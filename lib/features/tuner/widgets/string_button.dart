import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import '../../../core/music/guitar_string.dart';
import '../../preferences/tuner_preferences.dart';
import '../note_names.dart';

/// Botão redondo de uma corda: mostra o nome da nota e, ao tocar, escolhe a
/// corda (modo manual).
class StringButton extends StatelessWidget {
  const StringButton({
    super.key,
    required this.string,
    required this.naming,
    required this.size,
    required this.isActive,
    required this.isSelected,
    required this.isTuned,
    required this.activeColor,
    required this.onTap,
  });

  final GuitarString string;
  final NoteNaming naming;
  final double size;

  /// Corda em destaque (detectada ou escolhida).
  final bool isActive;

  /// Escolhida manualmente.
  final bool isSelected;

  /// Já ficou afinada nesta sessão.
  final bool isTuned;
  final Color activeColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = isActive ? activeColor : GzColors.textSecondary;
    // Em botões pequenos o solfejo ficaria ilegível: só o nome principal.
    final secondary = size >= 40 ? naming.secondary(string.note) : null;
    return Semantics(
      button: true,
      selected: isSelected,
      label:
          'Corda ${string.number}, ${string.note.name} '
          '(${string.note.solfegeName})',
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: SizedBox.square(
          dimension: size,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              AnimatedContainer(
                duration: GzDurations.state,
                width: size,
                height: size,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isActive
                      ? Color.alphaBlend(
                          activeColor.withValues(alpha: 0.16),
                          GzColors.surface,
                        )
                      : GzColors.surface,
                  border: Border.all(
                    color: isActive || isSelected ? color : GzColors.line,
                    width: isSelected ? 2.5 : 1.5,
                  ),
                  boxShadow: const [
                    BoxShadow(color: Color(0x66000000), blurRadius: 6),
                  ],
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      naming.primary(string.note),
                      style: TextStyle(
                        fontSize: size * (secondary == null ? 0.36 : 0.32),
                        height: 1.05,
                        fontWeight: FontWeight.w600,
                        color: isActive ? activeColor : GzColors.textPrimary,
                      ),
                    ),
                    if (secondary != null)
                      Text(
                        secondary,
                        style: TextStyle(
                          fontSize: size * 0.2,
                          height: 1.1,
                          color: GzColors.textSecondary,
                        ),
                      ),
                  ],
                ),
              ),
              Positioned(
                right: 0,
                top: 0,
                child: AnimatedScale(
                  duration: GzDurations.state,
                  scale: isTuned ? 1 : 0,
                  child: Container(
                    width: size * 0.22,
                    height: size * 0.22,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: GzColors.zero,
                      border: Border.all(color: GzColors.background, width: 2),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
