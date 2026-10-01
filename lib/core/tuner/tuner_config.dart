import '../music/tuning.dart';

/// Parâmetros do afinador independentes da plataforma e da UI.
class TunerConfig {
  const TunerConfig({
    this.tuning = Tuning.standard,
    this.inTuneToleranceCents = 5,
    this.minConfidence = 0.9,
  });

  final Tuning tuning;

  /// Desvio máximo, em cents, para considerar a corda afinada. Valor inicial,
  /// a ser calibrado com testes em instrumentos reais.
  final double inTuneToleranceCents;

  /// Estimativas com confiança abaixo disto são tratadas como ausência de
  /// pitch. 0.90 é ponto de partida inspirado no fgnass/tuner; precisa ser
  /// validado em aparelhos reais (microfone, AGC e ruído afetam a confiança).
  final double minConfidence;
}
