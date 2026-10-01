import '../pitch_estimate.dart';
import '../pitch_filter.dart';

/// Descarta estimativas com periodicidade (confiança do detector) abaixo de
/// [minConfidence].
class ConfidenceGate implements PitchFilter {
  const ConfidenceGate({required this.minConfidence});

  final double minConfidence;

  @override
  PitchEstimate? process(PitchEstimate? estimate, Duration timestamp) =>
      estimate != null && estimate.periodicity >= minConfidence
      ? estimate
      : null;

  @override
  void reset() {}
}
