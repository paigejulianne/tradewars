import 'dart:math';
import 'package:flutter/material.dart';

/// A cheap animated starfield used behind auth screens and as a subtle
/// backdrop for the game shell. Purely decorative — gives the "graphical"
/// space feel without needing image assets.
class StarfieldBackground extends StatefulWidget {
  final Widget child;
  final int starCount;
  const StarfieldBackground({super.key, required this.child, this.starCount = 140});

  @override
  State<StarfieldBackground> createState() => _StarfieldBackgroundState();
}

class _StarfieldBackgroundState extends State<StarfieldBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final List<_Star> _stars;

  @override
  void initState() {
    super.initState();
    final rnd = Random(42);
    _stars = List.generate(widget.starCount, (_) => _Star.random(rnd));
    _controller = AnimationController(vsync: this, duration: const Duration(seconds: 60))
      ..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: DecoratedBox(
            decoration: const BoxDecoration(
              gradient: RadialGradient(
                center: Alignment(0.1, -0.4),
                radius: 1.4,
                colors: [Color(0xFF161A3A), Color(0xFF05060F)],
              ),
            ),
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, _) => CustomPaint(
                painter: _StarfieldPainter(_stars, _controller.value),
                size: Size.infinite,
              ),
            ),
          ),
        ),
        widget.child,
      ],
    );
  }
}

class _Star {
  final double x, y, radius, twinkleOffset, driftSpeed;
  _Star(this.x, this.y, this.radius, this.twinkleOffset, this.driftSpeed);
  factory _Star.random(Random r) => _Star(
        r.nextDouble(),
        r.nextDouble(),
        r.nextDouble() * 1.6 + 0.3,
        r.nextDouble(),
        r.nextDouble() * 0.02 + 0.005,
      );
}

class _StarfieldPainter extends CustomPainter {
  final List<_Star> stars;
  final double t;
  _StarfieldPainter(this.stars, this.t);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint();
    for (final s in stars) {
      final twinkle = (sin((t * 2 * pi) + s.twinkleOffset * 2 * pi) + 1) / 2;
      final dy = (s.y + t * s.driftSpeed) % 1.0;
      paint.color = Colors.white.withValues(alpha: 0.25 + twinkle * 0.65);
      canvas.drawCircle(Offset(s.x * size.width, dy * size.height), s.radius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _StarfieldPainter oldDelegate) => oldDelegate.t != t;
}
