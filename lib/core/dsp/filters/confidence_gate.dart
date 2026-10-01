import '../pitch_estimate.dart';
import '../pitch_filter.dart';

/// Descarta estimativas com confiança abaixo de [minConfidence].
class ConfidenceGate implements PitchFilter {
  const ConfidenceGate({required this.minConfidence});

  final double minConfidence;

  @override
  PitchEstimate? process(PitchEstimate? estimate, Duration timestamp) =>
      estimate != null && estimate.confidence >= minConfidence
      ? estimate
      : null;

  @override
  void reset() {}
}
