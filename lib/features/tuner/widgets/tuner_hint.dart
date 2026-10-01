import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import '../../../core/tuner/tuner_reading.dart';
import '../tuner_controller.dart';

/// Instrução curta para o usuário, conforme o estado do afinador.
class TunerHint extends StatelessWidget {
  const TunerHint({super.key, required this.status, required this.reading});

  final TunerStatus status;
  final TunerReading? reading;

  @override
  Widget build(BuildContext context) {
    final (text, color) = _message();
    return AnimatedSwitcher(
      duration: GzDurations.state,
      child: Text(
        text,
        key: ValueKey(text),
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 15, color: color),
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
        if (r == null) return ('Toque qualquer corda', GzColors.textSecondary);
        if (r.isInTune) return ('Afinada', GzColors.zero);
        return r.cents < 0
            ? ('Baixa — suba a afinação', GzColors.textPrimary)
            : ('Alta — desça a afinação', GzColors.textPrimary);
    }
  }
}
