import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../app/theme.dart';
import '../../../../core/music/guitar_string.dart';
import '../../../preferences/tuner_preferences.dart';
import '../string_button.dart';
import 'headstock_layout.dart';

/// Imagem do headstock com os botões das cordas ligados às tarraxas. Só os
/// botões indicam a corda ativa; a imagem não muda.
class HeadstockView extends StatelessWidget {
  const HeadstockView({
    super.key,
    required this.style,
    required this.strings,
    required this.activeString,
    required this.selectedString,
    required this.activeColor,
    required this.tunedStrings,
    required this.naming,
    required this.onSelect,
  });

  /// Margem lateral livre: os botões podem sair do retângulo da imagem.
  static const double sideMargin = 32;

  final InstrumentStyle style;

  /// Cordas da mais grave para a mais aguda.
  final List<GuitarString> strings;
  final GuitarString? activeString;

  /// Corda escolhida no modo manual (`null` no automático).
  final GuitarString? selectedString;
  final Color activeColor;
  final Set<GuitarString> tunedStrings;
  final NoteNaming naming;
  final ValueChanged<GuitarString> onSelect;

  @override
  Widget build(BuildContext context) {
    final layout = HeadstockLayout.of(style);
    return LayoutBuilder(
      builder: (context, constraints) {
        // Imagem inteira (contain), centralizada e ancorada embaixo.
        var height = math.min(
          constraints.maxHeight,
          (constraints.maxWidth - 2 * sideMargin) / HeadstockLayout.aspectRatio,
        );
        var buttons = layout.buttonsFor(height);
        var size = _buttonSize(buttons, height);
        // Espaço no topo para o botão mais alto não ser cortado.
        final topY = buttons.map((b) => b.dy).reduce(math.min);
        final overflow = size / 2 + 2 - topY * height;
        if (overflow > 0) {
          height = math.max(0, height - overflow / (1 - topY));
          buttons = layout.buttonsFor(height);
          size = _buttonSize(buttons, height);
        }
        final width = height * HeadstockLayout.aspectRatio;
        final image = Rect.fromLTWH(
          (constraints.maxWidth - width) / 2,
          constraints.maxHeight - height,
          width,
          height,
        );
        Offset at(Offset p) =>
            Offset(image.left + p.dx * width, image.top + p.dy * height);

        final activeIndex = activeString == null
            ? -1
            : strings.indexOf(activeString!);
        final centers = [for (final b in buttons) at(b)];
        final keys = [for (final k in layout.keys) at(k)];

        return Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned.fromRect(
              rect: image,
              child: Image.asset(
                layout.asset,
                fit: BoxFit.fill,
                excludeFromSemantics: true,
                gaplessPlayback: true,
              ),
            ),
            Positioned.fill(
              child: CustomPaint(
                painter: _ConnectorPainter(
                  from: centers,
                  to: keys,
                  buttonRadius: size / 2,
                  keyRadius: width * 0.035,
                ),
              ),
            ),
            for (var i = 0; i < strings.length; i++)
              Positioned(
                left: centers[i].dx - size / 2,
                top: centers[i].dy - size / 2,
                child: StringButton(
                  string: strings[i],
                  naming: naming,
                  size: size,
                  isActive: i == activeIndex,
                  isSelected: strings[i] == selectedString,
                  isTuned: tunedStrings.contains(strings[i]),
                  activeColor: activeColor,
                  onTap: () => onSelect(strings[i]),
                ),
              ),
          ],
        );
      },
    );
  }

  /// Entre 30 e 48 dp, sem sobrepor o botão vizinho mais próximo.
  static double _buttonSize(List<Offset> buttons, double height) {
    final width = height * HeadstockLayout.aspectRatio;
    var spacing = double.infinity;
    for (var i = 0; i < buttons.length; i++) {
      for (var j = i + 1; j < buttons.length; j++) {
        final d = Offset(
          (buttons[i].dx - buttons[j].dx) * width,
          (buttons[i].dy - buttons[j].dy) * height,
        ).distance;
        spacing = math.min(spacing, d);
      }
    }
    return (spacing - 4).clamp(30, 48).toDouble();
  }
}

/// Linhas discretas do botão até a chave da tarraxa correspondente.
class _ConnectorPainter extends CustomPainter {
  _ConnectorPainter({
    required this.from,
    required this.to,
    required this.buttonRadius,
    required this.keyRadius,
  });

  final List<Offset> from;
  final List<Offset> to;
  final double buttonRadius;
  final double keyRadius;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = GzColors.line
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < from.length; i++) {
      final delta = to[i] - from[i];
      final length = delta.distance;
      if (length <= buttonRadius + keyRadius) continue;
      final dir = delta / length;
      canvas.drawLine(
        from[i] + dir * buttonRadius,
        to[i] - dir * keyRadius,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_ConnectorPainter old) =>
      old.from != from || old.to != to || old.buttonRadius != buttonRadius;
}
