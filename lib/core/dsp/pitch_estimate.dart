/// Estimativa da frequência fundamental de um trecho de áudio.
class PitchEstimate {
  const PitchEstimate({
    required this.frequencyHz,
    required this.confidence,
    this.rms,
  }) : assert(confidence >= 0 && confidence <= 1);

  /// Frequência fundamental estimada, em Hz.
  final double frequencyHz;

  /// Confiança da estimativa, de 0 (nenhuma) a 1 (máxima). Cada detector
  /// define como calculá-la; no YIN é `1 − d'(τ)` (ver `YinPitchDetector`).
  /// Estágios posteriores (gate de confiança, stability gate) a utilizam.
  final double confidence;

  /// Nível RMS do frame analisado (após remoção de DC), em escala linear
  /// [0, 1]. Útil para noise gate adaptativo e indicadores de nível. `null`
  /// quando o produtor da estimativa não o calcula.
  final double? rms;

  PitchEstimate copyWith({
    double? frequencyHz,
    double? confidence,
    double? rms,
  }) => PitchEstimate(
    frequencyHz: frequencyHz ?? this.frequencyHz,
    confidence: confidence ?? this.confidence,
    rms: rms ?? this.rms,
  );

  @override
  String toString() =>
      'PitchEstimate(${frequencyHz.toStringAsFixed(3)} Hz, '
      'confidence ${confidence.toStringAsFixed(3)})';
}
