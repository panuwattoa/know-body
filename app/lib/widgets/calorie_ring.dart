import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../theme/tokens.g.dart';

/// The signature calorie-left ring: a thick ink arc on a faint track, filling
/// clockwise from the top. The arc sweeps in and the number counts up on load
/// (and animates old→new on refresh).
class CalorieRing extends StatelessWidget {
  const CalorieRing({
    super.key,
    required this.kcalLeft,
    required this.pct,
    this.label = 'KCAL LEFT',
    this.size = 150,
    this.stroke = 16,
    this.trackColor = const Color(0x24121212),
    this.arcColor = KbTokens.inkColor,
    this.animate = true,
    this.duration = const Duration(milliseconds: 900),
  });

  final int kcalLeft;
  final double pct; // 0..1 consumed
  final String label;
  final double size, stroke;
  final Color trackColor, arcColor;
  final bool animate;
  final Duration duration;

  @override
  Widget build(BuildContext context) {
    final dur = animate ? duration : Duration.zero;
    return SizedBox(
      width: size,
      height: size,
      child: TweenAnimationBuilder<double>(
        tween: Tween(end: pct.clamp(0, 1).toDouble()),
        duration: dur,
        curve: Curves.easeOutCubic,
        builder: (_, animPct, __) => CustomPaint(
          painter: _RingPainter(pct: animPct, stroke: stroke, track: trackColor, arc: arcColor),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TweenAnimationBuilder<double>(
                  tween: Tween(end: kcalLeft.toDouble()),
                  duration: dur,
                  curve: Curves.easeOutCubic,
                  builder: (_, val, __) => Text(
                    '${val.round()}',
                    style: TextStyle(
                        fontSize: size * 0.25,
                        fontWeight: FontWeight.w600,
                        letterSpacing: -1,
                        color: KbTokens.inkColor),
                  ),
                ),
                Text(label,
                    style: const TextStyle(
                        fontSize: 11, fontWeight: FontWeight.w500, letterSpacing: 0.8, color: KbTokens.inkSoftColor)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({required this.pct, required this.stroke, required this.track, required this.arc});
  final double pct, stroke;
  final Color track, arc;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = (size.width - stroke) / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);

    final trackPaint = Paint()
      ..color = track
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke;
    canvas.drawCircle(center, radius, trackPaint);

    final arcPaint = Paint()
      ..color = arc
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = stroke;
    canvas.drawArc(rect, -math.pi / 2, 2 * math.pi * pct, false, arcPaint);
  }

  @override
  bool shouldRepaint(_RingPainter old) => old.pct != pct || old.arc != arc || old.track != track;
}
