import 'package:flutter/material.dart';

import '../theme/tokens.g.dart';

/// Mochi — the KnowBody cat, painted to match the handoff (cream fur, dark eyes,
/// salmon nose, a lime leaf sprout). Mood nudges the eyes/mouth.
class Mochi extends StatelessWidget {
  const Mochi({super.key, this.size = 132, this.mood = 'content'});
  final double size;
  final String mood;

  @override
  Widget build(BuildContext context) =>
      SizedBox(width: size, height: size, child: CustomPaint(painter: _MochiPainter(mood)));
}

/// Mochi with a gentle idle animation — bobs, breathes, and blinks. When the
/// mood is 'cheering' it hops a little more. Tap to make it hop.
class AnimatedMochi extends StatefulWidget {
  const AnimatedMochi({super.key, this.size = 132, this.mood = 'content'});
  final double size;
  final String mood;
  @override
  State<AnimatedMochi> createState() => _AnimatedMochiState();
}

class _AnimatedMochiState extends State<AnimatedMochi> with TickerProviderStateMixin {
  late final AnimationController _idle;
  late final AnimationController _hop;

  @override
  void initState() {
    super.initState();
    _idle = AnimationController(vsync: this, duration: const Duration(milliseconds: 2200))..repeat(reverse: true);
    _hop = AnimationController(vsync: this, duration: const Duration(milliseconds: 520));
  }

  @override
  void dispose() {
    _idle.dispose();
    _hop.dispose();
    super.dispose();
  }

  void _tapHop() {
    _hop.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    final cheering = widget.mood == 'cheering';
    return GestureDetector(
      onTap: _tapHop,
      child: AnimatedBuilder(
        animation: Listenable.merge([_idle, _hop]),
        builder: (_, child) {
          final t = _idle.value; // 0..1..0
          // idle bob + breathing squash
          final bob = (0.5 - (t - 0.5).abs()) * (cheering ? 14 : 7); // px up
          final squashX = 1 + (t - 0.5) * 0.04;
          final squashY = 1 - (t - 0.5) * 0.04;
          // tap hop (a quick up-and-down with a little scale pop)
          final hop = _hop.value;
          final hopUp = (hop == 0) ? 0.0 : (1 - (2 * hop - 1).abs()) * 26;
          final hopScale = (hop == 0) ? 1.0 : 1 + (1 - (2 * hop - 1).abs()) * 0.06;
          return Transform.translate(
            offset: Offset(0, -bob - hopUp),
            child: Transform.scale(
              scaleX: squashX * hopScale,
              scaleY: squashY * hopScale,
              child: child,
            ),
          );
        },
        child: Mochi(size: widget.size, mood: widget.mood),
      ),
    );
  }
}

class _MochiPainter extends CustomPainter {
  _MochiPainter(this.mood);
  final String mood;

  @override
  void paint(Canvas canvas, Size s) {
    final w = s.width, h = s.height;
    final fur = Paint()..color = KbTokens.petFurColor;
    final belly = Paint()..color = KbTokens.petBellyColor;
    final eye = Paint()..color = KbTokens.petEyeColor;
    final nose = Paint()..color = KbTokens.petNoseColor;
    final cheek = Paint()..color = KbTokens.petCheekColor;

    RRect rr(double l, double t, double ww, double hh, double r) =>
        RRect.fromRectAndRadius(Rect.fromLTWH(l * w, t * h, ww * w, hh * h), Radius.circular(r * w));

    // ears
    final earPath = Path()
      ..addPolygon([Offset(0.14 * w, 0.30 * h), Offset(0.22 * w, 0.02 * h), Offset(0.34 * w, 0.30 * h)], true)
      ..addPolygon([Offset(0.66 * w, 0.30 * h), Offset(0.78 * w, 0.02 * h), Offset(0.86 * w, 0.30 * h)], true);
    canvas.drawPath(earPath, fur);
    final innerEar = Path()
      ..addPolygon([Offset(0.18 * w, 0.28 * h), Offset(0.23 * w, 0.10 * h), Offset(0.29 * w, 0.28 * h)], true)
      ..addPolygon([Offset(0.71 * w, 0.28 * h), Offset(0.77 * w, 0.10 * h), Offset(0.82 * w, 0.28 * h)], true);
    canvas.drawPath(innerEar, Paint()..color = KbTokens.petNoseColor.withValues(alpha: 0.7));

    // body + head
    canvas.drawRRect(rr(0.16, 0.42, 0.68, 0.58, 0.34), fur);
    canvas.drawRRect(rr(0.33, 0.70, 0.34, 0.28, 0.20), belly);
    canvas.drawRRect(rr(0.13, 0.18, 0.74, 0.66, 0.40), fur);

    // eyes (sleepy = thin line)
    if (mood == 'sleepy') {
      final line = Paint()
        ..color = KbTokens.petEyeColor
        ..strokeWidth = 0.02 * w
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(Offset(0.30 * w, 0.48 * h), Offset(0.40 * w, 0.48 * h), line);
      canvas.drawLine(Offset(0.60 * w, 0.48 * h), Offset(0.70 * w, 0.48 * h), line);
    } else {
      canvas.drawRRect(rr(0.31, 0.44, 0.09, 0.11, 0.05), eye);
      canvas.drawRRect(rr(0.60, 0.44, 0.09, 0.11, 0.05), eye);
    }

    // cheeks + nose/mouth
    canvas.drawRRect(rr(0.24, 0.56, 0.13, 0.07, 0.04), cheek);
    canvas.drawRRect(rr(0.63, 0.56, 0.13, 0.07, 0.04), cheek);
    final mouth = Path()
      ..addRRect(rr(0.46, 0.57, 0.08, 0.05, 0.03));
    canvas.drawPath(mouth, nose);

    // lime leaf sprout
    canvas.drawRRect(
      RRect.fromRectAndCorners(
        Rect.fromLTWH(0.45 * w, -0.03 * h, 0.15 * w, 0.15 * h),
        topLeft: Radius.circular(0.08 * w),
        topRight: Radius.circular(0.08 * w),
        bottomRight: Radius.circular(0.02 * w),
        bottomLeft: Radius.circular(0.08 * w),
      ),
      Paint()..color = KbTokens.limeColor,
    );
    canvas.drawRect(Rect.fromLTWH(0.52 * w, 0.10 * h, 0.02 * w, 0.09 * h), Paint()..color = KbTokens.limeStemColor);
  }

  @override
  bool shouldRepaint(_MochiPainter old) => old.mood != mood;
}
