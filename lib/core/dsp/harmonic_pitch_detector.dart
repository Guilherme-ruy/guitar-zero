import '../audio/audio_frame.dart';
import '../music/pitch_math.dart';
import 'pitch_detector.dart';
import 'pitch_estimate.dart';
import 'spectral/harmonic_analyzer.dart';
import 'yin_pitch_detector.dart';

/// [PitchDetector] em duas etapas: o YIN fornece a semente (período e
/// periodicidade) e o [HarmonicAnalyzer] verifica a oitava no espectro,
/// calcula a harmonicidade e refina a frequência pela série harmônica.
///
/// O YIN continua independente; esta classe só compõe.
class HarmonicPitchDetector implements PitchDetector {
  HarmonicPitchDetector({
    YinPitchDetector? yin,
    HarmonicAnalyzer? analyzer,
    this.useSpectralRefinement = true,
    this.maxRefinementShiftCents = 40,
  }) : yin = yin ?? YinPitchDetector(),
       analyzer = analyzer ?? HarmonicAnalyzer();

  final YinPitchDetector yin;
  final HarmonicAnalyzer analyzer;

  /// Se `true` (padrão), a frequência final é a média ponderada de `f_h/h`
  /// dos harmônicos; se `false`, é a semente do YIN (ou sua metade/dobro
  /// após correção). Com ruído e com parciais esticados (inarmonicidade) o
  /// refinamento ficou mais próximo da fundamental que o YIN; ver
  /// docs/DSP_STRATEGY.md.
  final bool useSpectralRefinement;

  /// Se o refinamento divergir mais que isto da fundamental escolhida, ele
  /// é descartado (proteção contra picos mal associados).
  final double maxRefinementShiftCents;

  /// Última análise (diagnóstico/relatórios), ou `null`.
  HarmonicAnalysis? lastAnalysis;

  @override
  PitchEstimate? detect(AudioFrame frame) {
    lastAnalysis = null;
    final seed = yin.detect(frame);
    if (seed == null) return null;
    final analysis = analyzer.analyze(frame, seed.frequencyHz);
    if (analysis == null) return seed;
    lastAnalysis = analysis;

    final refined = analysis.refinedHz;
    final frequency =
        useSpectralRefinement &&
            refined != null &&
            centsBetween(refined, analysis.fundamentalHz).abs() <=
                maxRefinementShiftCents
        ? refined
        : analysis.fundamentalHz;
    final range = yin.config;
    if (frequency < range.minFrequencyHz || frequency > range.maxFrequencyHz) {
      // A fundamental mais plausível está fora da faixa (ex.: tom de 500 Hz
      // que o YIN reportou como 250 Hz).
      return null;
    }
    return seed.copyWith(
      frequencyHz: frequency,
      harmonicity: analysis.harmonicity,
    );
  }

  @override
  void reset() {
    yin.reset();
    lastAnalysis = null;
  }
}
