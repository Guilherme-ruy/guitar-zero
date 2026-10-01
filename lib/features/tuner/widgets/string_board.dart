import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import '../../../core/music/guitar_string.dart';

/// Representação abstrata do instrumento: seis cordas verticais, da mais
/// grave (esquerda) para a mais aguda (direita), com a nota de cada uma.
class StringBoard extends StatelessWidget {
  const StringBoard({
    super.key,
    required this.strings,
    required this.activeString,
    required this.activeColor,
    required this.tunedStrings,
  });

  /// Cordas ordenadas da mais grave para a mais aguda.
  final List<GuitarString> strings;
  final GuitarString? activeString;

  /// Cor de destaque da corda ativa (reflete o desvio atual).
  final Color activeColor;
  final Set<GuitarString> tunedStrings;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var i = 0; i < strings.length; i++)
          Expanded(
            child: _StringLane(
              string: strings[i],
              gauge: 3.2 - i * 0.4,
              isActive: strings[i] == activeString,
              isTuned: tunedStrings.contains(strings[i]),
              activeColor: activeColor,
            ),
          ),
      ],
    );
  }
}

class _StringLane extends StatelessWidget {
  const _StringLane({
    required this.string,
    required this.gauge,
    required this.isActive,
    required this.isTuned,
    required this.activeColor,
  });

  final GuitarString string;

  /// Espessura visual da corda.
  final double gauge;
  final bool isActive;
  final bool isTuned;
  final Color activeColor;

  @override
  Widget build(BuildContext context) {
    final color = isActive ? activeColor : GzColors.line;
    return Semantics(
      label: 'Corda ${string.number}, ${string.note}',
      selected: isActive,
      child: Column(
        children: [
          AnimatedContainer(
            duration: GzDurations.state,
            width: 44,
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isActive
                  ? activeColor.withValues(alpha: 0.14)
                  : GzColors.surface,
              border: Border.all(color: color, width: 1.5),
            ),
            child: Text(
              string.note.name,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: isActive ? activeColor : GzColors.textSecondary,
              ),
            ),
          ),
          const SizedBox(height: 6),
          AnimatedOpacity(
            duration: GzDurations.state,
            opacity: isTuned ? 1 : 0,
            child: Container(
              width: 5,
              height: 5,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: GzColors.zero,
              ),
            ),
          ),
          const SizedBox(height: 6),
          Expanded(
            child: AnimatedContainer(
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
            ),
          ),
        ],
      ),
    );
  }
}
