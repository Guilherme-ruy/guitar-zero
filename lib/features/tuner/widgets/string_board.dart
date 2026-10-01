import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import '../../../core/music/guitar_string.dart';
import '../../preferences/tuner_preferences.dart';
import 'string_button.dart';

/// Visual minimalista: seis cordas verticais, da mais grave (esquerda) para
/// a mais aguda (direita), com o botão de cada uma no topo.
class StringBoard extends StatelessWidget {
  const StringBoard({
    super.key,
    required this.strings,
    required this.activeString,
    required this.selectedString,
    required this.activeColor,
    required this.tunedStrings,
    required this.naming,
    required this.onSelect,
  });

  /// Cordas ordenadas da mais grave para a mais aguda.
  final List<GuitarString> strings;
  final GuitarString? activeString;
  final GuitarString? selectedString;

  /// Cor de destaque da corda ativa (reflete o desvio atual).
  final Color activeColor;
  final Set<GuitarString> tunedStrings;
  final NoteNaming naming;
  final ValueChanged<GuitarString> onSelect;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var i = 0; i < strings.length; i++)
          Expanded(
            child: Column(
              children: [
                StringButton(
                  string: strings[i],
                  naming: naming,
                  size: 46,
                  isActive: strings[i] == activeString,
                  isSelected: strings[i] == selectedString,
                  isTuned: tunedStrings.contains(strings[i]),
                  activeColor: activeColor,
                  onTap: () => onSelect(strings[i]),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: _StringLine(
                    gauge: 3.2 - i * 0.4,
                    isActive: strings[i] == activeString,
                    activeColor: activeColor,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _StringLine extends StatelessWidget {
  const _StringLine({
    required this.gauge,
    required this.isActive,
    required this.activeColor,
  });

  final double gauge;
  final bool isActive;
  final Color activeColor;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: GzDurations.state,
      width: gauge,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(gauge),
        color: isActive ? activeColor : GzColors.line,
        boxShadow: isActive
            ? [
                BoxShadow(
                  color: activeColor.withValues(alpha: 0.5),
                  blurRadius: 10,
                ),
              ]
            : const [],
      ),
    );
  }
}
