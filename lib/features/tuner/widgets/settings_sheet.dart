import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import '../../preferences/tuner_preferences.dart';

/// Ajustes visuais em um painel inferior: instrumento, visual e nomes.
Future<void> showTunerSettings(
  BuildContext context,
  TunerPreferences preferences,
) => showModalBottomSheet<void>(
  context: context,
  backgroundColor: GzColors.surface,
  showDragHandle: true,
  builder: (context) => ListenableBuilder(
    listenable: preferences,
    builder: (context, _) => SafeArea(
      // Rolável: em telas baixas (ou paisagem) o conteúdo não estoura.
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _ChoiceRow<InstrumentStyle>(
              title: 'INSTRUMENTO',
              selected: preferences.instrument,
              options: const [
                (InstrumentStyle.acoustic, 'Violão'),
                (InstrumentStyle.electric, 'Guitarra'),
              ],
              onChanged: (v) => preferences.instrument = v,
            ),
            _ChoiceRow<bool>(
              title: 'VISUAL',
              selected: preferences.showInstrument,
              options: const [
                (true, 'Com instrumento'),
                (false, 'Minimalista'),
              ],
              onChanged: (v) => preferences.showInstrument = v,
            ),
            _ChoiceRow<NoteNaming>(
              title: 'NOMES DAS NOTAS',
              selected: preferences.noteNaming,
              options: const [
                (NoteNaming.both, 'E · Mi'),
                (NoteNaming.letters, 'E A D'),
                (NoteNaming.solfege, 'Mi Lá Ré'),
              ],
              onChanged: (v) => preferences.noteNaming = v,
            ),
          ],
        ),
      ),
    ),
  ),
);

class _ChoiceRow<T> extends StatelessWidget {
  const _ChoiceRow({
    required this.title,
    required this.selected,
    required this.options,
    required this.onChanged,
  });

  final String title;
  final T selected;
  final List<(T, String)> options;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.labelSmall),
          const SizedBox(height: 10),
          Row(
            spacing: 8,
            children: [
              for (final (value, label) in options)
                Expanded(
                  child: _Choice(
                    label: label,
                    selected: value == selected,
                    onTap: () => onChanged(value),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Choice extends StatelessWidget {
  const _Choice({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: GzDurations.state,
          height: 44,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: selected
                ? GzColors.zero.withValues(alpha: 0.14)
                : GzColors.background,
            border: Border.all(
              color: selected ? GzColors.zero : GzColors.line,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: selected ? GzColors.zero : GzColors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}
