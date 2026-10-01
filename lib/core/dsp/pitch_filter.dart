import 'pitch_estimate.dart';

/// Etapa de pós-processamento aplicada à sequência de estimativas.
///
/// Cada técnica (gate de confiança, proteção de oitava, stability gate,
/// smoothing…) é um filtro independente e testável.
///
/// Recebe `null` quando não houve estimativa no frame, permitindo que o
/// filtro reaja ao silêncio. [timestamp] é o instante do frame em um relógio
/// monotônico; filtros dependentes de tempo devem usá-lo em vez de contar
/// frames.
abstract interface class PitchFilter {
  PitchEstimate? process(PitchEstimate? estimate, Duration timestamp);

  void reset();
}

/// Aplica uma sequência de [PitchFilter] em ordem.
class PitchFilterChain implements PitchFilter {
  const PitchFilterChain(this.filters);

  final List<PitchFilter> filters;

  @override
  PitchEstimate? process(PitchEstimate? estimate, Duration timestamp) {
    var current = estimate;
    for (final filter in filters) {
      current = filter.process(current, timestamp);
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
