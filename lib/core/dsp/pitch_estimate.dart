/// Estimativa da frequência fundamental de um trecho de áudio.
class PitchEstimate {
  const PitchEstimate({required this.frequency, required this.confidence})
    : assert(confidence >= 0 && confidence <= 1);

  /// Frequência fundamental estimada, em Hz.
  final double frequency;

  /// Confiança da estimativa, de 0 (nenhuma) a 1 (máxima). Cada detector
  /// define como calculá-la (ex.: no YIN, `1 - aperiodicidade`).
  final double confidence;

  PitchEstimate copyWith({double? frequency, double? confidence}) =>
      PitchEstimate(
        frequency: frequency ?? this.frequency,
        confidence: confidence ?? this.confidence,
      );

  @override
  String toString() =>
      'PitchEstimate(${frequency.toStringAsFixed(2)} Hz, '
      'confidence ${confidence.toStringAsFixed(2)})';
}
