import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../app/theme.dart';

/// Medidor horizontal de desvio em cents, centrado no "zero".
///
/// O indicador converge para o anel central conforme a afinação se aproxima
/// de 0 cents; dentro da tolerância, o anel se preenche. A suavização aqui é
/// apenas interpolação visual entre leituras — a estabilização do sinal é
/// responsabilidade do engine (filtros DSP).
class ZeroMeter extends StatelessWidget {
  const ZeroMeter({
    super.key,
    required this.cents,
    required this.isInTune,
    this.range = 50,
  });

  /// Desvio atual, ou `null` quando nenhuma nota está soando.
  final double? cents;
  final bool isInTune;

  /// Desvio máximo representado em cada lado, em cents.
  final double range;

  @override
  Widget build(BuildContext context) {
    final active = cents != null;
    return Row(
      children: [
        const _SideLabel('♭'),
        Expanded(
          child: SizedBox(
            height: 88,
            child: TweenAnimationBuilder<double>(
              tween: Tween(end: active ? 1 : 0),
              duration: GzDurations.state,
              builder: (context, presence, _) => TweenAnimationBuilder<double>(
                tween: Tween(end: (cents ?? 0).clamp(-range, range)),
                duration: GzDurations.reading,
                curve: Curves.easeOut,
                builder: (context, animatedCents, _) => CustomPaint(
                  painter: _ZeroMeterPainter(
                    cents: animatedCents,
                    presence: presence,
                    isInTune: active && isInTune,
                    range: range,
                  ),
                ),
              ),
            ),
          ),
        ),
        const _SideLabel('♯'),
      ],
    );
  }
}

class _SideLabel extends StatelessWidget {
  const _SideLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 28,
    child: Text(
      text,
      textAlign: TextAlign.center,
      style: const TextStyle(fontSize: 22, color: GzColors.textSecondary),
    ),
  );
}

class _ZeroMeterPainter extends CustomPainter {
  _ZeroMeterPainter({
    required this.cents,
    required this.presence,
    required this.isInTune,
    required this.range,
  });

  final double cents;
  final double presence;
  final bool isInTune;
  final double range;

  static const double _ringRadius = 24;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final halfWidth = size.width / 2 - 8;
    double xFor(double c) => center.dx + c / range * halfWidth;

    final color = Color.lerp(
      GzColors.line,
      GzColors.forCents(cents),
      presence,
    )!;

    // Escala: marcas a cada 5 cents, maiores a cada 10.
    final tickPaint = Paint()
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 1.5;
    for (var c = -range; c <= range; c += 5) {
      if (c.abs() < 1) continue;
      final x = xFor(c);
      if ((x - center.dx).abs() < _ringRadius + 6) continue;
      final major = c.round() % 10 == 0;
      final h = major ? 14.0 : 7.0;
      final near = 1 - ((c - cents).abs() / 12).clamp(0.0, 1.0);
      tickPaint.color = Color.lerp(GzColors.line, color, near * presence)!;
      canvas.drawLine(
        Offset(x, center.dy - h / 2),
        Offset(x, center.dy + h / 2),
        tickPaint,
      );
    }

    // Trilha entre o zero e o indicador.
    final ix = xFor(cents);
    final gap = ix - center.dx;
    if (gap.abs() > _ringRadius && presence > 0) {
      final trail = Paint()
        ..strokeCap = StrokeCap.round
        ..strokeWidth = 3
        ..color = color.withValues(alpha: 0.35 * presence);
      canvas.drawLine(
        Offset(center.dx + gap.sign * _ringRadius, center.dy),
        Offset(ix, center.dy),
        trail,
      );
    }

    // Anel central: o "zero".
    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = color;
    if (isInTune) {
      canvas.drawCircle(
        center,
        _ringRadius + 10,
        Paint()
          ..color = GzColors.zero.withValues(alpha: 0.12)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12),
      );
      canvas.drawCircle(
        center,
        _ringRadius,
        Paint()..color = GzColors.zero.withValues(alpha: 0.18),
      );
    }
    canvas.drawCircle(center, _ringRadius, ring);
    final zero = TextPainter(
      text: TextSpan(
        text: '0',
        style: TextStyle(
          color: isInTune ? GzColors.zero : GzColors.textSecondary,
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    zero.paint(canvas, center - Offset(zero.width / 2, zero.height / 2));

    // Indicador: encolhe ao se fundir com o anel.
    if (presence > 0) {
      final merge = (gap.abs() / _ringRadius).clamp(0.0, 1.0);
      final radius = 4 + 5 * math.max(merge, 0.0);
      canvas.drawCircle(
        Offset(ix, center.dy),
        radius * presence,
        Paint()..color = color,
      );
    }
  }

  @override
  bool shouldRepaint(_ZeroMeterPainter old) =>
      old.cents != cents ||
      old.presence != presence ||
      old.isInTune != isInTune ||
      old.range != range;
}
