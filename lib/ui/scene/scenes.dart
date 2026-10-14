import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../theme/tokens.dart';
import 'art.dart';

/// Lays out a fixed 820 x 420 world so it covers the box, anchored to the bottom
/// (like the landing page's `xMidYMax slice`).
void _cover(Canvas canvas, Size size, {double worldW = 820, double worldH = 420, double focusX = 410}) {
  final s = math.max(size.width / worldW, size.height / worldH);
  final visibleW = size.width / s;
  final left = (focusX - visibleW / 2).clamp(0.0, worldW - visibleW);
  canvas.translate(0, size.height - worldH * s);
  canvas.scale(s);
  canvas.translate(-left, 0);
}

/// Looping drives a [CustomPainter] from a repeating controller and pauses when the
/// route is covered or the app is backgrounded (TickerMode).
abstract class _LoopScene extends StatefulWidget {
  const _LoopScene({super.key});
  Duration get period;
  CustomPainter painter(Animation<double> t);
  @override
  State<_LoopScene> createState() => _LoopSceneState();
}

class _LoopSceneState extends State<_LoopScene> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: widget.period);

  @override
  void initState() {
    super.initState();
    if (!WidgetsBinding.instance.platformDispatcher.accessibilityFeatures.disableAnimations) {
      _c.repeat();
    } else {
      _c.value = 0.45;
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => RepaintBoundary(child: CustomPaint(painter: widget.painter(_c), size: Size.infinite));
}

/// Driver side: the shuttle cruising, the campus scrolling past. Used on the driver
/// welcome and as the splash backdrop.
class DriveScene extends _LoopScene {
  const DriveScene({super.key, this.seats = 3});
  final int seats;
  @override
  Duration get period => const Duration(seconds: 6);
  @override
  CustomPainter painter(Animation<double> t) => _DrivePainter(t, seats);
}

class _DrivePainter extends CustomPainter {
  _DrivePainter(this.t, this.seats) : super(repaint: t);
  final Animation<double> t;
  final int seats;

  @override
  void paint(Canvas canvas, Size size) {
    final v = t.value;
    _cover(canvas, size, focusX: 410);
    final scroll = v * 820 * 2; // two screen-widths per loop, so the dashes loop seamlessly
    paintCampus(canvas, scroll: scroll, twinkle: v * 2, parkSign: false);
    paintBus(
      canvas,
      at: const Offset(230, 210),
      scale: 0.7,
      wheelTurns: scroll / wheelCircumference(0.7),
      seats: List.filled(seats, 1.0),
      bob: math.sin(v * 2 * math.pi * 14) * 1.6,
    );
  }

  @override
  bool shouldRepaint(_DrivePainter old) => false;
}

/// Pulsing sound rings behind the driver's "₦200 received" alert.
class SoundRings extends StatefulWidget {
  const SoundRings({super.key, required this.child, this.color = K.yellow});
  final Widget child;
  final Color color;
  @override
  State<SoundRings> createState() => _SoundRingsState();
}

class _SoundRingsState extends State<SoundRings> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 2200))..repeat();
  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => CustomPaint(
        painter: _RingsPainter(_c, widget.color),
        child: widget.child,
      );
}

class _RingsPainter extends CustomPainter {
  _RingsPainter(this.t, this.color) : super(repaint: t);
  final Animation<double> t;
  final Color color;
  @override
  void paint(Canvas canvas, Size size) {
    final r = RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(28));
    for (var i = 0; i < 3; i++) {
      final p = (t.value + i / 3) % 1;
      canvas.drawRRect(r.inflate(p * 34), Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..color = color.withValues(alpha: (1 - p) * 0.5));
    }
  }

  @override
  bool shouldRepaint(_RingsPainter old) => false;
}
