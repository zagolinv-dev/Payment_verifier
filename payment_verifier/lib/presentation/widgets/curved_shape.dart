import 'dart:math' as math;
import 'package:flutter/material.dart';

class CurvedTopShape extends CustomClipper<Path> {
  const CurvedTopShape({this.heightFactor = 0.45});

  final double heightFactor;

  @override
  Path getClip(Size size) {
    final path = Path()
      ..lineTo(0, size.height * heightFactor)
      ..quadraticBezierTo(
        size.width * 0.25, size.height * (heightFactor + 0.12),
        size.width * 0.5, size.height * heightFactor,
      )
      ..quadraticBezierTo(
        size.width * 0.75, size.height * (heightFactor - 0.08),
        size.width, size.height * (heightFactor + 0.04),
      )
      ..lineTo(size.width, 0)
      ..close();
    return path;
  }

  @override
  bool shouldReclip(covariant CurvedTopShape old) => old.heightFactor != heightFactor;
}

class CurvedBottomShape extends CustomClipper<Path> {
  const CurvedBottomShape({this.heightFactor = 0.2});

  final double heightFactor;

  @override
  Path getClip(Size size) {
    final path = Path()
      ..moveTo(0, size.height * (1 - heightFactor))
      ..quadraticBezierTo(
        size.width * 0.3, size.height * (1 - heightFactor - 0.1),
        size.width * 0.5, size.height * (1 - heightFactor),
      )
      ..quadraticBezierTo(
        size.width * 0.7, size.height * (1 - heightFactor + 0.08),
        size.width, size.height * (1 - heightFactor - 0.04),
      )
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    return path;
  }

  @override
  bool shouldReclip(covariant CurvedBottomShape old) => old.heightFactor != heightFactor;
}

class WavyCurve extends CustomPainter {
  const WavyCurve({required this.color, this.amplitude = 20});

  final Color color;
  final double amplitude;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [color.withOpacity(0.3), color.withOpacity(0.05)],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height))
      ..style = PaintingStyle.fill;

    final path = Path()
      ..moveTo(0, size.height * 0.5);

    for (double x = 0; x <= size.width; x += 1) {
      path.lineTo(
        x,
        size.height * 0.5 + math.sin((x / size.width) * 4 * math.pi) * amplitude,
      );
    }

    path.lineTo(size.width, size.height);
    path.lineTo(0, size.height);
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant WavyCurve old) => old.color != color || old.amplitude != amplitude;
}
