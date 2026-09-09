import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

class BotWidget extends StatefulWidget {
  final String deviceName;
  final bool isScanning;

  const BotWidget({
    super.key,
    required this.deviceName,
    this.isScanning = true,
  });

  @override
  State<BotWidget> createState() => _BotWidgetState();
}

class _BotWidgetState extends State<BotWidget> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _breathingAnim;
  late final Animation<double> _floatingAnim;
  late final Animation<double> _glowAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat(reverse: true);

    _breathingAnim = Tween<double>(begin: 0.96, end: 1.04).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOutSine),
    );

    _floatingAnim = Tween<double>(begin: -6.0, end: 6.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOutQuad),
    );

    _glowAnim = Tween<double>(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, _floatingAnim.value),
          child: Transform.scale(
            scale: _breathingAnim.value,
            child: child,
          ),
        );
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Mascot Avatar with glowing aura
          Stack(
            alignment: Alignment.center,
            children: [
              // Outer Halo Glow
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF00E5FF).withAlpha((_glowAnim.value * 90).toInt()),
                      blurRadius: 36,
                      spreadRadius: 8,
                    ),
                    BoxShadow(
                      color: const Color(0xFF7C4DFF).withAlpha((_glowAnim.value * 50).toInt()),
                      blurRadius: 50,
                      spreadRadius: 14,
                    ),
                  ],
                ),
              ),

              // Bot Container / Lottie
              Container(
                width: 96,
                height: 96,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const RadialGradient(
                    colors: [
                      Color(0xFF1E293B),
                      Color(0xFF0F172A),
                    ],
                  ),
                  border: Border.all(
                    color: const Color(0xFF00E5FF).withAlpha(180),
                    width: 2.2,
                  ),
                ),
                child: ClipOval(
                  child: Lottie.asset(
                    'assets/animations/bot_idle.json',
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) {
                      // High-end Cyber-Bot Vector Fallback
                      return const _CyberBotFallback();
                    },
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Host Name Pill
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
            decoration: BoxDecoration(
              color: const Color(0xFF0F172A).withAlpha(200),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: const Color(0xFF00E5FF).withAlpha(100),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF00E5FF).withAlpha(30),
                  blurRadius: 10,
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 7,
                  height: 7,
                  decoration: const BoxDecoration(
                    color: Color(0xFF00E5FF),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Color(0xFF00E5FF),
                        blurRadius: 6,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  widget.deviceName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Fallback procedural cyber bot if Lottie JSON isn't rendered
class _CyberBotFallback extends StatelessWidget {
  const _CyberBotFallback();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Antenna with glowing dot
          Positioned(
            top: 14,
            child: Column(
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: const BoxDecoration(
                    color: Color(0xFF00E5FF),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Color(0xFF00E5FF),
                        blurRadius: 8,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                ),
                Container(
                  width: 2,
                  height: 10,
                  color: const Color(0xFF00E5FF).withAlpha(180),
                ),
              ],
            ),
          ),

          // Cyber Head Visor
          Container(
            width: 58,
            height: 42,
            margin: const EdgeInsets.only(top: 12),
            decoration: BoxDecoration(
              color: const Color(0xFF0B132B),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: const Color(0xFF00E5FF).withAlpha(220),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF00E5FF).withAlpha(50),
                  blurRadius: 12,
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Left glowing eye
                Container(
                  width: 12,
                  height: 16,
                  decoration: BoxDecoration(
                    color: const Color(0xFF00E5FF),
                    borderRadius: BorderRadius.circular(4),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0xFF00E5FF),
                        blurRadius: 10,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                // Right glowing eye
                Container(
                  width: 12,
                  height: 16,
                  decoration: BoxDecoration(
                    color: const Color(0xFF00E5FF),
                    borderRadius: BorderRadius.circular(4),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0xFF00E5FF),
                        blurRadius: 10,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
