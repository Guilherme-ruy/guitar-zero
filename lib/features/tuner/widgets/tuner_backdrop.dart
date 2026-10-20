import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../app/theme.dart';

/// Luz ambiente e ondas discretas, pintadas sem reconstruir o afinador.
class TunerBackdrop extends StatefulWidget {
  const TunerBackdrop({super.key});

  @override
  State<TunerBackdrop> createState() => _TunerBackdropState();
}

class _TunerBackdropState extends State<TunerBackdrop>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final AnimationController _motion = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 24),
  );
  bool _reduceMotion = false;
  bool _tickerEnabled = true;
  bool _foreground = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final lifecycle = WidgetsBinding.instance.lifecycleState;
    _foreground = lifecycle == null || lifecycle == AppLifecycleState.resumed;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduceMotion = MediaQuery.disableAnimationsOf(context);
    _tickerEnabled = TickerMode.of(context);
    _syncMotion();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    _syncMotion();
  }

  void _syncMotion() {
    if (_foreground && _tickerEnabled && !_reduceMotion) {
      if (!_motion.isAnimating) _motion.repeat();
    } else {
      _motion.stop();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _motion.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: ExcludeSemantics(
      child: RepaintBoundary(
        child: CustomPaint(
          painter: _AmbientPainter(_motion),
          child: const SizedBox.expand(),
        ),
      ),
    ),
  );
}

class _AmbientPainter extends CustomPainter {
  _AmbientPainter(this.motion) : super(repaint: motion);

  final Animation<double> motion;

  @override
  void paint(Canvas canvas, Size size) {
    final bounds = Offset.zero & size;
    final phase = motion.value * math.pi * 2;
    canvas.drawRect(
      bounds,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF151E22), GzColors.background],
        ).createShader(bounds),
    );

    void glow(Offset center, double radius, Color color) {
      final area = Rect.fromCircle(center: center, radius: radius);
      canvas.drawRect(
        bounds,
        Paint()
          ..shader = RadialGradient(
            colors: [color, color.withValues(alpha: 0)],
          ).createShader(area),
      );
    }

    glow(
      Offset(
        size.width * (0.18 + 0.06 * math.sin(phase)),
        size.height * (0.28 + 0.035 * math.cos(phase)),
      ),
      size.width * 0.95,
      GzColors.zero.withValues(alpha: 0.09),
    );
    glow(
      Offset(
        size.width * (0.88 + 0.04 * math.cos(phase)),
        size.height * (0.68 + 0.04 * math.sin(phase)),
      ),
      size.width * 0.85,
      const Color(0xFF7199AD).withValues(alpha: 0.07),
    );

    // Ondas largas de baixa opacidade, com movimento periódico sem salto.
    final wavePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    for (var i = 0; i < 3; i++) {
      final y = size.height * (0.49 + i * 0.12);
      final drift = math.sin(phase + i * 0.8) * size.height * 0.012;
      final path = Path()
        ..moveTo(-size.width * 0.15, y + drift)
        ..cubicTo(
          size.width * 0.24,
          y - size.height * 0.09 + drift,
          size.width * 0.68,
          y + size.height * 0.09 - drift,
          size.width * 1.15,
          y - size.height * 0.035 + drift,
        );
      wavePaint.color = GzColors.zero.withValues(alpha: 0.035 - i * 0.006);
      canvas.drawPath(path, wavePaint);
    }
  }

  @override
  bool shouldRepaint(_AmbientPainter oldDelegate) =>
      oldDelegate.motion != motion;
}
