import 'package:flutter/material.dart';

/// Balance dot. Green is a zero balance, red is money still owed.
class GlowShopPin extends StatelessWidget {
  const GlowShopPin({
    super.key,
    this.selected = false,
    this.size = 22,
    this.color = const Color(0xFF16A34A),
  });

  final bool selected;
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final d = selected ? size * 1.18 : size;
    return IgnorePointer(
      ignoring: false,
      child: SizedBox(
        width: d * 2.2,
        height: d * 2.2,
        child: CustomPaint(
          painter: _GlowDotPainter(selected: selected, color: color),
        ),
      ),
    );
  }
}

class _GlowDotPainter extends CustomPainter {
  _GlowDotPainter({required this.selected, required this.color});

  final bool selected;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final r = selected ? 8.5 : 7.0;
    canvas.drawCircle(
      c,
      r * 2.4,
      Paint()
        ..color = color.withValues(alpha: selected ? 0.38 : 0.22)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
    );
    canvas.drawCircle(
      c,
      r * 1.35,
      Paint()
        ..color = color.withValues(alpha: 0.55)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.2),
    );
    canvas.drawCircle(c, r, Paint()..color = color);
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = selected ? 2.4 : 1.8,
    );
    canvas.drawCircle(
      c.translate(-r * 0.28, -r * 0.32),
      r * 0.28,
      Paint()..color = Colors.white.withValues(alpha: 0.55),
    );
  }

  @override
  bool shouldRepaint(covariant _GlowDotPainter oldDelegate) =>
      oldDelegate.selected != selected || oldDelegate.color != color;
}
