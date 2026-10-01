import '../music/guitar_string.dart';

/// Uma leitura do afinador pronta para ser exibida.
class TunerReading {
  const TunerReading({
    required this.frequency,
    required this.confidence,
    required this.string,
    required this.cents,
    required this.isInTune,
  });

  /// Frequência fundamental detectada (já filtrada), em Hz.
  final double frequency;

  /// Confiança da detecção, de 0 a 1.
  final double confidence;

  /// Corda mais provável na afinação ativa.
  final GuitarString string;

  /// Desvio em relação à nota alvo. Negativo = abaixo, positivo = acima.
  final double cents;

  /// Se o desvio está dentro da tolerância considerada afinada.
  final bool isInTune;
}
