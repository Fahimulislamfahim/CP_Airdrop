import 'dart:io';
import 'package:airp2p/core/discovery/peer_registry.dart';
import 'package:airp2p/core/models/peer.dart';
import 'package:airp2p/core/models/transfer.dart';
import 'package:airp2p/core/utils/checksum.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hotkey_manager/hotkey_manager.dart';

void main() {
  group('ChecksumUtils Tests', () {
    test('formats byte sizes cleanly', () {
      expect(ChecksumUtils.formatBytes(500), '500.0 B');
      expect(ChecksumUtils.formatBytes(1024), '1.0 KB');
      expect(ChecksumUtils.formatBytes(1024 * 1024 * 5), '5.0 MB');
      expect(ChecksumUtils.formatBytes(1024 * 1024 * 1024 * 2), '2.0 GB');
    });

    test('calculates SHA-256 via streaming correctly', () async {
      final tempDir = await Directory.systemTemp.createTemp('airp2p_test_');
      final testFile = File('${tempDir.path}/test.txt');
      await testFile.writeAsString('Hello AirP2P Streaming World!');

      final hash = await ChecksumUtils.calculateSha256(testFile);
      expect(hash, isNotEmpty);
      expect(hash.length, 64); // Standard SHA-256 hex string length

      // Cleanup
      await tempDir.delete(recursive: true);
    });
  });

  group('Peer Model & Registry Tests', () {
    test('serializes and deserializes Peer correctly', () {
      final peer = Peer(
        id: 'win_1234',
        ip: '192.168.1.100',
        port: 49200,
        name: "Fahim's Legion",
        os: 'windows',
        devType: 'desktop',
        lastSeen: DateTime.now(),
      );

      final jsonStr = peer.toJson();
      final revived = Peer.fromJson(jsonStr);

      expect(revived.id, peer.id);
      expect(revived.ip, peer.ip);
      expect(revived.name, peer.name);
      expect(revived.os, 'windows');
      expect(revived.devType, 'desktop');
    });

    test('PeerRegistry adds, updates, and prunes expired peers', () async {
      final registry = PeerRegistry(ttl: const Duration(milliseconds: 300));
      final peer1 = Peer(
        id: 'peer_1',
        ip: '192.168.1.50',
        port: 49200,
        name: 'Phone A',
        os: 'android',
        devType: 'mobile',
        lastSeen: DateTime.now(),
      );

      registry.upsertPeer(peer1);
      expect(registry.peers.length, 1);
      expect(registry.hasPeer('peer_1'), isTrue);

      // Wait for TTL to expire
      await Future.delayed(const Duration(milliseconds: 2200));
      expect(registry.hasPeer('peer_1'), isFalse);
      expect(registry.peers.isEmpty, isTrue);

      registry.dispose();
    });
  });

  group('Transfer Model Tests', () {
    test('computes progress percentage accurately', () {
      final peer = Peer(
        id: 'peer_1',
        ip: '192.168.1.50',
        port: 49200,
        name: 'Phone A',
        os: 'android',
        devType: 'mobile',
        lastSeen: DateTime(2026, 1, 1),
      );

      final transfer = Transfer(
        id: 't_1',
        fileName: 'demo.mp4',
        fileSize: 1000,
        mimeType: 'video/mp4',
        checksum: 'abc123hash',
        peer: peer,
        isOutgoing: true,
        status: TransferStatus.transferring,
        bytesTransferred: 500,
        createdAt: DateTime.now(),
      );

      expect(transfer.progress, 0.5);
      expect(transfer.progressPercentage, 50.0);
    });
  });
}
