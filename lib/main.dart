import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

import 'app.dart';
import 'core/discovery/mdns_service.dart';
import 'core/discovery/peer_registry.dart';
import 'core/transfer/transfer_manager.dart';
import 'core/utils/platform_utils.dart';
import 'features/overlay/overlay_controller.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Generate or derive a unique instance ID for this session
  final randomSuffix = Random().nextInt(9999).toString().padLeft(4, '0');
  final selfId = '${PlatformUtils.osName}_$randomSuffix';
  final selfName = PlatformUtils.getDefaultDeviceName();

  // Create core service instances
  final peerRegistry = PeerRegistry();
  final transferManager = TransferManager(
    selfId: selfId,
    selfName: selfName,
  );
  final mdnsService = MdnsService(
    peerRegistry: peerRegistry,
    selfId: selfId,
    deviceName: selfName,
  );

  // Request mobile permissions if running on Android/iOS
  if (PlatformUtils.isMobile) {
    try {
      await [
        Permission.storage,
        Permission.nearbyWifiDevices,
      ].request();
    } catch (e) {
      debugPrint('[AirP2P] Permission request error: $e');
    }
  }

  // Windows Desktop OS Integration (System Tray + Alt + Q hotkey + Acrylic)
  if (Platform.isWindows) {
    await OverlayController().initialize(
      onToggleRequested: () => OverlayController().toggleOverlay(),
    );
  }

  // Start Discovery and File Transfer TCP servers
  await transferManager.start();
  await mdnsService.start();

  runApp(AirP2PApp(
    peerRegistry: peerRegistry,
    transferManager: transferManager,
    selfName: selfName,
  ));
}
