import 'dart:math' as math;

import '../dsp/pitch_estimate.dart';

/// Medidas de um frame para depuração e calibração em aparelho.
///
/// Não faz parte do estado de afinação: a UI normal não usa; só o painel de
/// diagnóstico (oculto) exibe.
class TunerDiagnostics {
  const TunerDiagnostics({
    required this.timestamp,
    required this.processingTime,
    this.estimate,
    this.droppedFrames = 0,
  });

  /// Instante do frame (relógio da captura).
  final Duration timestamp;

  /// Tempo gasto pelo detector + pipeline neste frame.
  final Duration processingTime;

  /// Saída bruta do detector (antes dos filtros), ou `null`.
  final PitchEstimate? estimate;

  /// Frames descartados até agora por atraso no processamento.
  final int droppedFrames;

  /// Nível RMS em dB (0 dB = amplitude RMS 1.0), ou `null`.
  double? get rmsDb {
    final rms = estimate?.rms;
    if (rms == null || rms <= 0) return null;
    return 20 * math.log(rms) / math.ln10;
  }

  TunerDiagnostics withDroppedFrames(int dropped) => TunerDiagnostics(
    timestamp: timestamp,
    processingTime: processingTime,
    estimate: estimate,
    droppedFrames: dropped,
  );
}
