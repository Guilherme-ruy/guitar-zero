import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:guitar_zero/core/audio/audio_frame.dart';
import 'package:guitar_zero/core/dsp/harmonic_pitch_detector.dart';
import 'package:guitar_zero/core/dsp/spectral/harmonic_analyzer.dart';
import 'package:guitar_zero/core/dsp/yin_pitch_detector.dart';
import 'package:guitar_zero/core/music/pitch_math.dart';
import 'package:guitar_zero/core/music/tuning.dart';

import '../../support/synthetic_signals.dart';

final detector = HarmonicPitchDetector();
final yin = YinPitchDetector();
final strings = Tuning.standard.strings;
const configs = [(44100, 4096), (44100, 8192), (48000, 4096), (48000, 8192)];

AudioFrame toneFrame(
  double f,
  int sr,
  int n, {
  List<double> harmonics = const [1, 0.6, 0.4, 0.25, 0.15],
  double noise = 0,
  int seed = 1,
  double inharmonicity = 0,
}) => SyntheticSignals.frame(
  SyntheticSignals.tone(
    frequencyHz: f,
    sampleRate: sr,
    length: n,
    harmonics: harmonics,
    noise: noise,
    seed: seed,
    inharmonicity: inharmonicity,
  ),
  sr,
);

void main() {
  test('sinal limpo: 6 cordas × ±25 cents × 4 configurações, erro ≤ 1 cent '
      'e harmonicidade ≥ 0.95', () {
    for (final s in strings) {
      for (final (sr, n) in configs) {
        for (final detune in [-25.0, 0.0, 25.0]) {
          final f = frequencyFromMidi(s.note.midi + detune / 100);
          final e = detector.detect(toneFrame(f, sr, n))!;
          expect(centsBetween(e.frequencyHz, f).abs(), lessThanOrEqualTo(1));
          expect(e.harmonicity, greaterThanOrEqualTo(0.95));
        }
      }
    }
  });

  test('preserva a periodicidade do YIN e o RMS', () {
    final frame = toneFrame(110, 48000, 4096);
    final seed = yin.detect(frame)!;
    final e = detector.detect(frame)!;
    expect(e.periodicity, seed.periodicity);
    expect(e.rms, seed.rms);
  });

  test('silêncio e frames abaixo do gate: sem estimativa', () {
    final silent = AudioFrame(
      samples: Float32List(4096),
      sampleRate: 48000,
      timestamp: Duration.zero,
    );
    expect(detector.detect(silent), isNull);
  });

  test('ruído branco: harmonicidade baixa quando há estimativa', () {
    for (var seed = 1; seed <= 30; seed++) {
      final e = detector.detect(
        SyntheticSignals.frame(
          SyntheticSignals.whiteNoise(length: 4096, seed: seed),
          48000,
        ),
      );
      if (e != null) expect(e.harmonicity, lessThan(0.1));
    }
  });

  group('refinamento espectral vs YIN', () {
    test('com ruído (pico 0.2): erro máximo menor que o do YIN', () {
      for (final (sr, n) in configs) {
        var yinError = 0.0;
        var refinedError = 0.0;
        for (final s in strings) {
          for (var seed = 1; seed <= 10; seed++) {
            final f = s.targetFrequency;
            final frame = toneFrame(f, sr, n, noise: 0.2, seed: seed);
            yinError = math.max(
              yinError,
              centsBetween(yin.detect(frame)!.frequencyHz, f).abs(),
            );
            refinedError = math.max(
              refinedError,
              centsBetween(detector.detect(frame)!.frequencyHz, f).abs(),
            );
          }
        }
        expect(refinedError, lessThan(yinError), reason: '$sr/$n');
      }
    });

    test('inarmonicidade (B = 1e-4): ambos ficam sustenidos; refinado mais '
        'perto da fundamental', () {
      for (final s in strings) {
        final f = s.targetFrequency;
        final frame = toneFrame(
          f,
          48000,
          8192,
          harmonics: const [1, .7, .5, .4, .3, .25, .2, .15, .1, .08],
          inharmonicity: 1e-4,
        );
        final y = centsBetween(yin.detect(frame)!.frequencyHz, f);
        final r = centsBetween(detector.detect(frame)!.frequencyHz, f);
        expect(r, greaterThan(0));
        expect(r, lessThan(y));
      }
    });

    test('sem refinamento: frequência = semente do YIN (ou metade/dobro)', () {
      final plain = HarmonicPitchDetector(useSpectralRefinement: false);
      final frame = toneFrame(146.83, 48000, 4096, noise: 0.1);
      expect(plain.detect(frame)!.frequencyHz, yin.detect(frame)!.frequencyHz);
      final octave = toneFrame(
        146.83,
        48000,
        4096,
        harmonics: const [0.1, 1, 0.1, 0.3],
      );
      expect(
        plain.detect(octave)!.frequencyHz,
        closeTo(yin.detect(octave)!.frequencyHz / 2, 1e-9),
      );
      expect(plain.lastAnalysis!.correction, OctaveCorrection.down);
    });
  });

  test('frame curto (FFT não resolve a corda): devolve a semente do YIN', () {
    final frame = toneFrame(82.41, 48000, 1602);
    final e = detector.detect(frame)!;
    expect(e.frequencyHz, yin.detect(frame)!.frequencyHz);
    expect(e.harmonicity, isNull);
  });
}
