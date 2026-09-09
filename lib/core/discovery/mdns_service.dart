import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:bonsoir/bonsoir.dart';
import 'package:flutter/foundation.dart';
import '../models/peer.dart';
import '../utils/platform_utils.dart';
import 'peer_registry.dart';

/// Discovery layer managing mDNS (bonsoir) advertising/browsing + UDP LAN beacon.
class MdnsService {
  static const String serviceType = '_airp2p._tcp';
  static const int defaultPort = 49200;
  static const int udpBeaconPort = 49201;

  final PeerRegistry peerRegistry;
  final String selfId;
  final String deviceName;
  final int tcpPort;

  BonsoirBroadcast? _broadcast;
  BonsoirDiscovery? _discovery;
  StreamSubscription<BonsoirDiscoveryEvent>? _discoverySubscription;

  RawDatagramSocket? _udpSocket;
  Timer? _udpBeaconTimer;
  bool _isRunning = false;

  MdnsService({
    required this.peerRegistry,
    required this.selfId,
    required this.deviceName,
    this.tcpPort = defaultPort,
  });

  bool get isRunning => _isRunning;

  /// Start both mDNS announcement/browsing and local UDP fallback beacon.
  Future<void> start() async {
    if (_isRunning) return;
    _isRunning = true;

    await _startMdnsBroadcast();
    await _startMdnsDiscovery();
    await _startUdpBeacon();
  }

  /// Stop discovery and release sockets.
  Future<void> stop() async {
    _isRunning = false;
    _udpBeaconTimer?.cancel();
    _udpBeaconTimer = null;

    try {
      _udpSocket?.close();
      _udpSocket = null;
    } catch (_) {}

    try {
      await _discoverySubscription?.cancel();
      _discoverySubscription = null;
      if (_discovery != null) {
        await _discovery!.stop();
        _discovery = null;
      }
    } catch (e) {
      debugPrint('[MdnsService] Discovery stop error: $e');
    }

    try {
      if (_broadcast != null) {
        await _broadcast!.stop();
        _broadcast = null;
      }
    } catch (e) {
      debugPrint('[MdnsService] Broadcast stop error: $e');
    }
  }

  Future<void> _startMdnsBroadcast() async {
    try {
      final service = BonsoirService(
        name: '$deviceName ($selfId)',
        type: serviceType,
        port: tcpPort,
        attributes: {
          'id': selfId,
          'dev_name': deviceName,
          'dev_type': PlatformUtils.devType,
          'os': PlatformUtils.osName,
          'port': tcpPort.toString(),
        },
      );

      _broadcast = BonsoirBroadcast(service: service);
      await _broadcast!.ready;
      await _broadcast!.start();
      debugPrint('[MdnsService] mDNS broadcast active for $deviceName');
    } catch (e) {
      debugPrint('[MdnsService] mDNS broadcast init failed (using UDP beacon fallback): $e');
    }
  }

  Future<void> _startMdnsDiscovery() async {
    try {
      _discovery = BonsoirDiscovery(type: serviceType);
      await _discovery!.ready;

      _discoverySubscription = _discovery!.eventStream?.listen((event) {
        if (event.type == BonsoirDiscoveryEventType.discoveryServiceFound) {
          event.service?.resolve(_discovery!.serviceResolver);
        } else if (event.type == BonsoirDiscoveryEventType.discoveryServiceResolved) {
          final service = event.service;
          if (service != null) {
            _handleResolvedBonsoirService(service);
          }
        } else if (event.type == BonsoirDiscoveryEventType.discoveryServiceLost) {
          final service = event.service;
          if (service != null) {
            final peerId = service.attributes['id'] ?? service.name;
            peerRegistry.removePeer(peerId);
          }
        }
      });

      await _discovery!.start();
      debugPrint('[MdnsService] mDNS discovery active');
    } catch (e) {
      debugPrint('[MdnsService] mDNS discovery init failed (using UDP beacon fallback): $e');
    }
  }

  void _handleResolvedBonsoirService(BonsoirService service) {
    final attributes = service.attributes;
    final peerId = attributes['id'] ?? service.name;

    // Ignore self-discovery
    if (peerId == selfId) return;

    final peer = Peer(
      id: peerId,
      ip: (service is ResolvedBonsoirService ? service.host : null) ?? '127.0.0.1',
      port: service.port,
      name: attributes['dev_name'] ?? service.name,
      os: attributes['os'] ?? 'unknown',
      devType: attributes['dev_type'] ?? 'desktop',
      lastSeen: DateTime.now(),
    );

    peerRegistry.upsertPeer(peer);
  }

  /// UDP broadcast beacon providing 100% resilient LAN discovery on every router
  Future<void> _startUdpBeacon() async {
    try {
      _udpSocket = await RawDatagramSocket.bind(
        InternetAddress.anyIPv4,
        udpBeaconPort,
        reuseAddress: true,
        reusePort: !Platform.isWindows,
      );
      _udpSocket!.broadcastEnabled = true;

      _udpSocket!.listen((RawSocketEvent event) {
        if (event == RawSocketEvent.read) {
          final dg = _udpSocket?.receive();
          if (dg != null) {
            _handleUdpPacket(dg);
          }
        }
      });

      // Send initial beacon immediately, then every 3 seconds
      _sendUdpBeacon();
      _udpBeaconTimer = Timer.periodic(const Duration(seconds: 3), (_) {
        _sendUdpBeacon();
      });
    } catch (e) {
      debugPrint('[MdnsService] UDP beacon failed: $e');
    }
  }

  void _sendUdpBeacon() {
    if (_udpSocket == null) return;
    try {
      final payload = json.encode({
        'type': 'airp2p_beacon',
        'id': selfId,
        'dev_name': deviceName,
        'dev_type': PlatformUtils.devType,
        'os': PlatformUtils.osName,
        'port': tcpPort,
      });
      final bytes = utf8.encode(payload);
      _udpSocket?.send(
        bytes,
        InternetAddress('255.255.255.255'),
        udpBeaconPort,
      );
    } catch (e) {
      debugPrint('[MdnsService] Error sending UDP beacon: $e');
    }
  }

  void _handleUdpPacket(Datagram dg) {
    try {
      final text = utf8.decode(dg.data);
      final jsonMap = json.decode(text) as Map<String, dynamic>;
      if (jsonMap['type'] != 'airp2p_beacon') return;

      final peerId = jsonMap['id'] as String?;
      if (peerId == null || peerId == selfId) return;

      final peer = Peer(
        id: peerId,
        ip: dg.address.address,
        port: (jsonMap['port'] as int?) ?? defaultPort,
        name: (jsonMap['dev_name'] as String?) ?? 'Unknown Device',
        os: (jsonMap['os'] as String?) ?? 'unknown',
        devType: (jsonMap['dev_type'] as String?) ?? 'desktop',
        lastSeen: DateTime.now(),
      );

      peerRegistry.upsertPeer(peer);
    } catch (_) {}
  }
}
