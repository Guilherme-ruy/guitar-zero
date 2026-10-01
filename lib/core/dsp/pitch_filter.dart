import 'pitch_estimate.dart';

/// Etapa de pós-processamento aplicada à sequência de estimativas.
///
/// É aqui que entram estabilidade temporal, filtro de mediana, smoothing
/// (ex.: One Euro Filter), proteção contra erros de oitava e noise gate
/// baseado em confiança. Cada técnica é um filtro independente e testável.
///
/// Recebe `null` quando não houve estimativa no frame, permitindo que o
/// filtro reaja ao silêncio (ex.: segurar o último valor por um instante).
abstract interface class PitchFilter {
  PitchEstimate? process(PitchEstimate? estimate);

  void reset();
}

/// Aplica uma sequência de [PitchFilter] em ordem.
class PitchFilterChain implements PitchFilter {
  const PitchFilterChain(this.filters);

  final List<PitchFilter> filters;

  @override
  PitchEstimate? process(PitchEstimate? estimate) {
    var current = estimate;
    for (final filter in filters) {
      current = filter.process(current);
    }
    return current;
  }

  @override
  void reset() {
    for (final filter in filters) {
      filter.reset();
    }
  }
}
