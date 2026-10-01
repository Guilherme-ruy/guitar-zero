import '../../music/pitch_math.dart';
import '../pitch_estimate.dart';
import '../pitch_filter.dart';
import 'one_euro_filter.dart';

/// Suaviza a frequência com um [OneEuroFilter] no domínio de cents, para que
/// a dinâmica seja a mesma na corda mais grave e na mais aguda.
///
/// Reinicia (sem suavizar) quando:
/// - o salto em relação ao valor filtrado excede [newNoteThresholdCents]
///   (nova nota: o ponteiro não deve deslizar até ela);
/// - o intervalo desde a última estimativa excede [resetGap].
///
/// `dt` vem dos timestamps reais dos frames.
class PitchSmoother implements PitchFilter {
  PitchSmoother({
    required double minCutoffHz,
    required double beta,
    required double derivativeCutoffHz,
    required this.newNoteThresholdCents,
    required this.resetGap,
  }) : _filter = OneEuroFilter(
         minCutoffHz: minCutoffHz,
         beta: beta,
         derivativeCutoffHz: derivativeCutoffHz,
       );

  final double newNoteThresholdCents;
  final Duration resetGap;
  final OneEuroFilter _filter;
  Duration? _lastTimestamp;

  @override
  PitchEstimate? process(PitchEstimate? estimate, Duration timestamp) {
    if (estimate == null) return null;

    final cents = midiFromFrequency(estimate.frequencyHz) * 100;
    final last = _lastTimestamp;
    final previous = _filter.value;
    final gap = last == null ? null : timestamp - last;
    _lastTimestamp = timestamp;

    if (previous == null ||
        gap == null ||
        gap > resetGap ||
        (cents - previous).abs() > newNoteThresholdCents) {
      _filter.reset();
    }
    final dt = gap == null ? 0.0 : gap.inMicroseconds / 1e6;
    final smoothed = _filter.filter(cents, dt);
    return estimate.copyWith(frequencyHz: frequencyFromMidi(smoothed / 100));
  }

  @override
  void reset() {
    _filter.reset();
    _lastTimestamp = null;
  }
}
