import 'dart:math' as math;

import 'package:flutter/material.dart';

class MoodStyle {
  const MoodStyle(this.key, this.label, this.color);

  final String key;
  final String label;
  final Color color;
}

const moodStyles = [
  MoodStyle('happy', 'Happy', Color(0xFFF6C453)),
  MoodStyle('calm', 'Calm', Color(0xFF7EC4CF)),
  MoodStyle('anxious', 'Anxious', Color(0xFF7FA3D9)),
  MoodStyle('stressed', 'Stressed', Color(0xFFE58A8A)),
  MoodStyle('tired', 'Tired', Color(0xFFB4A3D6)),
];

MoodStyle moodStyle(String key) => moodStyles.firstWhere((m) => m.key == key, orElse: () => moodStyles.first);

/// Hand-drawn mood face so moods look consistent on every platform.
class MoodFace extends StatelessWidget {
  const MoodFace(this.mood, {super.key, this.size = 40});

  final String mood;
  final double size;

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: size,
    child: CustomPaint(painter: _FacePainter(moodStyle(mood))),
  );
}

class _FacePainter extends CustomPainter {
  _FacePainter(this.style);

  final MoodStyle style;

  @override
  void paint(Canvas canvas, Size size) {
    final r = size.width / 2;
    final c = Offset(r, r);
    canvas.drawCircle(c, r, Paint()..color = style.color);
    canvas.drawCircle(c + Offset(-r * 0.15, -r * 0.2), r * 0.55, Paint()..color = Colors.white.withValues(alpha: 0.18));

    final ink = Paint()
      ..color = const Color(0xFF3A3A3A)
      ..style = PaintingStyle.stroke
      ..strokeWidth = r * 0.11
      ..strokeCap = StrokeCap.round;
    final dot = Paint()..color = const Color(0xFF3A3A3A);
    final eyeL = c + Offset(-r * 0.33, -r * 0.12);
    final eyeR = c + Offset(r * 0.33, -r * 0.12);
    Rect mouth(double w, double h, double dy) => Rect.fromCenter(center: c + Offset(0, dy * r), width: w * r, height: h * r);

    switch (style.key) {
      case 'happy':
        canvas.drawCircle(eyeL, r * 0.09, dot);
        canvas.drawCircle(eyeR, r * 0.09, dot);
        canvas.drawArc(mouth(0.8, 0.6, 0.12), 0.15, math.pi - 0.3, false, ink);
      case 'calm':
        for (final e in [eyeL, eyeR]) {
          canvas.drawArc(Rect.fromCenter(center: e, width: r * 0.3, height: r * 0.22), 0.2, math.pi - 0.4, false, ink);
        }
        canvas.drawArc(mouth(0.5, 0.35, 0.3), 0.3, math.pi - 0.6, false, ink);
      case 'anxious':
        canvas.drawCircle(eyeL, r * 0.09, dot);
        canvas.drawCircle(eyeR, r * 0.09, dot);
        canvas.drawLine(eyeL + Offset(-r * 0.12, -r * 0.2), eyeL + Offset(r * 0.1, -r * 0.28), ink);
        canvas.drawLine(eyeR + Offset(r * 0.12, -r * 0.2), eyeR + Offset(-r * 0.1, -r * 0.28), ink);
        canvas.drawOval(mouth(0.22, 0.26, 0.42), ink);
      case 'stressed':
        canvas.drawLine(eyeL + Offset(-r * 0.12, -r * 0.08), eyeL + Offset(r * 0.12, r * 0.04), ink);
        canvas.drawLine(eyeR + Offset(r * 0.12, -r * 0.08), eyeR + Offset(-r * 0.12, r * 0.04), ink);
        canvas.drawArc(mouth(0.6, 0.45, 0.55), math.pi + 0.3, math.pi - 0.6, false, ink);
      default:
        for (final e in [eyeL, eyeR]) {
          canvas.drawLine(e + Offset(-r * 0.13, 0), e + Offset(r * 0.13, 0), ink);
        }
        canvas.drawLine(c + Offset(-r * 0.2, r * 0.42), c + Offset(r * 0.2, r * 0.42), ink);
    }
  }

  @override
  bool shouldRepaint(_FacePainter old) => old.style != style;
}
