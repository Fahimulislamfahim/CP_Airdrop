import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import '../models/peer.dart';
import '../models/transfer.dart';
import '../utils/checksum.dart';
import '../utils/platform_utils.dart';

typedef TransferClientProgressCallback = void Function(Transfer transfer);

class TcpClient {
  static const int chunkSize = 64 * 1024; // 64 KB per chunk

  /// Send a file to a remote peer via raw streaming over TCP.
  static Future<void> sendFile({
    required Peer peer,
    required File file,
    required String selfId,
    required String selfName,
    required TransferClientProgressCallback onProgress,
  }) async {
    final fileName = p.basename(file.path);
    final fileSize = await file.length();
    final transferId = '${DateTime.now().millisecondsSinceEpoch}_send';

    var currentTransfer = Transfer(
      id: transferId,
      fileName: fileName,
      fileSize: fileSize,
      mimeType: 'application/octet-stream',
      checksum: '',
      peer: peer,
      isOutgoing: true,
      status: TransferStatus.connecting,
      localFilePath: file.path,
      createdAt: DateTime.now(),
    );

    onProgress(currentTransfer);

    Socket? socket;
    try {
      // 1. Compute SHA-256 via streaming without loading whole file in RAM
      final checksum = await ChecksumUtils.calculateSha256(file);
      currentTransfer = currentTransfer.copyWith(checksum: checksum);

      // 2. Connect to receiver's IP:port
      debugPrint('[TcpClient] Connecting to ${peer.ip}:${peer.port}');
      socket = await Socket.connect(
        peer.ip,
        peer.port,
        timeout: const Duration(seconds: 8),
      );

      // 3. Build & send Handshake Frame (JSON header with 4-byte big-endian prefix)
      final headerMap = {
        'file_name': fileName,
        'file_size': fileSize,
        'mime_type': 'application/octet-stream',
        'checksum': checksum,
        'sender_id': selfId,
        'sender_name': selfName,
        'sender_os': PlatformUtils.osName,
        'sender_dev_type': PlatformUtils.devType,
      };

      final headerBytes = utf8.encode(json.encode(headerMap));
      final prefixData = ByteData(4)..setUint32(0, headerBytes.length, Endian.big);

      socket.add(prefixData.buffer.asUint8List());
      socket.add(headerBytes);
      await socket.flush();

      // 4. Await 1-byte ACK (1 = Accept, 0 = Decline)
      final responseCompleter = Completer<int>();
      StreamSubscription<List<int>>? ackSub;

      ackSub = socket.listen((data) {
        if (!responseCompleter.isCompleted && data.isNotEmpty) {
          responseCompleter.complete(data.first);
        }
      }, onError: (e) {
        if (!responseCompleter.isCompleted) {
          responseCompleter.completeError(e);
        }
      });

      final ack = await responseCompleter.future.timeout(
        const Duration(seconds: 45),
        onTimeout: () => 0,
      );

      await ackSub.cancel();

      if (ack != 1) {
        currentTransfer = currentTransfer.copyWith(
          status: TransferStatus.declined,
          errorMessage: 'Transfer was declined or timed out',
        );
        onProgress(currentTransfer);
        socket.destroy();
        return;
      }

      // 5. Stream file in 64 KB chunks
      currentTransfer = currentTransfer.copyWith(
        status: TransferStatus.transferring,
      );
      onProgress(currentTransfer);

      final fileStream = file.openRead();
      var sentBytes = 0;

      await for (final chunk in fileStream) {
        socket.add(chunk);
        sentBytes += chunk.length;
        currentTransfer = currentTransfer.copyWith(bytesTransferred: sentBytes);
        onProgress(currentTransfer);
      }

      await socket.flush();

      currentTransfer = currentTransfer.copyWith(
        status: TransferStatus.completed,
        bytesTransferred: fileSize,
      );
      onProgress(currentTransfer);
      debugPrint('[TcpClient] Sent $fileName ($sentBytes bytes) successfully');

      await socket.close();
    } catch (e) {
      debugPrint('[TcpClient] Send error: $e');
      currentTransfer = currentTransfer.copyWith(
        status: TransferStatus.failed,
        errorMessage: e.toString(),
      );
      onProgress(currentTransfer);
      socket?.destroy();
      rethrow;
    }
  }
}
