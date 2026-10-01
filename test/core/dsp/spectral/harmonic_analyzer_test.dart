import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:guitar_zero/core/audio/audio_frame.dart';
import 'package:guitar_zero/core/dsp/spectral/harmonic_analyzer.dart';
import 'package:guitar_zero/core/music/tuning.dart';

import '../../../support/synthetic_signals.dart';

final analyzer = HarmonicAnalyzer();
final strings = Tuning.standard.strings;
const configs = [(44100, 4096), (44100, 8192), (48000, 4096), (48000, 8192)];

AudioFrame toneFrame(
  double f,
  List<double> harmonics, {
  int sampleRate = 48000,
  int size = 4096,
  double noise = 0,
  int seed = 1,
}) => SyntheticSignals.frame(
  SyntheticSignals.tone(
    frequencyHz: f,
    sampleRate: sampleRate,
    length: size,
    harmonics: harmonics,
    noise: noise,
    seed: seed,
  ),
  sampleRate,
);

void main() {
  group('correção para baixo (semente = 2 × fundamental)', () {
    test('com evidência (H1 e H3 de f/2 presentes): corrige', () {
      for (final s in strings.take(4)) {
        final f0 = s.targetFrequency;
        final a = analyzer.analyze(toneFrame(f0, [0.1, 1, 0.1, 0.3]), 2 * f0)!;
        expect(a.correction, OctaveCorrection.down, reason: '${s.note}');
        expect(a.fundamentalHz, closeTo(f0, 1e-9));
      }
    });

    test(
      'pico só em f/2 (sem outros ímpares) mas forte o bastante: corrige',
      () {
        final f0 = strings.first.targetFrequency;
        final a = analyzer.analyze(toneFrame(f0, [0.25, 1, 0, 0.2]), 2 * f0)!;
        expect(a.correction, OctaveCorrection.down);
      },
    );

    test('ímpares fracos demais (< −25 dB da energia): não corrige', () {
      final f0 = strings.first.targetFrequency;
      final a = analyzer.analyze(toneFrame(f0, [0.02, 1, 0.02, 0.3]), 2 * f0)!;
      expect(a.correction, OctaveCorrection.none);
      expect(a.lowerOddEnergyRatio, lessThan(0.003));
    });

    test('sem pico em f/2, mesmo com componente em 1.5·f: não corrige '
        '(ressonância de outra corda)', () {
      // D3 tocada; A2 vibrando por simpatia tem H2 = 220 Hz ≈ 1.5 × D3.
      final d3 = strings[2].targetFrequency;
      final a2 = strings[1].targetFrequency;
      final frame = SyntheticSignals.frame(
        SyntheticSignals.partials(
          components: [
            for (var h = 1; h <= 6; h++) (hz: d3 * h, amplitude: 1 / h),
            for (var h = 1; h <= 6; h++) (hz: a2 * h, amplitude: 0.3 / h),
          ],
          sampleRate: 48000,
          length: 4096,
        ),
        48000,
      );
      final a = analyzer.analyze(frame, d3)!;
      expect(a.correction, OctaveCorrection.none);
    });

    test('notas corretas nunca são corrigidas (6 perfis × 6 cordas × '
        '4 configurações × ±25 cents)', () {
      const profiles = [
        [1.0],
        [1.0, 0.6, 0.4, 0.25, 0.15],
        [1.0, 0.8, 0.7, 0.6, 0.5, 0.4, 0.3, 0.2],
        [0.5, 1.0, 0.3, 0.2],
        [0.1, 1.0, 0.6, 0.4],
        [0.0, 1.0, 0.7, 0.5],
      ];
      for (final h in profiles) {
        for (final (sr, n) in configs) {
          for (final s in strings) {
            for (final detune in [-25.0, 0.0, 25.0]) {
              final f = s.targetFrequency * math.pow(2, detune / 1200);
              final a = analyzer.analyze(
                toneFrame(f, h, sampleRate: sr, size: n),
                f,
              )!;
              expect(
                a.correction,
                OctaveCorrection.none,
                reason: '${s.note} $detune c $h @ $sr/$n',
              );
            }
          }
        }
      }
    });

    test('nunca corrige para abaixo de 60 Hz (A2 → 55 Hz)', () {
      final a2 = strings[1].targetFrequency;
      final a = analyzer.analyze(toneFrame(a2 / 2, [0.3, 1, 0.3]), a2)!;
      expect(a.fundamentalHz, greaterThanOrEqualTo(60));
    });
  });

  group('correção para cima (sub-harmônico)', () {
    test('tom de 500 Hz visto como 250 Hz: o espectro indica 500 Hz', () {
      for (final h in [
        [1.0],
        [1.0, 0.5, 0.3],
      ]) {
        final a = analyzer.analyze(toneFrame(500, h), 250)!;
        expect(a.correction, OctaveCorrection.up);
        expect(a.fundamentalHz, closeTo(500, 1e-9));
      }
    });

    test('fundamental ausente com H3 presente não é tratada como '
        'sub-harmônico', () {
      final f0 = strings[2].targetFrequency;
      final a = analyzer.analyze(toneFrame(f0, [0, 1, 0.7, 0.5]), f0)!;
      expect(a.correction, OctaveCorrection.none);
    });
  });

  group('harmonicidade (sem thresholds definitivos; apenas ordenação)', () {
    double harmonicity(AudioFrame frame, double seed) =>
        analyzer.analyze(frame, seed)!.harmonicity;

    test('séries harmônicas completas ≈ 1', () {
      for (final s in strings) {
        final f = s.targetFrequency;
        for (final h in [
          [1.0],
          [1.0, 0.8, 0.7, 0.6, 0.5, 0.4, 0.3, 0.2],
          [0.1, 1.0, 0.6, 0.4],
        ]) {
          expect(harmonicity(toneFrame(f, h), f), greaterThan(0.95));
        }
      }
    });

    test('fundamental ausente: menor que série completa (completude 3/4)', () {
      final f = strings[1].targetFrequency;
      expect(
        harmonicity(toneFrame(f, [0, 1, 0.7, 0.5]), f),
        closeTo(0.75, 0.02),
      );
    });

    test('ruído branco ≪ qualquer corda', () {
      var maxNoise = 0.0;
      for (var seed = 1; seed <= 50; seed++) {
        final frame = SyntheticSignals.frame(
          SyntheticSignals.whiteNoise(length: 4096, seed: seed),
          48000,
        );
        maxNoise = math.max(maxNoise, harmonicity(frame, 110));
      }
      expect(maxNoise, lessThan(0.1));
    });

    test('parciais inarmônicos < corda harmônica', () {
      for (final s in strings) {
        final f = s.targetFrequency;
        final frame = SyntheticSignals.frame(
          SyntheticSignals.partials(
            components: [
              (hz: f, amplitude: 1),
              (hz: f * 1.37, amplitude: 0.8),
              (hz: f * 2.21, amplitude: 0.6),
              (hz: f * 3.53, amplitude: 0.5),
            ],
            sampleRate: 48000,
            length: 4096,
          ),
          48000,
        );
        final harmonicString = harmonicity(toneFrame(f, [1, 0.8, 0.6, 0.5]), f);
        // Com a semente exatamente em f, só o parcial em f casa com a série:
        // a métrica cai para ~a fração de energia desse parcial (0.44–0.55).
        expect(
          harmonicity(frame, f),
          lessThan(harmonicString - 0.3),
          reason: '${s.note}',
        );
      }
    });

    test('mistura de duas cordas sem relação harmônica < corda isolada', () {
      final f = strings[1].targetFrequency;
      final frame = SyntheticSignals.frame(
        SyntheticSignals.partials(
          components: [
            for (var h = 1; h <= 5; h++) (hz: f * h, amplitude: 1 / h),
            for (var h = 1; h <= 5; h++)
              (hz: f * 1.4142 * h, amplitude: 0.8 / h),
          ],
          sampleRate: 48000,
          length: 4096,
        ),
        48000,
      );
      expect(harmonicity(frame, f), lessThan(0.7));
    });

    test('glissando harmônico continua harmônico (não distingue fala '
        'sonora de corda)', () {
      final f = strings[1].targetFrequency;
      final frame = SyntheticSignals.frame(
        SyntheticSignals.glide(
          startHz: f,
          centsPerSecond: 600,
          sampleRate: 48000,
          length: 4096,
        ),
        48000,
      );
      expect(harmonicity(frame, f * math.pow(2, 25 / 1200)), greaterThan(0.9));
    });
  });

  group('refinamento', () {
    test('série limpa: refinado ≈ f0', () {
      for (final s in strings) {
        final f = s.targetFrequency;
        final a = analyzer.analyze(toneFrame(f, [1, 0.6, 0.4, 0.25]), f)!;
        expect(a.refinedHz!, closeTo(f, f * 1e-4)); // < 0.2 cent
        expect(a.harmonicsFound, 4);
      }
    });
  });

  test('frame curto demais para resolver a semente: sem análise', () {
    final frame = toneFrame(82.41, [1], size: 1024); // 46.9 Hz/bin
    expect(analyzer.analyze(frame, 82.41), isNull);
  });
}
