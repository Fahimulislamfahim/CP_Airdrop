import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import '../models/peer.dart';
import '../models/transfer.dart';
import 'tcp_client.dart';
import 'tcp_server.dart';

class TransferManager extends ChangeNotifier {
  final String selfId;
  final String selfName;
  final int port;

  late final TcpServer _server;
  final List<Transfer> _transfers = [];
  final Map<String, Completer<bool>> _pendingRequests = {};

  // Callback when a new incoming transfer is requested
  void Function(Transfer transfer)? onIncomingRequest;

  TransferManager({
    required this.selfId,
    required this.selfName,
    this.port = 49200,
  }) {
    _server = TcpServer(
      port: port,
      onRequest: _handleIncomingRequest,
      onProgress: _handleTransferUpdate,
    );
  }

  List<Transfer> get transfers => List.unmodifiable(_transfers);

  List<Transfer> get activeTransfers => List.unmodifiable(_transfers.where(
      (t) => t.status == TransferStatus.transferring || t.status == TransferStatus.connecting));

  Transfer? get pendingIncomingTransfer {
    try {
      return _transfers.firstWhere((t) => t.status == TransferStatus.pending && !t.isOutgoing);
    } catch (_) {
      return null;
    }
  }

  Future<void> start() async {
    await _server.start();
  }

  Future<void> stop() async {
    await _server.stop();
  }

  /// Trigger outgoing file transfer to a peer
  Future<void> sendFile(Peer peer, File file) async {
    await TcpClient.sendFile(
      peer: peer,
      file: file,
      selfId: selfId,
      selfName: selfName,
      onProgress: _handleTransferUpdate,
    );
  }

  /// Accept an incoming transfer request
  void acceptTransfer(String transferId) {
    final completer = _pendingRequests.remove(transferId);
    if (completer != null && !completer.isCompleted) {
      completer.complete(true);
    }
  }

  /// Decline an incoming transfer request
  void declineTransfer(String transferId) {
    final completer = _pendingRequests.remove(transferId);
    if (completer != null && !completer.isCompleted) {
      completer.complete(false);
    }
  }

  Future<bool> _handleIncomingRequest(Transfer transfer) async {
    _handleTransferUpdate(transfer);
    final completer = Completer<bool>();
    _pendingRequests[transfer.id] = completer;

    // Trigger external notification/UI hook
    onIncomingRequest?.call(transfer);

    // Default timeout 60s
    return completer.future.timeout(
      const Duration(seconds: 60),
      onTimeout: () {
        _pendingRequests.remove(transfer.id);
        return false;
      },
    );
  }

  void _handleTransferUpdate(Transfer transfer) {
    final index = _transfers.indexWhere((t) => t.id == transfer.id);
    if (index >= 0) {
      _transfers[index] = transfer;
    } else {
      _transfers.insert(0, transfer);
    }
    notifyListeners();
  }

  void clearCompleted() {
    _transfers.removeWhere((t) =>
        t.status == TransferStatus.completed ||
        t.status == TransferStatus.failed ||
        t.status == TransferStatus.declined ||
        t.status == TransferStatus.cancelled);
    notifyListeners();
  }
}
