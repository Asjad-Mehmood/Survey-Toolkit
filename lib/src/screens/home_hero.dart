// The picture on the right of Home's banner: contour lines, layered hills with pines and a total
// station on its tripod. Drawn in code, so it is sharp at any size and needs no image file. It fills
// its own box; the banner gives it the right half and fades its left edge in.
import 'dart:math' as math;

import 'package:flutter/material.dart';

class SurveyScene extends StatelessWidget {
  const SurveyScene({super.key, required this.dark, this.start = 0.44});
  final bool dark;

  /// Where the scene begins, as a share of the banner's width (it fades in from there)
  final double start;

  @override
  Widget build(BuildContext context) => CustomPaint(painter: _ScenePainter(dark, start), size: Size.infinite);
}

class _ScenePainter extends CustomPainter {
  _ScenePainter(this.dark, this.start);
  final bool dark;
  final double start;

  @override
  void paint(Canvas canvas, Size size) {
    final full = Offset.zero & size;
    // drawn in a layer of its own, then faded in from the left over the whole banner, so there is
    // no edge anywhere
    canvas.saveLayer(full, Paint());
    canvas.save();
    canvas.translate(size.width * start, 0);
    _scene(canvas, Size(size.width * (1 - start), size.height));
    canvas.restore();
    canvas.drawRect(
      full,
      Paint()
        ..blendMode = BlendMode.dstIn
        ..shader = LinearGradient(
          colors: const [Colors.transparent, Colors.transparent, Colors.black],
          stops: [0, start + 0.04, start + 0.24],
        ).createShader(full),
    );
    canvas.restore();
  }

