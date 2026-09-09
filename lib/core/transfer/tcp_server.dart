import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import '../models/peer.dart';
import '../models/transfer.dart';
import '../utils/checksum.dart';
import '../utils/platform_utils.dart';

typedef TransferRequestHandler = Future<bool> Function(Transfer transfer);
typedef TransferProgressCallback = void Function(Transfer transfer);

class TcpServer {
  final int port;
  final TransferRequestHandler onRequest;
  final TransferProgressCallback onProgress;

  ServerSocket? _serverSocket;
  bool _isRunning = false;

  TcpServer({
    this.port = 49200,
    required this.onRequest,
    required this.onProgress,
  });

  bool get isRunning => _isRunning;

  Future<void> start() async {
    if (_isRunning) return;
    try {
      _serverSocket = await ServerSocket.bind(
        InternetAddress.anyIPv4,
        port,
        shared: true,
      );
      _isRunning = true;
      debugPrint('[TcpServer] Listening on port $port');

      _serverSocket!.listen(
        _handleClient,
        onError: (e) => debugPrint('[TcpServer] Error on socket: $e'),
        cancelOnError: false,
      );
    } catch (e) {
      debugPrint('[TcpServer] Failed to bind ServerSocket on port $port: $e');
    }
  }

  Future<void> stop() async {
    _isRunning = false;
    await _serverSocket?.close();
    _serverSocket = null;
  }

  Future<void> _handleClient(Socket socket) async {
    final clientIp = socket.remoteAddress.address;
    debugPrint('[TcpServer] Incoming connection from $clientIp:${socket.remotePort}');

    IOSink? fileSink;
    File? outputFile;
    Transfer? currentTransfer;

    try {
      // 1. Read 4-byte header length + JSON handshake frame
      final streamIterator = StreamIterator<List<int>>(socket);

      // Accumulator buffer for initial handshake frame
      final buffer = BytesBuilder();
      int? headerLength;

      while (await streamIterator.moveNext()) {
        buffer.add(streamIterator.current);
        if (headerLength == null && buffer.length >= 4) {
          final bytes = buffer.takeBytes();
          final byteData = ByteData.sublistView(Uint8List.fromList(bytes));
          headerLength = byteData.getUint32(0, Endian.big);
          buffer.add(bytes.sublist(4));
        }

        if (headerLength != null && buffer.length >= headerLength) {
          // Handshake complete
          break;
        }
      }

      if (headerLength == null || buffer.length < headerLength) {
        socket.destroy();
        return;
      }

      final allBytes = buffer.takeBytes();
      final headerBytes = allBytes.sublist(0, headerLength);
      final remainingData = allBytes.sublist(headerLength);

      final headerJson = utf8.decode(headerBytes);
      final meta = json.decode(headerJson) as Map<String, dynamic>;

      final fileName = meta['file_name'] as String? ?? 'received_file';
      final fileSize = meta['file_size'] as int? ?? 0;
      final mimeType = meta['mime_type'] as String? ?? 'application/octet-stream';
      final checksum = meta['checksum'] as String? ?? '';
      final senderName = meta['sender_name'] as String? ?? 'Unknown Peer';
      final senderOs = meta['sender_os'] as String? ?? 'unknown';
      final senderDevType = meta['sender_dev_type'] as String? ?? 'desktop';
      final senderId = meta['sender_id'] as String? ?? socket.remoteAddress.address;

      final peer = Peer(
        id: senderId,
        ip: socket.remoteAddress.address,
        port: socket.remotePort,
        name: senderName,
        os: senderOs,
        devType: senderDevType,
        lastSeen: DateTime.now(),
      );

      final transferId = '${DateTime.now().millisecondsSinceEpoch}_${socket.remotePort}';
      currentTransfer = Transfer(
        id: transferId,
        fileName: fileName,
        fileSize: fileSize,
        mimeType: mimeType,
        checksum: checksum,
        peer: peer,
        isOutgoing: false,
        status: TransferStatus.pending,
        createdAt: DateTime.now(),
      );

      // Notify progress for pending state
      onProgress(currentTransfer);

      // 2. Await accept / decline
      final accepted = await onRequest(currentTransfer);
      if (!accepted) {
        // Send 0 (Decline)
        socket.add([0]);
        await socket.flush();
        socket.destroy();
        onProgress(currentTransfer.copyWith(status: TransferStatus.declined));
        return;
      }

      // Send 1 (Accept)
      socket.add([1]);
      await socket.flush();

      // 3. Prepare file destination
      final saveDir = await PlatformUtils.getSaveDirectory();
      var targetPath = p.join(saveDir.path, fileName);

      // Handle duplicate file names
      var counter = 1;
      final baseName = p.basenameWithoutExtension(fileName);
      final ext = p.extension(fileName);
      while (await File(targetPath).exists()) {
        targetPath = p.join(saveDir.path, '$baseName($counter)$ext');
        counter++;
      }

      outputFile = File(targetPath);
      fileSink = outputFile.openWrite();

      var receivedBytes = 0;
      currentTransfer = currentTransfer.copyWith(
        status: TransferStatus.transferring,
        localFilePath: targetPath,
      );
      onProgress(currentTransfer);

      // Write any leftover bytes read during handshake buffering
      if (remainingData.isNotEmpty) {
        fileSink.add(remainingData);
        receivedBytes += remainingData.length;
        currentTransfer = currentTransfer.copyWith(bytesTransferred: receivedBytes);
        onProgress(currentTransfer);
      }

      // 4. Stream 64 KB chunks directly to disk
      while (receivedBytes < fileSize && await streamIterator.moveNext()) {
        final chunk = streamIterator.current;
        fileSink.add(chunk);
        receivedBytes += chunk.length;

        final transferObj = currentTransfer;
        if (transferObj != null) {
          final updated = transferObj.copyWith(bytesTransferred: receivedBytes);
          currentTransfer = updated;
          onProgress(updated);
        }
      }

      await fileSink.flush();
      await fileSink.close();
      fileSink = null;

      // 5. Check integrity (SHA-256)
      if (checksum.isNotEmpty) {
        final actualHash = await ChecksumUtils.calculateSha256(outputFile);
        if (actualHash.toLowerCase() != checksum.toLowerCase()) {
          throw Exception('Checksum verification failed: expected $checksum, got $actualHash');
        }
      }

      // Send 1 completion byte
      socket.add([1]);
      await socket.flush();
      await socket.close();

      if (currentTransfer != null) {
        currentTransfer = currentTransfer.copyWith(
          status: TransferStatus.completed,
          bytesTransferred: fileSize,
        );
        onProgress(currentTransfer);
      }
      debugPrint('[TcpServer] Transfer completed successfully: $fileName ($receivedBytes bytes)');
    } catch (e) {
      debugPrint('[TcpServer] Transfer error: $e');
      await fileSink?.close();
      if (currentTransfer != null) {
        onProgress(currentTransfer.copyWith(
          status: TransferStatus.failed,
          errorMessage: e.toString(),
        ));
      }
      socket.destroy();
    }
  }
}
