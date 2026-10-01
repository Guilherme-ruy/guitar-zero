import '../pitch_estimate.dart';
import '../pitch_filter.dart';

/// Descarta estimativas fora de [[minFrequencyHz], [maxFrequencyHz]].
///
/// Redundante com a faixa de lags do YIN, mas mantém a garantia mesmo se o
/// detector for trocado.
class RangeGate implements PitchFilter {
  const RangeGate({required this.minFrequencyHz, required this.maxFrequencyHz});

  final double minFrequencyHz;
  final double maxFrequencyHz;

  @override
  PitchEstimate? process(PitchEstimate? estimate, Duration timestamp) =>
      estimate != null &&
          estimate.frequencyHz >= minFrequencyHz &&
          estimate.frequencyHz <= maxFrequencyHz
      ? estimate
      : null;

  @override
  void reset() {}
}
