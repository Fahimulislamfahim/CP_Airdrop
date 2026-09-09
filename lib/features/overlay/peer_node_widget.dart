import 'dart:io';
import 'dart:ui';
import 'package:desktop_drop/desktop_drop.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../../core/models/peer.dart';

class PeerNodeWidget extends StatefulWidget {
  final Peer peer;
  final void Function(File file) onSendFile;

  const PeerNodeWidget({
    super.key,
    required this.peer,
    required this.onSendFile,
  });

  @override
  State<PeerNodeWidget> createState() => _PeerNodeWidgetState();
}

class _PeerNodeWidgetState extends State<PeerNodeWidget> {
  bool _isDraggingOver = false;

  IconData _getOsIcon(String os) {
    final lower = os.toLowerCase();
    if (lower.contains('win')) return Icons.desktop_windows_rounded;
    if (lower.contains('andr')) return Icons.phone_android_rounded;
    if (lower.contains('ios') || lower.contains('mac') || lower.contains('apple')) {
      return Icons.apple_rounded;
    }
    if (lower.contains('linux')) return Icons.terminal_rounded;
    return Icons.devices_rounded;
  }

  Color _getOsColor(String os) {
    final lower = os.toLowerCase();
    if (lower.contains('win')) return const Color(0xFF00B0FF);
    if (lower.contains('andr')) return const Color(0xFF00E676);
    if (lower.contains('ios') || lower.contains('mac') || lower.contains('apple')) {
      return const Color(0xFFE0E0E0);
    }
    return const Color(0xFFFF9100);
  }

  Future<void> _pickAndSendFile() async {
    final result = await FilePicker.platform.pickFiles();
    if (result != null && result.files.isNotEmpty) {
      final path = result.files.first.path;
      if (path != null) {
        widget.onSendFile(File(path));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final osColor = _getOsColor(widget.peer.os);

    return DropTarget(
      onDragEntered: (details) => setState(() => _isDraggingOver = true),
      onDragExited: (details) => setState(() => _isDraggingOver = false),
      onDragDone: (details) {
        setState(() => _isDraggingOver = false);
        if (details.files.isNotEmpty) {
          final first = details.files.first;
          widget.onSendFile(File(first.path));
        }
      },
      child: GestureDetector(
        onTap: _pickAndSendFile,
        child: AnimatedScale(
          scale: _isDraggingOver ? 1.15 : 1.0,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutBack,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Circular frosted badge
              ClipOval(
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                  child: Container(
                    width: 74,
                    height: 74,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _isDraggingOver
                          ? const Color(0xFF00E5FF).withAlpha(80)
                          : const Color(0xFF0F172A).withAlpha(190),
                      border: Border.all(
                        color: _isDraggingOver
                            ? const Color(0xFF00E5FF)
                            : osColor.withAlpha(180),
                        width: _isDraggingOver ? 2.8 : 1.8,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: (_isDraggingOver ? const Color(0xFF00E5FF) : osColor)
                              .withAlpha(_isDraggingOver ? 160 : 70),
                          blurRadius: _isDraggingOver ? 24 : 14,
                          spreadRadius: _isDraggingOver ? 4 : 1,
                        ),
                      ],
                    ),
                    child: Center(
                      child: Icon(
                        _getOsIcon(widget.peer.os),
                        size: 34,
                        color: _isDraggingOver ? Colors.white : osColor,
                      ),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 8),

              // Peer Name & Online Indicator
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF0B132B).withAlpha(220),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: Colors.white.withAlpha(25),
                    width: 1,
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
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
                        const SizedBox(width: 5),
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 110),
                          child: Text(
                            widget.peer.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    Text(
                      _isDraggingOver ? 'Drop to send!' : 'Tap or drop file',
                      style: TextStyle(
                        color: _isDraggingOver
                            ? const Color(0xFF00E5FF)
                            : Colors.white54,
                        fontSize: 10,
                        fontWeight: _isDraggingOver ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
