import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import '../../../core/music/guitar_string.dart';
import '../../../core/tuner/tuner_reading.dart';
import '../../preferences/tuner_preferences.dart';
import '../note_names.dart';
import '../tuner_controller.dart';

/// Instrução curta para o usuário, conforme o estado do afinador.
class TunerHint extends StatelessWidget {
  const TunerHint({
    super.key,
    required this.status,
    required this.reading,
    this.onRetry,
    this.lastResult,
    this.allStringsTuned = false,
    this.manualString,
    this.naming = NoteNaming.letters,
  });

  /// Último resultado ao vivo (persiste após o som), para a instrução de
  /// espera dizer o que fazer a seguir em vez de recomeçar do zero.
  final TunerReading? lastResult;
  final bool allStringsTuned;

  /// Corda escolhida no modo manual (muda a instrução de espera).
  final GuitarString? manualString;
  final NoteNaming naming;

  final TunerStatus status;
  final TunerReading? reading;

  /// Ação para tentar de novo quando o microfone não está disponível.
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final (text, color) = _message();
    final canRetry =
        onRetry != null &&
        (status == TunerStatus.permissionDenied ||
            status == TunerStatus.unavailable);
    return AnimatedSwitcher(
      duration: GzDurations.state,
      child: Column(
        key: ValueKey(text),
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            text,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 15, color: color),
          ),
          if (canRetry)
            TextButton(
              onPressed: onRetry,
              style: TextButton.styleFrom(
                foregroundColor: GzColors.textPrimary,
              ),
              child: const Text('Tentar novamente'),
            ),
        ],
      ),
    );
  }

  (String, Color) _message() {
    switch (status) {
      case TunerStatus.idle:
        return ('Afinador pausado', GzColors.textSecondary);
      case TunerStatus.starting:
        return ('Preparando o microfone…', GzColors.textSecondary);
      case TunerStatus.permissionDenied:
        return ('Permita o acesso ao microfone para afinar', GzColors.off);
      case TunerStatus.unavailable:
        return ('Microfone indisponível', GzColors.off);
      case TunerStatus.listening:
        // Leitura atual ou mantida após o som (o controller a segura por
        // alguns segundos): o veredito não some na pausa entre palhetadas.
        final r = reading;
        if (r != null) {
          if (r.isInTune) return ('Afinada', GzColors.zero);
          return r.cents < 0
              ? ('Baixa — suba a afinação', GzColors.textPrimary)
              : ('Alta — desça a afinação', GzColors.textPrimary);
        }
        final manual = manualString;
        if (manual != null) {
          return (
            'Toque a corda ${naming.primary(manual.note)} (${manual.number}ª)',
            GzColors.textSecondary,
          );
        }
        if (allStringsTuned) {
          return ('Todas as cordas afinadas', GzColors.zero);
        }
        final last = lastResult;
        if (last == null) {
          return ('Toque uma corda para começar', GzColors.textSecondary);
        }
        return last.isInTune
            ? ('Toque a próxima corda', GzColors.textSecondary)
            : ('Ajuste e toque a corda de novo', GzColors.textSecondary);
    }
  }
}
