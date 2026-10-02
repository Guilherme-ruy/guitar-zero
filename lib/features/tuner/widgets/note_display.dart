import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import '../../../core/music/note.dart';
import '../../preferences/tuner_preferences.dart';
import '../note_names.dart';

/// Nota alvo em destaque e frequência detectada. O desvio aparece só no
/// medidor (ponteiro e cor), sem número de cents.
class NoteDisplay extends StatelessWidget {
  const NoteDisplay({
    super.key,
    required this.note,
    required this.frequency,
    this.naming = NoteNaming.letters,
    this.compact = false,
  });

  /// Versão menor (telas baixas).
  final bool compact;

  /// Nota da corda ativa, ou `null` antes da primeira detecção.
  final Note? note;

  /// Frequência detectada, ou `null` quando nada está soando.
  final double? frequency;
  final NoteNaming naming;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;
    final sounding = frequency != null;
    final noteColor = sounding ? GzColors.textPrimary : GzColors.textSecondary;
    final n = note;
    final secondary = n == null ? null : naming.secondary(n);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedDefaultTextStyle(
          duration: GzDurations.state,
          style: theme.displayLarge!.copyWith(
            color: noteColor,
            fontSize: compact ? 68 : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(n == null ? '–' : naming.primary(n)),
              if (n != null)
                Padding(
                  padding: const EdgeInsets.only(left: 6, bottom: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (secondary != null)
                        Text(
                          secondary,
                          style: const TextStyle(
                            fontSize: 20,
                            letterSpacing: 0,
                            fontWeight: FontWeight.w500,
                            color: GzColors.textSecondary,
                          ),
                        ),
                      Text(
                        '${n.octave}',
                        style: const TextStyle(
                          fontSize: 28,
                          letterSpacing: 0,
                          color: GzColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Text(
          sounding ? '${frequency!.toStringAsFixed(1)} Hz' : '— Hz',
          style: theme.titleMedium!.copyWith(color: GzColors.textSecondary),
        ),
      ],
    );
  }
}
