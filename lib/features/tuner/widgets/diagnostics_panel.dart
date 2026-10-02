import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import '../../../core/tuner/tuner_diagnostics.dart';
import '../../../core/tuner/tuner_reading.dart';

/// Painel de diagnóstico (oculto; aberto com toque longo no logo). Serve
/// para calibrar o DSP em aparelhos reais: um print desta tela traz os
/// números relevantes.
class DiagnosticsPanel extends StatelessWidget {
  const DiagnosticsPanel({super.key, required this.diagnostics, this.reading});

  final Stream<TunerDiagnostics> diagnostics;

  /// Leitura exibida (após os filtros): o desvio em cents só aparece aqui.
  final TunerReading? reading;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: GzColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: GzColors.line),
      ),
      child: StreamBuilder<TunerDiagnostics>(
        stream: diagnostics,
        builder: (context, snapshot) {
          final d = snapshot.data;
          return DefaultTextStyle(
            style: const TextStyle(
              fontFamily: 'monospace',
              fontSize: 12,
              height: 1.5,
              color: GzColors.textSecondary,
            ),
            child: d == null
                ? const Text('diagnóstico: aguardando áudio…')
                : Text(_format(d, reading)),
          );
        },
      ),
    );
  }

  static String _format(TunerDiagnostics d, TunerReading? r) {
    final e = d.estimate;
    final ms = d.processingTime.inMicroseconds / 1000;
    final rms = d.rmsDb;
    return [
      'DSP ${ms.toStringAsFixed(1)} ms · descartados ${d.droppedFrames}'
          ' · t ${(d.timestamp.inMilliseconds / 1000).toStringAsFixed(1)} s',
      e == null
          ? 'detector: sem estimativa'
          : 'f ${e.frequencyHz.toStringAsFixed(2)} Hz'
                ' · per ${e.periodicity.toStringAsFixed(2)}'
                ' · harm ${e.harmonicity?.toStringAsFixed(2) ?? '—'}',
      'RMS ${rms == null ? '—' : '${rms.toStringAsFixed(0)} dB'}'
          ' · leitura ${r == null ? '—' : '${r.string.note} '
                    '${r.cents >= 0 ? '+' : ''}${r.cents.toStringAsFixed(1)} c'
                    '${r.isHeld ? ' (mantida)' : ''}'}',
    ].join('\n');
  }
}
