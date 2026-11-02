import 'dart:math' as math;

import 'package:flutter/material.dart';

/// The moon as it looks on lunar day [lunarDay]: new on day 1, full around day 15.
class MoonPhase extends StatelessWidget {
  const MoonPhase({super.key, required this.lunarDay, this.size = 40, required this.lit, required this.shadow});

  final int lunarDay;
  final double size;
  final Color lit;
  final Color shadow;

  @override
  Widget build(BuildContext context) =>
      CustomPaint(size: Size.square(size), painter: _MoonPainter(lunarDay, lit, shadow));
}

class _MoonPainter extends CustomPainter {
  _MoonPainter(this.lunarDay, this.lit, this.shadow);

  final int lunarDay;
  final Color lit;
  final Color shadow;

  @override
  void paint(Canvas canvas, Size size) {
    final r = size.width / 2;
    final c = Offset(r, r);
    final litPaint = Paint()..color = lit;
    final shadowPaint = Paint()..color = shadow;
    final glow = Paint()
      ..color = lit.withValues(alpha: 0.35)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);

    final p = ((lunarDay - 1) / 29.53).clamp(0.0, 0.999); // 0 new moon, 0.5 full moon
    final illumination = (1 - math.cos(2 * math.pi * p)) / 2;
    if (illumination > 0.3) canvas.drawCircle(c, r * illumination, glow);
    canvas.drawCircle(c, r, shadowPaint);
    if (lunarDay <= 1) return;

    final waxing = p < 0.5;
    final disk = Rect.fromCircle(center: c, radius: r);
    // Lit half: the right one while waxing, the left one while waning.
    final half = Path()
      ..moveTo(r, 0)
      ..arcTo(disk, -math.pi / 2, waxing ? math.pi : -math.pi, false)
      ..close();
    // The terminator is a half-ellipse: cut out of the lit half (crescent) or added to it (gibbous).
    // Combined into one path so the translucent shadow is never painted over the light.
    final k = math.cos(2 * math.pi * p);
    final ellipse = Path()..addOval(Rect.fromCenter(center: c, width: 2 * r * k.abs(), height: 2 * r));
    canvas.drawPath(Path.combine(k > 0 ? PathOperation.difference : PathOperation.union, half, ellipse), litPaint);
  }

  @override
  bool shouldRepaint(_MoonPainter old) => old.lunarDay != lunarDay || old.lit != lit || old.shadow != shadow;
}
