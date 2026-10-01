import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import '../../../core/tuner/tuner_reading.dart';
import '../tuner_controller.dart';

/// Instrução curta para o usuário, conforme o estado do afinador.
class TunerHint extends StatelessWidget {
  const TunerHint({
    super.key,
    required this.status,
    required this.reading,
    this.onRetry,
  });

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
        final r = reading;
        if (r == null || r.isHeld) {
          return ('Toque qualquer corda', GzColors.textSecondary);
        }
        if (r.isInTune) return ('Afinada', GzColors.zero);
        return r.cents < 0
            ? ('Baixa — suba a afinação', GzColors.textPrimary)
            : ('Alta — desça a afinação', GzColors.textPrimary);
    }
  }
}
