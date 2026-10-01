import '../dsp/filters/confidence_gate.dart';
import '../dsp/filters/octave_jump_guard.dart';
import '../dsp/filters/pitch_smoother.dart';
import '../dsp/filters/range_gate.dart';
import '../dsp/filters/stability_gate.dart';
import '../dsp/pitch_estimate.dart';
import '../dsp/pitch_filter.dart';
import '../music/string_tracker.dart';
import 'in_tune_hysteresis.dart';
import 'silence_hold.dart';
import 'tuner_config.dart';
import 'tuner_reading.dart';

/// Transforma a sequência de estimativas do detector em leituras estáveis
/// para a UI. Puro e síncrono (sem áudio, sem streams), portanto testável
/// de forma determinística.
///
/// ```
/// PitchEstimate?
///   → ConfidenceGate → RangeGate → OctaveJumpGuard → StabilityGate
///   → PitchSmoother (One Euro em cents + reset em nova nota)
///   → StringTracker (histerese de corda)
///   → InTuneHysteresis
///   → SilenceHold
/// TunerReading?
/// ```
class TunerPipeline {
  TunerPipeline({this.config = const TunerConfig(), PitchFilter? pitchFilter})
    : pitchFilter = pitchFilter ?? standardPitchFilter(config),
      _strings = StringTracker(
        tuning: config.tuning,
        switchMarginCents: config.stringSwitchMarginCents,
        maxDeviationCents: config.maxStringDeviationCents,
      ),
      _inTune = InTuneHysteresis(
        enterCents: config.inTuneEnterCents,
        leaveCents: config.inTuneLeaveCents,
      ),
      _hold = SilenceHold(holdDuration: config.silenceHold);

  final TunerConfig config;

  /// Etapas no domínio da frequência (gates, oitava, estabilidade,
  /// smoothing).
  final PitchFilter pitchFilter;

  final StringTracker _strings;
  final InTuneHysteresis _inTune;
  final SilenceHold _hold;

  /// Cadeia padrão de filtros de pitch, configurada por [config].
  static PitchFilter standardPitchFilter(TunerConfig config) =>
      PitchFilterChain([
        ConfidenceGate(minConfidence: config.minConfidence),
        RangeGate(
          minFrequencyHz: config.minFrequencyHz,
          maxFrequencyHz: config.maxFrequencyHz,
        ),
        OctaveJumpGuard(
          toleranceCents: config.octaveToleranceCents,
          confirmDuration: config.octaveConfirmDuration,
          memory: config.octaveMemory,
        ),
        StabilityGate(
          windowSize: config.stabilityWindow,
          toleranceCents: config.stabilityToleranceCents,
        ),
        PitchSmoother(
          minCutoffHz: config.smoothingMinCutoffHz,
          beta: config.smoothingBeta,
          derivativeCutoffHz: config.smoothingDerivativeCutoffHz,
          newNoteThresholdCents: config.newNoteThresholdCents,
          resetGap: config.smoothingResetGap,
        ),
      ]);

  TunerReading? process(PitchEstimate? estimate, Duration timestamp) {
    final filtered = pitchFilter.process(estimate, timestamp);
    TunerReading? reading;
    if (filtered != null) {
      final match = _strings.match(filtered.frequencyHz);
      if (match != null) {
        reading = TunerReading(
          frequency: filtered.frequencyHz,
          confidence: filtered.confidence,
          string: match.string,
          cents: match.cents,
          isInTune: _inTune.update(match.string, match.cents),
        );
      }
    }
    final output = _hold.process(reading, timestamp);
    if (output == null) {
      // Silêncio além do hold: a próxima nota começa sem histerese.
      _strings.reset();
      _inTune.reset();
    }
    return output;
  }

  void reset() {
    pitchFilter.reset();
    _strings.reset();
    _inTune.reset();
    _hold.reset();
  }
}
