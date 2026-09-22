import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

class SignaturePadDialog extends StatefulWidget {
  const SignaturePadDialog({super.key});

  static Future<String?> capture(BuildContext context) {
    return showDialog<String>(
      context: context,
      builder: (_) => const SignaturePadDialog(),
    );
  }

  @override
  State<SignaturePadDialog> createState() => _SignaturePadDialogState();
}

class _SignaturePadDialogState extends State<SignaturePadDialog> {
  final _points = <Offset?>[];
  final _key = GlobalKey();

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Sign here'),
      content: SizedBox(
        width: 320,
        height: 180,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: const Color(0xFFCBD5E1)),
            borderRadius: BorderRadius.circular(8),
          ),
          child: GestureDetector(
            onPanStart: (d) => setState(() => _points.add(d.localPosition)),
            onPanUpdate: (d) => setState(() => _points.add(d.localPosition)),
            onPanEnd: (_) => setState(() => _points.add(null)),
            child: RepaintBoundary(
              key: _key,
              child: CustomPaint(
                painter: _SigPainter(_points),
                child: const SizedBox.expand(),
              ),
            ),
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => setState(_points.clear), child: const Text('Clear')),
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(
          onPressed: () async {
            final bytes = await _export();
            if (!context.mounted) return;
            Navigator.pop(context, bytes == null ? null : base64Encode(bytes));
          },
          child: const Text('Save'),
        ),
      ],
    );
  }

  Future<Uint8List?> _export() async {
    final boundary = _key.currentContext?.findRenderObject() as RenderRepaintBoundary?;
    if (boundary == null) return null;
    final image = await boundary.toImage(pixelRatio: 2);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    return data?.buffer.asUint8List();
  }
}

class _SigPainter extends CustomPainter {
  _SigPainter(this.points);
  final List<Offset?> points;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black
      ..strokeWidth = 2.4
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    for (var i = 0; i < points.length - 1; i++) {
      final a = points[i];
      final b = points[i + 1];
      if (a != null && b != null) canvas.drawLine(a, b, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _SigPainter oldDelegate) => true;
}
