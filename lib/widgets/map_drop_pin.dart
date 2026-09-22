import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';

import '../services/map_customers.dart';
import '../theme/app_theme.dart';

class MapDropPin extends StatelessWidget {
  const MapDropPin({
    super.key,
    required this.status,
    this.selected = false,
  });

  final ShopPinStatus status;
  final bool selected;

  Color get _color => switch (status) {
        ShopPinStatus.paid => const Color(0xFF2E7D32),
        ShopPinStatus.partial => const Color(0xFFEF6C00),
        ShopPinStatus.due => AppTheme.fabRed,
      };

  /// Grows from city view (~0.62) to building view (~1.18) so the tip stays
  /// on the coordinate while the pin remains readable.
  static double scaleForZoom(double zoom) {
    final t = ((zoom - 11) / 8).clamp(0.0, 1.0);
    return 0.62 + Curves.easeOutCubic.transform(t) * 0.56;
  }

  @override
  Widget build(BuildContext context) {
    final zoom = MapCamera.maybeOf(context)?.zoom ?? 16.5;
    final scale = scaleForZoom(zoom);
    return Transform.scale(
      scale: selected ? scale * 1.12 : scale,
      alignment: Alignment.bottomCenter,
      filterQuality: FilterQuality.high,
      child: SizedBox(
        width: 40,
        height: 54,
        child: CustomPaint(
          painter: _DropPinPainter(color: _color, selected: selected),
          isComplex: true,
        ),
      ),
    );
  }
}

class _DropPinPainter extends CustomPainter {
  _DropPinPainter({required this.color, required this.selected});

  final Color color;
  final bool selected;

  @override
  void paint(Canvas canvas, Size size) {
    final tip = Offset(size.width / 2, size.height - 0.5);
    final cx = size.width / 2;
    final cy = 16.5;
    final r = selected ? 13.2 : 12.0;

    final pin = Path()
      ..moveTo(tip.dx, tip.dy)
      ..quadraticBezierTo(cx - r - 1.5, cy + r * 0.55, cx - r, cy)
      ..arcToPoint(
        Offset(cx + r, cy),
        radius: Radius.circular(r),
        clockwise: true,
      )
      ..quadraticBezierTo(cx + r + 1.5, cy + r * 0.55, tip.dx, tip.dy)
      ..close();

    canvas.drawOval(
      Rect.fromCenter(center: tip.translate(0, 0.4), width: 14, height: 5.5),
      Paint()
        ..color = const Color(0x66000000)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.6),
    );

    canvas.drawPath(
      pin,
      Paint()
        ..isAntiAlias = true
        ..color = color
        ..style = PaintingStyle.fill,
    );
    canvas.drawPath(
      pin,
      Paint()
        ..isAntiAlias = true
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6
        ..strokeJoin = StrokeJoin.round,
    );

    canvas.drawCircle(
      Offset(cx, cy),
      selected ? 5.4 : 4.8,
      Paint()
        ..isAntiAlias = true
        ..color = Colors.white,
    );
    canvas.drawCircle(
      Offset(cx - 2.4, cy - 3.2),
      2.1,
      Paint()
        ..isAntiAlias = true
        ..color = Colors.white.withValues(alpha: 0.45),
    );
  }

  @override
  bool shouldRepaint(covariant _DropPinPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.selected != selected;
}
