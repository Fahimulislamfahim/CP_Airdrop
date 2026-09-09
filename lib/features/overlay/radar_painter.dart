import 'dart:math';
import 'package:flutter/material.dart';

class RadarPainter extends CustomPainter {
  final double sweepAngle; // 0.0 to 2*pi
  final double pulseProgress; // 0.0 to 1.0
  final Color primaryColor;
  final Color glowColor;

  RadarPainter({
    required this.sweepAngle,
    required this.pulseProgress,
    this.primaryColor = const Color(0xFF00E5FF),
    this.glowColor = const Color(0xFF00B0FF),
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxRadius = min(size.width, size.height) * 0.46;

    // 1. Draw subtle background radial gradient
    final bgPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          primaryColor.withAlpha(25),
          const Color(0xFF0A0F1D).withAlpha(0),
        ],
        stops: const [0.0, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: maxRadius));
    canvas.drawCircle(center, maxRadius, bgPaint);

    // 2. Draw Concentric Fixed Grid Circles
    final gridPaint = Paint()
      ..color = primaryColor.withAlpha(40)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    const ringCount = 4;
    for (int i = 1; i <= ringCount; i++) {
      final r = maxRadius * (i / ringCount);
      canvas.drawCircle(center, r, gridPaint);
    }

    // 3. Crosshair Axis Lines
    final axisPaint = Paint()
      ..color = primaryColor.withAlpha(30)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8;

    canvas.drawLine(
      Offset(center.dx - maxRadius, center.dy),
      Offset(center.dx + maxRadius, center.dy),
      axisPaint,
    );
    canvas.drawLine(
      Offset(center.dx, center.dy - maxRadius),
      Offset(center.dx, center.dy + maxRadius),
      axisPaint,
    );

    // 4. Staggered Expanding Pulse Waves
    for (int wave = 0; wave < 3; wave++) {
      final waveOffset = (pulseProgress + (wave / 3.0)) % 1.0;
      final waveRadius = maxRadius * waveOffset;
      final waveOpacity = (1.0 - waveOffset).clamp(0.0, 1.0);

      final pulsePaint = Paint()
        ..color = primaryColor.withAlpha((waveOpacity * 140).toInt())
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0 * (1.0 - waveOffset) + 0.5;

      canvas.drawCircle(center, waveRadius, pulsePaint);

      // Subtle outer glow around wave
      final pulseGlowPaint = Paint()
        ..color = glowColor.withAlpha((waveOpacity * 60).toInt())
        ..style = PaintingStyle.stroke
        ..strokeWidth = 6.0 * (1.0 - waveOffset);
      canvas.drawCircle(center, waveRadius, pulseGlowPaint);
    }

    // 5. Rotating Radar Sweep (Conical Gradient Sector)
    final sweepRect = Rect.fromCircle(center: center, radius: maxRadius);
    final sweepGradient = SweepGradient(
      center: Alignment.center,
      startAngle: 0.0,
      endAngle: 2 * pi,
      colors: [
        primaryColor.withAlpha(0),
        primaryColor.withAlpha(0),
        primaryColor.withAlpha(12),
        primaryColor.withAlpha(90),
      ],
      stops: const [0.0, 0.65, 0.88, 1.0],
      transform: GradientRotation(sweepAngle - pi / 2),
    );

    final sweepPaint = Paint()
      ..shader = sweepGradient.createShader(sweepRect)
      ..style = PaintingStyle.fill;

    canvas.drawCircle(center, maxRadius, sweepPaint);

    // Leading Sweep Needle Line
    final needleAngle = sweepAngle + pi / 2;
    final needleEnd = Offset(
      center.dx + maxRadius * cos(needleAngle),
      center.dy + maxRadius * sin(needleAngle),
    );

    final needlePaint = Paint()
      ..color = primaryColor
      ..strokeWidth = 1.8
      ..shader = LinearGradient(
        colors: [
          primaryColor.withAlpha(20),
          primaryColor,
          Colors.white,
        ],
        stops: const [0.0, 0.85, 1.0],
      ).createShader(Rect.fromPoints(center, needleEnd));

    canvas.drawLine(center, needleEnd, needlePaint);
  }

  @override
  bool shouldRepaint(covariant RadarPainter oldDelegate) {
    return oldDelegate.sweepAngle != sweepAngle ||
        oldDelegate.pulseProgress != pulseProgress;
  }
}
