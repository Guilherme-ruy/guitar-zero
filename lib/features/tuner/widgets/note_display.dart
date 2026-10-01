import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import '../../../core/music/note.dart';

/// Nota alvo em destaque, com frequência e desvio detectados.
class NoteDisplay extends StatelessWidget {
  const NoteDisplay({
    super.key,
    required this.note,
    required this.frequency,
    required this.cents,
  });

  /// Nota da corda ativa, ou `null` antes da primeira detecção.
  final Note? note;

  /// Frequência detectada, ou `null` quando nada está soando.
  final double? frequency;
  final double? cents;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;
    final sounding = frequency != null;
    final noteColor = sounding ? GzColors.textPrimary : GzColors.textSecondary;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedDefaultTextStyle(
          duration: GzDurations.state,
          style: theme.displayLarge!.copyWith(color: noteColor),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(note?.name ?? '–'),
              if (note != null)
                Padding(
                  padding: const EdgeInsets.only(left: 4, bottom: 8),
                  child: Text(
                    '${note!.octave}',
                    style: const TextStyle(
                      fontSize: 28,
                      letterSpacing: 0,
                      color: GzColors.textSecondary,
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Text(
          sounding ? '${frequency!.toStringAsFixed(1)} Hz' : '— Hz',
          style: theme.titleMedium!.copyWith(color: GzColors.textSecondary),
        ),
        const SizedBox(height: 4),
        Text(
          sounding ? _formatCents(cents!) : ' ',
          style: theme.bodyMedium!.copyWith(
            color: GzColors.forCents(cents ?? 0),
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }

  static String _formatCents(double cents) {
    final rounded = cents.round();
    if (rounded == 0) return '0 cents';
    final sign = rounded > 0 ? '+' : '−';
    return '$sign${rounded.abs()} cents';
  }
}
