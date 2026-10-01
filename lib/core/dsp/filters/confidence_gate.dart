import '../pitch_estimate.dart';
import '../pitch_filter.dart';

/// Descarta estimativas sem evidência suficiente de som tonal.
///
/// Aceita se:
/// - periodicidade ≥ [minConfidence]; **ou**
/// - periodicidade ≥ [relaxedMinPeriodicity] **e** harmonicidade ≥
///   [minHarmonicity] — duas evidências independentes.
///
/// O caminho combinado existe porque, com duas cordas soando (a nova e a
/// anterior ainda vibrando), o sinal não é periódico em nenhum período
/// dentro da faixa: a periodicidade da nota dominante cai para 0.65–0.85
/// mesmo com o detector acertando. Ruído (harmonicidade ≤ 0.01) e misturas
/// inarmônicas (≤ 0.57) continuam rejeitados. Estimativas sem harmonicidade
/// só passam pelo critério de periodicidade.
class ConfidenceGate implements PitchFilter {
  const ConfidenceGate({
    required this.minConfidence,
    this.relaxedMinPeriodicity,
    this.minHarmonicity,
  });

  final double minConfidence;
  final double? relaxedMinPeriodicity;
  final double? minHarmonicity;

  @override
  PitchEstimate? process(PitchEstimate? estimate, Duration timestamp) {
    if (estimate == null) return null;
    if (estimate.periodicity >= minConfidence) return estimate;
    final relaxed = relaxedMinPeriodicity;
    final harmonicityFloor = minHarmonicity;
    final harmonicity = estimate.harmonicity;
    if (relaxed != null &&
        harmonicityFloor != null &&
        harmonicity != null &&
        estimate.periodicity >= relaxed &&
        harmonicity >= harmonicityFloor) {
      return estimate;
    }
    return null;
  }

  @override
  void reset() {}
}
