import 'tuner_reading.dart';

/// Mantém a última leitura visível por [holdDuration] depois que o sinal
/// some, para o ponteiro não desaparecer entre palhetadas ou durante um
/// bloqueio momentâneo do stability gate. Baseado em timestamps.
///
/// Leituras mantidas saem com `isHeld = true`. Uma leitura nova durante o
/// hold substitui a anterior imediatamente.
class SilenceHold {
  SilenceHold({required this.holdDuration});

  final Duration holdDuration;

  TunerReading? _last;
  Duration? _lastTimestamp;

  TunerReading? process(TunerReading? reading, Duration timestamp) {
    if (reading != null) {
      _last = reading;
      _lastTimestamp = timestamp;
      return reading;
    }
    final last = _last;
    if (last != null && timestamp - _lastTimestamp! <= holdDuration) {
      return last.copyWith(isHeld: true);
    }
    reset();
    return null;
  }

  void reset() {
    _last = null;
    _lastTimestamp = null;
  }
}
