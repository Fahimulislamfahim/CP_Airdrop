import 'dart:io';
import 'dart:math';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/discovery/peer_registry.dart';
import '../../core/models/peer.dart';
import '../../core/models/transfer.dart';
import '../../core/transfer/transfer_manager.dart';
import '../overlay/bot_widget.dart';
import '../overlay/radar_painter.dart';
import 'accept_sheet.dart';

class MobileScreen extends StatefulWidget {
  final String selfName;

  const MobileScreen({
    super.key,
    required this.selfName,
  });

  @override
  State<MobileScreen> createState() => _MobileScreenState();
}

class _MobileScreenState extends State<MobileScreen>
    with TickerProviderStateMixin {
  late final AnimationController _sweepController;
  late final AnimationController _pulseController;
  String? _currentlyPromptedTransferId;

  @override
  void initState() {
    super.initState();
    _sweepController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3200),
    )..repeat();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat();
  }

  @override
  void dispose() {
    _sweepController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _pickAndSendFile(Peer peer) async {
    final result = await FilePicker.platform.pickFiles();
    if (result != null && result.files.isNotEmpty) {
      final path = result.files.first.path;
      if (path != null && mounted) {
        context.read<TransferManager>().sendFile(peer, File(path));
      }
    }
  }

  void _checkIncomingTransfer(TransferManager manager) {
    final pending = manager.pendingIncomingTransfer;
    if (pending != null && pending.id != _currentlyPromptedTransferId) {
      _currentlyPromptedTransferId = pending.id;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        showModalBottomSheet(
          context: context,
          isDismissible: false,
          enableDrag: false,
          backgroundColor: Colors.transparent,
          builder: (ctx) {
            return Consumer<TransferManager>(
              builder: (context, currentManager, _) {
                final currentTransfer = currentManager.transfers.firstWhere(
                  (t) => t.id == pending.id,
                  orElse: () => pending,
                );

                if (currentTransfer.status == TransferStatus.completed ||
                    currentTransfer.status == TransferStatus.declined ||
                    currentTransfer.status == TransferStatus.failed) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (Navigator.canPop(ctx)) {
                      Navigator.pop(ctx);
                      _currentlyPromptedTransferId = null;
                    }
                  });
                }

                return AcceptSheet(
                  transfer: currentTransfer,
                  onAccept: () => currentManager.acceptTransfer(pending.id),
                  onDecline: () {
                    currentManager.declineTransfer(pending.id);
                    if (Navigator.canPop(ctx)) {
                      Navigator.pop(ctx);
                      _currentlyPromptedTransferId = null;
                    }
                  },
                );
              },
            );
          },
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final peerRegistry = context.watch<PeerRegistry>();
    final transferManager = context.watch<TransferManager>();
    final peers = peerRegistry.peers;
    final activeTransfers = transferManager.activeTransfers;

    _checkIncomingTransfer(transferManager);

    return Scaffold(
      backgroundColor: const Color(0xFF0A0F1D),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF00E5FF).withAlpha(30),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.radar_rounded, color: Color(0xFF00E5FF), size: 20),
            ),
            const SizedBox(width: 12),
            const Text(
              'AirP2P Radar',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.8,
              ),
            ),
          ],
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFF0F172A),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF00E5FF).withAlpha(80)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: const BoxDecoration(
                    color: Color(0xFF00E676),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  '${peers.length} active',
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Upper Radar Scanner with Center Bot
            Expanded(
              flex: 5,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Radar sweep canvas
                  AnimatedBuilder(
                    animation: Listenable.merge([_sweepController, _pulseController]),
                    builder: (context, _) {
                      return CustomPaint(
                        size: const Size(320, 320),
                        painter: RadarPainter(
                          sweepAngle: _sweepController.value * 2 * pi,
                          pulseProgress: _pulseController.value,
                        ),
                      );
                    },
                  ),

                  // Bot Companion
                  BotWidget(
                    deviceName: widget.selfName,
                    isScanning: true,
                  ),
                ],
              ),
            ),

            // Active Transfers Card if any
            if (activeTransfers.isNotEmpty)
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F172A),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFF00E5FF).withAlpha(100)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          activeTransfers.first.isOutgoing
                              ? 'Sending to ${activeTransfers.first.peer.name}'
                              : 'Receiving from ${activeTransfers.first.peer.name}',
                          style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          '${activeTransfers.first.progressPercentage.toStringAsFixed(0)}%',
                          style: const TextStyle(color: Color(0xFF00E5FF), fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        value: activeTransfers.first.progress,
                        minHeight: 6,
                        backgroundColor: Colors.white12,
                        valueColor: const AlwaysStoppedAnimation(Color(0xFF00E5FF)),
                      ),
                    ),
                  ],
                ),
              ),

            // Discovered Nearby Devices Section
            Expanded(
              flex: 4,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                decoration: const BoxDecoration(
                  color: Color(0xFF0B132B),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
                  border: Border(
                    top: BorderSide(color: Color(0x3300E5FF), width: 1),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'NEARBY DEVICES',
                      style: TextStyle(
                        color: Colors.white60,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: peers.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.wifi_tethering_rounded,
                                    size: 40,
                                    color: Colors.white.withAlpha(40),
                                  ),
                                  const SizedBox(height: 8),
                                  const Text(
                                    'Scanning local network...',
                                    style: TextStyle(color: Colors.white38, fontSize: 13),
                                  ),
                                  const SizedBox(height: 4),
                                  const Text(
                                    'Open AirP2P on your PC or phone on the same Wi-Fi',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(color: Colors.white24, fontSize: 11),
                                  ),
                                ],
                              ),
                            )
                          : ListView.separated(
                              itemCount: peers.length,
                              separatorBuilder: (context, index) => const SizedBox(height: 10),
                              itemBuilder: (context, index) {
                                final peer = peers[index];
                                final isDesktop = peer.devType == 'desktop';

                                return Container(
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF0F172A),
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color: isDesktop
                                          ? const Color(0xFF00E5FF).withAlpha(120)
                                          : Colors.white12,
                                    ),
                                  ),
                                  child: ListTile(
                                    leading: Container(
                                      padding: const EdgeInsets.all(10),
                                      decoration: BoxDecoration(
                                        color: (isDesktop
                                                ? const Color(0xFF00E5FF)
                                                : const Color(0xFF00E676))
                                            .withAlpha(30),
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(
                                        isDesktop
                                            ? Icons.desktop_windows_rounded
                                            : Icons.phone_android_rounded,
                                        color: isDesktop
                                            ? const Color(0xFF00E5FF)
                                            : const Color(0xFF00E676),
                                      ),
                                    ),
                                    title: Text(
                                      peer.name,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    subtitle: Text(
                                      '${peer.ip} • ${peer.os}',
                                      style: const TextStyle(
                                        color: Colors.white54,
                                        fontSize: 12,
                                      ),
                                    ),
                                    trailing: ElevatedButton.icon(
                                      onPressed: () => _pickAndSendFile(peer),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(0xFF00E5FF),
                                        foregroundColor: const Color(0xFF0A0F1D),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                      ),
                                      icon: const Icon(Icons.send_rounded, size: 16),
                                      label: const Text(
                                        'Send',
                                        style: TextStyle(fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
