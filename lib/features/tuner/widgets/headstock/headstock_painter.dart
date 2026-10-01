import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../app/theme.dart';
import '../../../preferences/tuner_preferences.dart';
import 'headstock_geometry.dart';

/// Desenho vetorial do headstock (madeira/grafite, tarraxas, nut, braço e
/// cordas). Sem imagens: escala para qualquer tela e segue o tema.
class HeadstockPainter extends CustomPainter {
  HeadstockPainter({
    required this.style,
    required this.activeIndex,
    required this.activeColor,
    required this.scale,
    required this.origin,
  });

  final InstrumentStyle style;

  /// Corda em destaque (0 = E2), ou −1.
  final int activeIndex;
  final Color activeColor;

  /// Pixels por unidade de projeto e posição da caixa de projeto.
  final double scale;
  final Offset origin;

  static const _woodAcoustic = [Color(0xFF6B4A33), Color(0xFF3E2A1C)];
  static const _woodElectric = [Color(0xFF3A3D45), Color(0xFF1F2126)];
  static const _fretboard = Color(0xFF221A15);
  static const _bone = Color(0xFFE9E2D2);
  static const _metal = [Color(0xFFE4E6EA), Color(0xFF8D929C)];
  static const _string = Color(0xFFC9CDD5);

  @override
  void paint(Canvas canvas, Size size) {
    final g = HeadstockGeometry.of(style);
    Offset p(Offset o) => origin + o * scale;
    double u(double v) => v * scale;

    // Braço: do nut até o fim da área.
    final neck = Rect.fromLTRB(
      p(Offset(g.neckLeft, 0)).dx,
      p(Offset(0, g.nutY)).dy,
      p(Offset(g.neckRight, 0)).dx,
      size.height,
    );
    canvas.drawRect(neck, Paint()..color = _fretboard);
    final fretPaint = Paint()
      ..color = const Color(0xFF9A9CA3)
      ..strokeWidth = u(0.8);
    for (var y = g.nutY + 24; p(Offset(0, y)).dy < size.height; y += 26) {
      final yy = p(Offset(0, y)).dy;
      canvas.drawLine(Offset(neck.left, yy), Offset(neck.right, yy), fretPaint);
    }

    // Tarraxas (eixo + chave), atrás da madeira.
    final metal = Paint()
      ..shader = const LinearGradient(
        colors: _metal,
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(Offset.zero & size);
    for (var i = 0; i < 6; i++) {
      final post = p(g.posts[i]);
      final knob = p(g.knobs[i]);
      canvas.drawLine(
        post,
        knob,
        Paint()
          ..color = _metal.last
          ..strokeWidth = u(2.2)
          ..strokeCap = StrokeCap.round,
      );
      final knobRect = RRect.fromRectAndRadius(
        Rect.fromCenter(center: knob, width: u(6.5), height: u(9)),
        Radius.circular(u(2.5)),
      );
      canvas
        ..drawRRect(
          knobRect.shift(Offset(0, u(0.8))),
          Paint()..color = Colors.black.withValues(alpha: 0.35),
        )
        ..drawRRect(knobRect, metal);
    }

    // Madeira do headstock.
    final outline = g.outline
        .transform(Matrix4.diagonal3Values(scale, scale, 1).storage)
        .shift(origin);
    final bounds = outline.getBounds();
    canvas
      ..drawPath(
        outline.shift(Offset(0, u(1.5))),
        Paint()
          ..color = Colors.black.withValues(alpha: 0.4)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, u(2)),
      )
      ..drawPath(
        outline,
        Paint()
          ..shader = LinearGradient(
            colors: style == InstrumentStyle.acoustic
                ? _woodAcoustic
                : _woodElectric,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ).createShader(bounds),
      )
      ..drawPath(
        outline,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = u(0.6)
          ..color = Colors.white.withValues(alpha: 0.12),
      );

    // Anel da marca (o "zero").
    canvas.drawCircle(
      p(g.logo),
      u(3.4),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = u(1.1)
        ..color = GzColors.zero.withValues(alpha: 0.75),
    );

    // Nut (pestana).
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTRB(
          neck.left,
          p(Offset(0, g.nutY - 2)).dy,
          neck.right,
          p(Offset(0, g.nutY + 0.8)).dy,
        ),
        Radius.circular(u(0.6)),
      ),
      Paint()..color = _bone,
    );

    // Cordas: braço → nut → pino. A ativa por cima, com brilho.
    final order = [
      for (var i = 0; i < 6; i++)
        if (i != activeIndex) i,
      if (activeIndex >= 0) activeIndex,
    ];
    for (final i in order) {
      final active = i == activeIndex;
      final slot = p(Offset(g.nutSlotsX[i], g.nutY));
      final post = p(g.posts[i]);
      final gauge = u(1.15 - i * 0.12);
      final paint = Paint()
        ..strokeCap = StrokeCap.round
        ..strokeWidth = math.max(1, gauge)
        ..color = active ? activeColor : _string.withValues(alpha: 0.55);
      if (active) {
        final glow = Paint()
          ..strokeCap = StrokeCap.round
          ..strokeWidth = math.max(1, gauge) * 4
          ..color = activeColor.withValues(alpha: 0.25)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, u(1.5));
        canvas
          ..drawLine(slot, post, glow)
          ..drawLine(slot, Offset(slot.dx, size.height), glow);
      }
      canvas
        ..drawLine(slot, post, paint)
        ..drawLine(slot, Offset(slot.dx, size.height), paint);
    }

    // Pinos (por cima das cordas).
    for (final post in g.posts) {
      final c = p(post);
      canvas
        ..drawCircle(c, u(2.6), metal)
        ..drawCircle(c, u(1), Paint()..color = _metal.last);
    }
  }

  @override
  bool shouldRepaint(HeadstockPainter old) =>
      old.style != style ||
      old.activeIndex != activeIndex ||
      old.activeColor != activeColor ||
      old.scale != scale ||
      old.origin != origin;
}
