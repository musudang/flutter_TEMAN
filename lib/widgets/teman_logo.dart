import 'package:flutter/material.dart';

class TemanLogoWidget extends StatelessWidget {
  final double size;
  const TemanLogoWidget({super.key, required this.size});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _TemanLogoPainter()),
    );
  }
}

class _TemanLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Left person (dark blue)
    final darkBluePaint = Paint()
      ..shader = const LinearGradient(
        colors: [Color(0xFF1E3A8A), Color(0xFF2563EB)],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(Rect.fromLTWH(0, 0, w * 0.5, h));

    // Right person (light blue)
    final lightBluePaint = Paint()
      ..shader = const LinearGradient(
        colors: [Color(0xFF38BDF8), Color(0xFF0EA5E9)],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(Rect.fromLTWH(w * 0.5, 0, w * 0.5, h));

    // Left person head
    canvas.drawCircle(Offset(w * 0.32, h * 0.18), w * 0.10, darkBluePaint);

    // Left person body (arc/semi-circle)
    final leftBodyRect = Rect.fromCenter(
      center: Offset(w * 0.28, h * 0.58),
      width: w * 0.42,
      height: h * 0.55,
    );
    canvas.drawArc(
      leftBodyRect,
      3.14159, // start from bottom-left (pi)
      3.14159, // half circle
      false,
      darkBluePaint
        ..style = PaintingStyle.stroke
        ..strokeWidth = w * 0.09,
    );

    // Right person head
    canvas.drawCircle(
      Offset(w * 0.68, h * 0.12),
      w * 0.09,
      lightBluePaint..style = PaintingStyle.fill,
    );

    // Right person body arc
    final rightBodyRect = Rect.fromCenter(
      center: Offset(w * 0.72, h * 0.52),
      width: w * 0.38,
      height: h * 0.50,
    );
    canvas.drawArc(
      rightBodyRect,
      3.14159,
      3.14159,
      false,
      lightBluePaint
        ..style = PaintingStyle.stroke
        ..strokeWidth = w * 0.085,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
