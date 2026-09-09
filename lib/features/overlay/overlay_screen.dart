import 'dart:io';
import 'dart:math';
import 'dart:ui';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/discovery/peer_registry.dart';
import '../../core/models/peer.dart';
import '../../core/models/transfer.dart';
import '../../core/transfer/transfer_manager.dart';
import '../../core/utils/checksum.dart';
import 'bot_widget.dart';
import 'overlay_controller.dart';
import 'peer_node_widget.dart';
import 'radar_painter.dart';

class OverlayScreen extends StatefulWidget {
  final String selfName;

  const OverlayScreen({
    super.key,
    required this.selfName,
  });

  @override
  State<OverlayScreen> createState() => _OverlayScreenState();
}

class _OverlayScreenState extends State<OverlayScreen>
    with TickerProviderStateMixin {
  late final AnimationController _sweepController;
  late final AnimationController _pulseController;
  late final AnimationController _orbitController;
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();

    // 1. Radar sweep rotation
    _sweepController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3200),
    )..repeat();

    // 2. Concentric pulse waves
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat();

    // 3. Gentle orbit rotation for nodes
    _orbitController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 40),
    )..repeat();
  }

  @override
  void dispose() {
    _sweepController.dispose();
    _pulseController.dispose();
    _orbitController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _dismissOverlay() {
    OverlayController().hideOverlay();
  }

  Future<void> _pickFileForAnyPeer(List<Peer> peers) async {
    if (peers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No peers discovered yet. Wait for devices on the same Wi-Fi.'),
          backgroundColor: Color(0xFF1E293B),
        ),
      );
      return;
    }

    final result = await FilePicker.platform.pickFiles();
    if (result != null && result.files.isNotEmpty) {
      final filePath = result.files.first.path;
      if (filePath == null) return;
      final file = File(filePath);

      if (!mounted) return;
      if (peers.length == 1) {
        context.read<TransferManager>().sendFile(peers.first, file);
      } else {
        _showPeerSelectionSheet(peers, file);
      }
    }
  }

  void _showPeerSelectionSheet(List<Peer> peers, File file) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0F172A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Select Destination Peer',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              ...peers.map((peer) => ListTile(
                    leading: const Icon(Icons.devices_rounded, color: Color(0xFF00E5FF)),
                    title: Text(peer.name, style: const TextStyle(color: Colors.white)),
                    subtitle: Text('${peer.ip} • ${peer.os}',
                        style: const TextStyle(color: Colors.white54)),
                    onTap: () {
                      Navigator.pop(ctx);
                      context.read<TransferManager>().sendFile(peer, file);
                    },
                  )),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final peerRegistry = context.watch<PeerRegistry>();
    final transferManager = context.watch<TransferManager>();
    final peers = peerRegistry.peers;
    final activeTransfers = transferManager.activeTransfers;
    final pendingTransfer = transferManager.pendingIncomingTransfer;

    return Focus(
      focusNode: _focusNode,
      autofocus: true,
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent &&
            event.logicalKey == LogicalKeyboardKey.escape) {
          _dismissOverlay();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Stack(
          children: [
            // 1. Frosted Translucent Dark Cyber-Glass Backdrop
            GestureDetector(
              onTap: _dismissOverlay,
              behavior: HitTestBehavior.opaque,
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                child: Container(
                  color: const Color(0xFF0A0F1D).withAlpha(165), // ~65% opacity
                ),
              ),
            ),

            // 2. Animated Center Radar Canvas
            Center(
              child: IgnorePointer(
                child: AnimatedBuilder(
                  animation: Listenable.merge([_sweepController, _pulseController]),
                  builder: (context, _) {
                    return CustomPaint(
                      size: const Size(640, 640),
                      painter: RadarPainter(
                        sweepAngle: _sweepController.value * 2 * pi,
                        pulseProgress: _pulseController.value,
                      ),
                    );
                  },
                ),
              ),
            ),

            // 3. Center Bot Companion Anchor
            Center(
              child: BotWidget(
                deviceName: widget.selfName,
                isScanning: true,
              ),
            ),

            // 4. Orbiting Discovered Peer Nodes
            Center(
              child: AnimatedBuilder(
                animation: _orbitController,
                builder: (context, _) {
                  return SizedBox(
                    width: 580,
                    height: 580,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        for (int i = 0; i < peers.length; i++)
                          _buildOrbitingNode(
                            peers[i],
                            i,
                            peers.length,
                            _orbitController.value * 2 * pi,
                          ),
                      ],
                    ),
                  );
                },
              ),
            ),

            // 5. Top Bar Header & Dismiss Controls
            Positioned(
              top: 36,
              left: 36,
              right: 36,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // App Brand & Discovery Status
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F172A).withAlpha(200),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: const Color(0xFF00E5FF).withAlpha(60),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.radar_rounded,
                          color: Color(0xFF00E5FF),
                          size: 20,
                        ),
                        const SizedBox(width: 10),
                        const Text(
                          'AIRP2P LOCAL RADAR',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.2,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFF00E5FF).withAlpha(30),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '${peers.length} ONLINE',
                            style: const TextStyle(
                              color: Color(0xFF00E5FF),
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Close (Esc) Button
                  IconButton.filled(
                    onPressed: _dismissOverlay,
                    tooltip: 'Dismiss (Esc)',
                    style: IconButton.styleFrom(
                      backgroundColor: const Color(0xFF0F172A).withAlpha(200),
                      foregroundColor: Colors.white70,
                      side: BorderSide(color: Colors.white.withAlpha(30)),
                    ),
                    icon: const Icon(Icons.close_rounded, size: 20),
                  ),
                ],
              ),
            ),

            // 6. Incoming Transfer Accept/Decline Banner
            if (pendingTransfer != null)
              Positioned(
                top: 96,
                left: 0,
                right: 0,
                child: Center(
                  child: _buildIncomingTransferPrompt(pendingTransfer, transferManager),
                ),
              ),

            // 7. Active Transfer Progress Dock
            if (activeTransfers.isNotEmpty)
              Positioned(
                bottom: 36,
                left: 36,
                right: 120,
                child: _buildActiveTransfersDock(activeTransfers),
              ),

            // 8. Manual File Picker Glass Floating Action Button
            Positioned(
              bottom: 36,
              right: 36,
              child: FloatingActionButton.extended(
                onPressed: () => _pickFileForAnyPeer(peers),
                backgroundColor: const Color(0xFF0F172A),
                foregroundColor: const Color(0xFF00E5FF),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                  side: const BorderSide(
                    color: Color(0xFF00E5FF),
                    width: 1.5,
                  ),
                ),
                elevation: 12,
                icon: const Icon(Icons.add_to_drive_rounded, size: 22),
                label: const Text(
                  'SEND FILE',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.0,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOrbitingNode(Peer peer, int index, int total, double orbitOffset) {
    const double radius = 210.0;
    // Distribute evenly around the circle + apply slow orbit offset
    final double angle = (index / total) * 2 * pi + orbitOffset;
    final double x = radius * cos(angle);
    final double y = radius * sin(angle);

    return Transform.translate(
      offset: Offset(x, y),
      child: PeerNodeWidget(
        peer: peer,
        onSendFile: (file) {
          context.read<TransferManager>().sendFile(peer, file);
        },
      ),
    );
  }

  Widget _buildIncomingTransferPrompt(
      Transfer transfer, TransferManager manager) {
    return Container(
      width: 440,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A).withAlpha(240),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF00E5FF), width: 1.8),
        boxShadow: const [
          BoxShadow(
            color: Color(0x6600E5FF),
            blurRadius: 28,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF00E5FF).withAlpha(30),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.download_rounded,
                  color: Color(0xFF00E5FF),
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${transfer.peer.name} wants to send:',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                    ),
                    Text(
                      transfer.fileName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      ChecksumUtils.formatBytes(transfer.fileSize),
                      style: const TextStyle(
                        color: Color(0xFF00E5FF),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () => manager.declineTransfer(transfer.id),
                style: TextButton.styleFrom(
                  foregroundColor: Colors.redAccent,
                ),
                child: const Text('Decline'),
              ),
              const SizedBox(width: 10),
              ElevatedButton.icon(
                onPressed: () => manager.acceptTransfer(transfer.id),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00E5FF),
                  foregroundColor: const Color(0xFF0A0F1D),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: const Icon(Icons.check_rounded, size: 18),
                label: const Text(
                  'Accept',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActiveTransfersDock(List<Transfer> transfers) {
    final transfer = transfers.first;
    return Container(
      constraints: const BoxConstraints(maxWidth: 460),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A).withAlpha(220),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFF00E5FF).withAlpha(80),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  '${transfer.isOutgoing ? 'Sending to' : 'Receiving from'} ${transfer.peer.name}: ${transfer.fileName}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Text(
                '${transfer.progressPercentage.toStringAsFixed(0)}%',
                style: const TextStyle(
                  color: Color(0xFF00E5FF),
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: transfer.progress,
              minHeight: 6,
              backgroundColor: Colors.white12,
              valueColor: const AlwaysStoppedAnimation(Color(0xFF00E5FF)),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '${ChecksumUtils.formatBytes(transfer.bytesTransferred)} / ${ChecksumUtils.formatBytes(transfer.fileSize)}',
            style: const TextStyle(
              color: Colors.white54,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}
