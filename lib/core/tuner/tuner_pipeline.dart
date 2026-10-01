import '../dsp/filters/confidence_gate.dart';
import '../dsp/filters/harmonic_jump_guard.dart';
import '../dsp/filters/pitch_smoother.dart';
import '../dsp/filters/range_gate.dart';
import '../dsp/filters/stability_gate.dart';
import '../dsp/pitch_estimate.dart';
import '../dsp/pitch_filter.dart';
import '../music/guitar_string.dart';
import '../music/pitch_math.dart';
import '../music/string_matcher.dart';
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
///   → ConfidenceGate → RangeGate → HarmonicJumpGuard → StabilityGate
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
  GuitarString? _target;

  /// Corda escolhida manualmente, ou `null` no modo automático.
  GuitarString? get targetString => _target;

  /// Modo manual: todo pitch detectado é medido contra [string] (cents
  /// dobrados por oitava, em (−600, 600]) — útil para uma corda muito
  /// desafinada, que no automático seria associada à corda vizinha.
  /// `null` volta ao automático. Trocar o alvo descarta histereses e hold.
  void setTargetString(GuitarString? string) {
    if (string == _target) return;
    _target = string;
    _strings.reset();
    _inTune.reset();
    _hold.reset();
  }

  /// Cadeia padrão de filtros de pitch, configurada por [config].
  static PitchFilter standardPitchFilter(TunerConfig config) =>
      PitchFilterChain([
        ConfidenceGate(
          minConfidence: config.minConfidence,
          relaxedMinPeriodicity: config.relaxedMinPeriodicity,
          minHarmonicity: config.minHarmonicity,
        ),
        RangeGate(
          minFrequencyHz: config.minFrequencyHz,
          maxFrequencyHz: config.maxFrequencyHz,
        ),
        HarmonicJumpGuard(
          toleranceCents: config.harmonicJumpToleranceCents,
          confirmDuration: config.harmonicJumpConfirmDuration,
          memory: config.harmonicJumpMemory,
          onsetThresholdDb: config.onsetThresholdDb,
          onsetWindow: config.onsetWindow,
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
      final target = _target;
      final match = target == null
          ? _strings.match(filtered.frequencyHz)
          : StringMatch(
              string: target,
              cents: octaveFoldedCents(
                filtered.frequencyHz,
                target.targetFrequency,
              ),
            );
      if (match != null) {
        reading = TunerReading(
          frequency: filtered.frequencyHz,
          confidence: filtered.periodicity,
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
