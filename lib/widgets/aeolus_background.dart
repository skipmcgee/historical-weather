import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../theme/aeolus_theme.dart';

/// The app's backdrop: a stormy night-sky gradient with slowly drifting
/// golden/cyan wind spirals and a scatter of wind-blown motes, evoking
/// Aeolus's floating island of Aeolia. Purely procedural (no image assets),
/// so it stays crisp at any window size and adapts to light/dark mode.
class AeolusBackground extends StatefulWidget {
  const AeolusBackground({super.key});

  @override
  State<AeolusBackground> createState() => _AeolusBackgroundState();
}

class _AeolusBackgroundState extends State<AeolusBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final List<_Spiral> _spirals;
  late final List<_Mote> _motes;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(seconds: 180))..repeat();
    final rnd = math.Random(1201);
    _spirals = List.generate(3, (i) {
      return _Spiral(
        turns: 2.4 + i * 0.6,
        radiusFactor: 0.22 + i * 0.14,
        anchor: Alignment(-0.6 + i * 0.55, -0.5 + i * 0.7),
        speed: (i.isEven ? 1.0 : -0.7) * (0.5 + rnd.nextDouble() * 0.3),
        strokeWidth: 1.4 + i * 0.4,
      );
    });
    _motes = List.generate(46, (i) {
      return _Mote(
        position: Offset(rnd.nextDouble(), rnd.nextDouble()),
        radius: 0.6 + rnd.nextDouble() * 1.8,
        opacity: 0.15 + rnd.nextDouble() * 0.35,
        drift: 0.4 + rnd.nextDouble() * 0.6,
      );
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final palette = isDark ? AeolusPalette.dark : AeolusPalette.light;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return CustomPaint(
          painter: _AeolusPainter(
            progress: _controller.value,
            palette: palette,
            isDark: isDark,
            spirals: _spirals,
            motes: _motes,
          ),
          size: Size.infinite,
        );
      },
    );
  }
}

class _Spiral {
  _Spiral({
    required this.turns,
    required this.radiusFactor,
    required this.anchor,
    required this.speed,
    required this.strokeWidth,
  });

  final double turns;
  final double radiusFactor;
  final Alignment anchor;
  final double speed;
  final double strokeWidth;
}

class _Mote {
  _Mote({required this.position, required this.radius, required this.opacity, required this.drift});

  final Offset position;
  final double radius;
  final double opacity;
  final double drift;
}

class _AeolusPainter extends CustomPainter {
  _AeolusPainter({
    required this.progress,
    required this.palette,
    required this.isDark,
    required this.spirals,
    required this.motes,
  });

  final double progress;
  final AeolusPalette palette;
  final bool isDark;
  final List<_Spiral> spirals;
  final List<_Mote> motes;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;

    final sky = Paint()
      ..shader = ui.Gradient.linear(
        rect.topLeft,
        rect.bottomRight,
        [palette.skyTop, palette.skyBottom],
      );
    canvas.drawRect(rect, sky);

    for (final spiral in spirals) {
      _drawSpiral(canvas, size, spiral);
    }

    for (final mote in motes) {
      final dx = (mote.position.dx + progress * mote.drift * 0.06) % 1.0;
      final center = Offset(dx * size.width, mote.position.dy * size.height);
      final paint = Paint()
        ..color = (isDark ? palette.wind : palette.storm).withValues(alpha: mote.opacity)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.2);
      canvas.drawCircle(center, mote.radius, paint);
    }
  }

  void _drawSpiral(Canvas canvas, Size size, _Spiral spiral) {
    final center = Offset(
      size.width * (0.5 + spiral.anchor.x * 0.5),
      size.height * (0.5 + spiral.anchor.y * 0.5),
    );
    final maxRadius = size.longestSide * spiral.radiusFactor;
    final rotation = progress * spiral.speed * 2 * math.pi;

    final path = Path();
    const steps = 220;
    for (var i = 0; i <= steps; i++) {
      final t = i / steps;
      final angle = t * spiral.turns * 2 * math.pi + rotation;
      final r = maxRadius * t;
      final point = center + Offset(math.cos(angle) * r, math.sin(angle) * r * 0.7);
      if (i == 0) {
        path.moveTo(point.dx, point.dy);
      } else {
        path.lineTo(point.dx, point.dy);
      }
    }

    final color = spiral.strokeWidth > 2 ? palette.gold : palette.wind;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = spiral.strokeWidth
      ..strokeCap = StrokeCap.round
      ..color = color.withValues(alpha: isDark ? 0.22 : 0.16)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _AeolusPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.isDark != isDark;
}
