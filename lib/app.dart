import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/discovery/peer_registry.dart';
import 'core/transfer/transfer_manager.dart';
import 'features/mobile/mobile_screen.dart';
import 'features/overlay/overlay_screen.dart';

class AirP2PApp extends StatelessWidget {
  final PeerRegistry peerRegistry;
  final TransferManager transferManager;
  final String selfName;

  const AirP2PApp({
    super.key,
    required this.peerRegistry,
    required this.transferManager,
    required this.selfName,
  });

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: peerRegistry),
        ChangeNotifierProvider.value(value: transferManager),
      ],
      child: MaterialApp(
        title: 'AirP2P',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          brightness: Brightness.dark,
          scaffoldBackgroundColor: const Color(0xFF0A0F1D),
          primaryColor: const Color(0xFF00E5FF),
          colorScheme: const ColorScheme.dark(
            primary: Color(0xFF00E5FF),
            secondary: Color(0xFF00B0FF),
            surface: Color(0xFF0F172A),
          ),
          fontFamily: 'Segoe UI',
        ),
        home: Platform.isWindows
            ? OverlayScreen(selfName: selfName)
            : MobileScreen(selfName: selfName),
      ),
    );
  }
}