  void _scene(Canvas canvas, Size size) {
    final w = size.width, h = size.height;

    // contour lines, like a survey plan, faint across the whole banner
    final contour = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = (dark ? Colors.white : const Color(0xFF3B5BA8)).withValues(alpha: dark ? 0.07 : 0.09);
    for (var i = 0; i < 9; i++) {
      final y0 = h * (0.1 + i * 0.1);
      final path = Path()..moveTo(0, y0);
      for (var x = 0.0; x <= w + 20; x += 20) {
        final t = (x / w) * math.pi * 2;
        path.lineTo(x, y0 + math.sin(t * 1.3 + i * 0.7) * 10 + math.cos(t * 0.6 + i) * 6);
      }
      canvas.drawPath(path, contour);
    }

    // the hills, three layers, palest at the back
    final hills = dark
        ? [const Color(0xFF243150), const Color(0xFF2A3A60), const Color(0xFF314575)]
        : [const Color(0xFFD3DFF6), const Color(0xFFB9CBEE), const Color(0xFF9CB3E3)];
    void hill(double base, double amp, double phase, Color colour) {
      final p = Path()..moveTo(0, h);
      for (var x = 0.0; x <= w; x += 8) {
        final t = x / w;
        final y =
            h * base - math.sin(t * math.pi * 1.4 + phase) * amp - math.sin(t * math.pi * 3.1 + phase) * amp * 0.25;
        // rises gently out of the banner's foot on the left, no hard edge
        final e = (t / 0.3).clamp(0.0, 1.0), rise = e * e * (3 - 2 * e);
        p.lineTo(x, h - (h - y) * rise);
      }
      p
        ..lineTo(w, h)
        ..close();
      canvas.drawPath(p, Paint()..color = colour);
    }

    hill(0.6, h * 0.26, 0.4, hills[0]);
    hill(0.78, h * 0.17, 1.6, hills[1]);
    hill(0.93, h * 0.08, 2.4, hills[2]);

    // pines on the near hill
    final pine = Paint()..color = dark ? const Color(0xFF3D5590) : const Color(0xFF7C97D2);
    for (final (fx, s) in [(0.8, 1.0), (0.86, 0.8), (0.91, 1.15), (0.96, 0.75), (0.26, 0.7), (0.32, 0.9)]) {
      final x = w * fx, base = h * 0.9, ph = h * 0.2 * s;
      for (var k = 0; k < 3; k++) {
        final top = base - ph + k * ph * 0.24, half = ph * (0.16 + k * 0.07);
        canvas.drawPath(
          Path()
            ..moveTo(x, top)
            ..lineTo(x - half, top + ph * 0.34)
            ..lineTo(x + half, top + ph * 0.34)
            ..close(),
          pine,
        );
      }
      canvas.drawRect(Rect.fromLTWH(x - 1.2, base - ph * 0.05, 2.4, ph * 0.08), pine);
    }

    // the total station on its tripod
    final cx = w * 0.6, head = h * 0.4, ground = h * 1.02;
    final unit = h / 170;
    final leg = Paint()
      ..color = const Color(0xFFE0A526)
      ..strokeWidth = 6 * unit
      ..strokeCap = StrokeCap.round;
    final legDark = Paint()
      ..color = const Color(0xFFB57F12)
      ..strokeWidth = 6 * unit
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(cx, head + 20 * unit), Offset(cx - 52 * unit, ground), leg);
    canvas.drawLine(Offset(cx, head + 20 * unit), Offset(cx + 52 * unit, ground), legDark);
    canvas.drawLine(Offset(cx, head + 20 * unit), Offset(cx + 8 * unit, ground), leg);
    // the leg clamps
    final clamp = Paint()..color = const Color(0xFF39445C);
    for (final (dx, t) in [(-52.0, 0.55), (52.0, 0.55), (8.0, 0.55)]) {
      final p = Offset.lerp(Offset(cx, head + 20 * unit), Offset(cx + dx * unit, ground), t)!;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: p, width: 10 * unit, height: 6 * unit),
          Radius.circular(2 * unit),
        ),
        clamp,
      );
    }
    // the tripod head and the base of the instrument
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(cx, head + 20 * unit), width: 46 * unit, height: 8 * unit),
        Radius.circular(3 * unit),
      ),
      Paint()..color = const Color(0xFF39445C),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(cx, head + 12 * unit), width: 36 * unit, height: 8 * unit),
        Radius.circular(3 * unit),
      ),
      Paint()..color = const Color(0xFF4A5672),
    );
    // the body, with a soft shine on its left
    final body = Rect.fromCenter(center: Offset(cx, head - 22 * unit), width: 44 * unit, height: 56 * unit);
    canvas.drawRRect(
      RRect.fromRectAndRadius(body, Radius.circular(8 * unit)),
      Paint()..shader = const LinearGradient(colors: [Color(0xFFFFD36A), Color(0xFFE9AE2C)]).createShader(body),
    );
    // the handle over the top
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(body.left + 6 * unit, body.top - 14 * unit, body.width - 12 * unit, 18 * unit),
        Radius.circular(6 * unit),
      ),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4 * unit
        ..color = const Color(0xFF39445C),
    );
    // the keypad screen
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(body.left + 7 * unit, body.bottom - 20 * unit, body.width - 14 * unit, 12 * unit),
        Radius.circular(2 * unit),
      ),
      Paint()..color = const Color(0xFF8FB4E8),
    );
    // the telescope lens
    final lens = Offset(cx, body.top + 20 * unit);
    canvas.drawCircle(lens, 13 * unit, Paint()..color = const Color(0xFF39445C));
    canvas.drawCircle(lens, 9 * unit, Paint()..color = const Color(0xFF1B2540));
    canvas.drawCircle(lens, 5 * unit, Paint()..color = const Color(0xFF4F7CD6));
    canvas.drawCircle(
      lens + Offset(-3 * unit, -3 * unit),
      2 * unit,
      Paint()..color = Colors.white.withValues(alpha: 0.85),
    );
  }

  @override
  bool shouldRepaint(_ScenePainter old) => old.dark != dark || old.start != start;
}
