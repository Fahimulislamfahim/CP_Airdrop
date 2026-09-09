import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/peer.dart';

/// In-memory registry of active peers on the LAN with 10-second TTL pruning.
class PeerRegistry extends ChangeNotifier {
  final Map<String, Peer> _peers = {};
  Timer? _pruneTimer;
  final Duration ttl;

  PeerRegistry({this.ttl = const Duration(seconds: 10)}) {
    _startPruneTimer();
  }

  /// Current active peers as an unmodifiable list
  List<Peer> get peers => List.unmodifiable(_peers.values);

  /// Map of peer ID to Peer
  Map<String, Peer> get peerMap => Map.unmodifiable(_peers);

  /// Check if a peer is registered
  bool hasPeer(String id) => _peers.containsKey(id);

  /// Get a specific peer
  Peer? getPeer(String id) => _peers[id];

  /// Upsert a peer when discovered or refreshed
  void upsertPeer(Peer peer) {
    final existing = _peers[peer.id];
    final updated = peer.copyWith(lastSeen: DateTime.now());

    // Only notify if something actually changed or new
    if (existing == null ||
        existing.ip != updated.ip ||
        existing.port != updated.port ||
        existing.name != updated.name ||
        existing.os != updated.os) {
      _peers[peer.id] = updated;
      notifyListeners();
    } else {
      // Just update timestamp without full notify if no fields changed
      _peers[peer.id] = updated;
    }
  }

  /// Remove a peer explicitly (e.g. mDNS lost event)
  void removePeer(String id) {
    if (_peers.remove(id) != null) {
      notifyListeners();
    }
  }

  /// Clear all peers
  void clear() {
    if (_peers.isNotEmpty) {
      _peers.clear();
      notifyListeners();
    }
  }

  void _startPruneTimer() {
    _pruneTimer?.cancel();
    _pruneTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      _pruneExpiredPeers();
    });
  }

  void _pruneExpiredPeers() {
    final now = DateTime.now();
    final expiredIds = <String>[];

    for (final entry in _peers.entries) {
      if (now.difference(entry.value.lastSeen) > ttl) {
        expiredIds.add(entry.key);
      }
    }

    if (expiredIds.isNotEmpty) {
      for (final id in expiredIds) {
        _peers.remove(id);
      }
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _pruneTimer?.cancel();
    super.dispose();
  }
}
