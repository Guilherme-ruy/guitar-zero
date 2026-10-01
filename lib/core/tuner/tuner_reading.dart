import '../music/guitar_string.dart';

/// Uma leitura do afinador pronta para ser exibida.
///
/// É o único tipo que a UI recebe do engine: já passou por todos os filtros
/// e histereses.
class TunerReading {
  const TunerReading({
    required this.frequency,
    required this.confidence,
    required this.string,
    required this.cents,
    required this.isInTune,
    this.isHeld = false,
  });

  /// Frequência fundamental (já filtrada), em Hz.
  final double frequency;

  /// Periodicidade da detecção (confiança do YIN), de 0 a 1.
  final double confidence;

  /// Corda ativa na afinação (com histerese).
  final GuitarString string;

  /// Desvio em relação à nota alvo. Negativo = abaixo, positivo = acima.
  final double cents;

  /// Estado "afinado" (com histerese de entrada/saída).
  final bool isInTune;

  /// `true` quando o sinal sumiu e esta é a última leitura sendo mantida
  /// durante o hold de silêncio.
  final bool isHeld;

  TunerReading copyWith({bool? isHeld}) => TunerReading(
    frequency: frequency,
    confidence: confidence,
    string: string,
    cents: cents,
    isInTune: isInTune,
    isHeld: isHeld ?? this.isHeld,
  );
}
