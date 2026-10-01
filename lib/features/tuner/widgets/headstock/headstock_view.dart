import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/music/guitar_string.dart';
import '../../../preferences/tuner_preferences.dart';
import '../string_button.dart';
import 'headstock_geometry.dart';
import 'headstock_painter.dart';

/// Headstock desenhado com os botões das cordas junto às tarraxas.
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
    final geometry = HeadstockGeometry.of(style);
    return LayoutBuilder(
      builder: (context, constraints) {
        const design = HeadstockGeometry.designSize;
        // Nunca maior que a distância até o botão vizinho (sem sobreposição);
        // entre 30 e 48 dp.
        double buttonSizeFor(double scale) {
          final spacing = geometry.buttonSpacing * scale;
          return math.max(
            30,
            math.min(48, math.min(spacing * 0.9, spacing - 2)),
          );
        }

        // Margem no topo para o botão e o contorno mais altos não serem
        // cortados; a escala é recalculada com a altura restante.
        final firstScale = math.min(
          constraints.maxWidth / design.width,
          constraints.maxHeight / design.height,
        );
        final topY = geometry.buttons.map((b) => b.dy).reduce(math.min);
        final topPad =
            math.max(0.0, buttonSizeFor(firstScale) / 2 - topY * firstScale) +
            6;
        final scale = math.min(
          constraints.maxWidth / design.width,
          (constraints.maxHeight - topPad) / design.height,
        );
        final origin = Offset(
          (constraints.maxWidth - design.width * scale) / 2,
          topPad,
        );
        final buttonSize = buttonSizeFor(scale);
        final activeIndex = activeString == null
            ? -1
            : strings.indexOf(activeString!);

        return Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned.fill(
              child: CustomPaint(
                painter: HeadstockPainter(
                  style: style,
                  activeIndex: activeIndex,
                  activeColor: activeColor,
                  scale: scale,
                  origin: origin,
                ),
              ),
            ),
            for (var i = 0; i < strings.length; i++)
              Positioned(
                left:
                    origin.dx + geometry.buttons[i].dx * scale - buttonSize / 2,
                top:
                    origin.dy + geometry.buttons[i].dy * scale - buttonSize / 2,
                child: StringButton(
                  string: strings[i],
                  naming: naming,
                  size: buttonSize,
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
}
