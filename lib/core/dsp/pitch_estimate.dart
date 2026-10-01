/// Estimativa da frequência fundamental de um trecho de áudio.
///
/// Duas medidas de confiança independentes:
/// - [periodicity]: quão periódico é o sinal no período escolhido (no YIN,
///   `1 − d'(τ)`). **Alta periodicidade não garante a oitava correta**: um
///   sinal com o 2º harmônico dominante é muito periódico em T/2.
/// - [harmonicity]: quão bem o espectro é explicado por uma série harmônica
///   sobre [frequencyHz] (análise espectral). `null` quando não calculada.
class PitchEstimate {
  const PitchEstimate({
    required this.frequencyHz,
    required this.periodicity,
    this.harmonicity,
    this.rms,
  }) : assert(periodicity >= 0 && periodicity <= 1),
       assert(harmonicity == null || (harmonicity >= 0 && harmonicity <= 1));

  /// Frequência fundamental estimada, em Hz.
  final double frequencyHz;

  /// Confiança de periodicidade, de 0 a 1 (YIN: `1 − d'(τ)`). É o que o
  /// gate de confiança do pipeline usa.
  final double periodicity;

  /// Coerência do espectro com a série harmônica de [frequencyHz], de 0
  /// (ruído / sem relação harmônica) a 1 (toda a energia nos harmônicos).
  final double? harmonicity;

  /// Nível RMS do frame analisado (após remoção de DC), em escala linear
  /// [0, 1]. `null` quando o produtor da estimativa não o calcula.
  final double? rms;

  PitchEstimate copyWith({
    double? frequencyHz,
    double? periodicity,
    double? harmonicity,
    double? rms,
  }) => PitchEstimate(
    frequencyHz: frequencyHz ?? this.frequencyHz,
    periodicity: periodicity ?? this.periodicity,
    harmonicity: harmonicity ?? this.harmonicity,
    rms: rms ?? this.rms,
  );

  @override
  String toString() =>
      'PitchEstimate(${frequencyHz.toStringAsFixed(3)} Hz, '
      'periodicity ${periodicity.toStringAsFixed(3)}'
      '${harmonicity == null ? '' : ', harmonicity ${harmonicity!.toStringAsFixed(3)}'})';
}
