import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:guitar_zero/core/audio/audio_frame.dart';
import 'package:guitar_zero/core/dsp/pitch_estimate.dart';
import 'package:guitar_zero/core/dsp/yin_pitch_detector.dart';
import 'package:guitar_zero/core/music/pitch_math.dart';
import 'package:guitar_zero/core/music/tuning.dart';
import 'package:guitar_zero/core/tuner/tuner_config.dart';

import '../../support/synthetic_signals.dart';

// Critérios definidos antes da implementação:
// - sinais periódicos limpos: erro ≤ 1 cent (resolução útil de um afinador;
//   a zona de "afinado" será de 3 a 6 cents);
// - confiança ≥ TunerConfig().minConfidence (0.90) para notas reais;
// - silêncio sem estimativa; ruído nunca com confiança ≥ 0.90.
const double maxCleanErrorCents = 1;
final double minConfidence = const TunerConfig().minConfidence;

const sampleRates = [44100, 48000];
const frameSizes = [4096, 8192];
const detunesCents = [-25.0, 0.0, 25.0];

final detector = YinPitchDetector();

PitchEstimate? detectTone(
  double frequencyHz,
  int sampleRate,
  int frameSize, {
  List<double> harmonics = const [1],
  double amplitude = 0.5,
  double dcOffset = 0,
  double noise = 0,
}) => detector.detect(
  SyntheticSignals.frame(
    SyntheticSignals.tone(
      frequencyHz: frequencyHz,
      sampleRate: sampleRate,
      length: frameSize,
      harmonics: harmonics,
      amplitude: amplitude,
      dcOffset: dcOffset,
      noise: noise,
    ),
    sampleRate,
  ),
);

void expectAccurate(
  PitchEstimate? estimate,
  double expectedHz, {
  double toleranceCents = maxCleanErrorCents,
}) {
  expect(estimate, isNotNull, reason: 'esperava pitch em $expectedHz Hz');
  final error = centsBetween(estimate!.frequencyHz, expectedHz);
  expect(
    error.abs(),
    lessThanOrEqualTo(toleranceCents),
    reason: 'erro de ${error.toStringAsFixed(4)} cents em $expectedHz Hz',
  );
  expect(estimate.confidence, greaterThanOrEqualTo(minConfidence));
}

void main() {
  group('senoide pura: 6 cordas × 44.1/48 kHz × 4096/8192 × ±25 cents', () {
    for (final string in Tuning.standard.strings) {
      for (final sampleRate in sampleRates) {
        for (final frameSize in frameSizes) {
          for (final detune in detunesCents) {
            final f = frequencyFromMidi(string.note.midi + detune / 100);
            test('${string.note} ${detune >= 0 ? '+' : ''}${detune.toInt()}c '
                '@ $sampleRate/$frameSize', () {
              expectAccurate(detectTone(f, sampleRate, frameSize), f);
            });
          }
        }
      }
    }
  });

  group('fundamental + harmônicos', () {
    const profiles = <String, List<double>>{
      'violão típico': [1, 0.6, 0.4, 0.25, 0.15],
      'rico em harmônicos': [1, 0.8, 0.7, 0.6, 0.5, 0.4, 0.3, 0.2],
      'H2 mais forte que a fundamental': [0.5, 1, 0.3, 0.2],
      'fundamental fraca, H3 presente': [0.1, 1, 0.6, 0.4],
      'fundamental ausente, H3 presente': [0, 1, 0.7, 0.5],
    };
    for (final MapEntry(key: name, value: harmonics) in profiles.entries) {
      for (final sampleRate in sampleRates) {
        for (final frameSize in frameSizes) {
          test('$name @ $sampleRate/$frameSize (6 cordas, ±25 cents)', () {
            for (final string in Tuning.standard.strings) {
              for (final detune in detunesCents) {
                final f = frequencyFromMidi(string.note.midi + detune / 100);
                expectAccurate(
                  detectTone(f, sampleRate, frameSize, harmonics: harmonics),
                  f,
                );
              }
            }
          });
        }
      }
    }
  });

  group('DC offset e amplitude', () {
    final a2 = Tuning.standard.strings[1].targetFrequency;
    const harmonics = [1.0, 0.5, 0.3];

    for (final dc in [-0.3, 0.2, 0.5]) {
      test('DC offset $dc não altera o resultado', () {
        final withDc = detectTone(
          a2,
          48000,
          4096,
          harmonics: harmonics,
          dcOffset: dc,
        );
        final withoutDc = detectTone(a2, 48000, 4096, harmonics: harmonics);
        expectAccurate(withDc, a2);
        expect(withDc!.frequencyHz, closeTo(withoutDc!.frequencyHz, 1e-6));
        expect(withDc.rms, closeTo(withoutDc.rms!, 1e-6));
      });
    }

    test('frequência e confiança independem da amplitude', () {
      final reference = detectTone(a2, 48000, 4096, harmonics: harmonics);
      for (final amplitude in [0.9, 0.1, 0.01]) {
        final e = detectTone(
          a2,
          48000,
          4096,
          harmonics: harmonics,
          amplitude: amplitude,
        );
        expectAccurate(e, a2);
        expect(e!.frequencyHz, closeTo(reference!.frequencyHz, 1e-4));
        expect(e.confidence, closeTo(reference.confidence, 1e-4));
      }
    });

    test('rms reportado corresponde ao sinal (senoide: A/√2)', () {
      final e = detectTone(a2, 48000, 8192, amplitude: 0.4, dcOffset: 0.3);
      expect(e!.rms, closeTo(0.4 / 1.4142135, 0.002));
    });

    test('abaixo de minRms (0.004) não há estimativa', () {
      // Senoide de pico 0.005 → RMS ≈ 0.0035.
      expect(detectTone(a2, 48000, 4096, amplitude: 0.005), isNull);
      // Pico 0.006 → RMS ≈ 0.0042: analisado normalmente.
      expectAccurate(detectTone(a2, 48000, 4096, amplitude: 0.006), a2);
    });
  });

  group('silêncio e ruído', () {
    for (final sampleRate in sampleRates) {
      for (final frameSize in frameSizes) {
        test('silêncio digital @ $sampleRate/$frameSize', () {
          final frame = AudioFrame(
            samples: Float32List(frameSize),
            sampleRate: sampleRate,
            timestamp: Duration.zero,
          );
          expect(detector.detect(frame), isNull);
        });

        test('ruído branco nunca atinge minConfidence '
            '@ $sampleRate/$frameSize (100 sementes, 2 níveis)', () {
          for (final peak in [0.5, 0.02]) {
            for (var seed = 1; seed <= 100; seed++) {
              final e = detector.detect(
                SyntheticSignals.frame(
                  SyntheticSignals.whiteNoise(
                    length: frameSize,
                    peak: peak,
                    seed: seed,
                  ),
                  sampleRate,
                ),
              );
              if (e != null) {
                expect(
                  e.confidence,
                  lessThan(minConfidence),
                  reason: 'semente $seed, pico $peak: $e',
                );
              }
            }
          }
        });
      }
    }

    test('ruído de fundo abaixo do gate não produz estimativa', () {
      final frame = SyntheticSignals.frame(
        SyntheticSignals.whiteNoise(length: 4096, peak: 0.005),
        48000,
      );
      expect(detector.detect(frame), isNull);
    });

    test('tom com ruído moderado (pico 0.05, ~SNR 20 dB) ainda é preciso', () {
      for (final string in Tuning.standard.strings) {
        final f = string.targetFrequency;
        expectAccurate(
          detectTone(
            f,
            48000,
            4096,
            harmonics: const [1, 0.6, 0.4, 0.25],
            noise: 0.05,
          ),
          f,
          toleranceCents: 2,
        );
      }
    });
  });

  test('ruído forte (pico 0.2, ~SNR 12 dB): estimativas confiáveis nunca '
      'caem em outra nota', () {
    for (final string in Tuning.standard.strings) {
      for (final frameSize in frameSizes) {
        for (var seed = 1; seed <= 20; seed++) {
          final f = string.targetFrequency;
          final e = detector.detect(
            SyntheticSignals.frame(
              SyntheticSignals.tone(
                frequencyHz: f,
                sampleRate: 48000,
                length: frameSize,
                harmonics: const [1, 0.6, 0.4, 0.25],
                noise: 0.2,
                seed: seed,
              ),
              48000,
            ),
          );
          if (e == null || e.confidence < minConfidence) continue;
          expect(
            centsBetween(e.frequencyHz, f).abs(),
            lessThan(50),
            reason: '${string.note} @ $frameSize, semente $seed: $e',
          );
        }
      }
    }
  });

  group('ataque / transiente', () {
    for (final string in Tuning.standard.strings) {
      for (final frameSize in frameSizes) {
        test('${string.note} @ 48000/$frameSize', () {
          const sampleRate = 48000;
          final f = string.targetFrequency;
          final signal = SyntheticSignals.pluck(
            frequencyHz: f,
            sampleRate: sampleRate,
            length: frameSize + sampleRate ~/ 10,
          );
          for (var offset = 0; offset <= sampleRate ~/ 10; offset += 480) {
            final e = detector.detect(
              SyntheticSignals.frame(
                signal,
                sampleRate,
                offset: offset,
                length: frameSize,
              ),
            );
            final error = e == null ? 0.0 : centsBetween(e.frequencyHz, f);
            if (offset == 0) {
              // Frame que contém o ataque: pode errar alguns cents, mas
              // nunca dar uma nota errada com confiança alta.
              if (e != null && e.confidence >= minConfidence) {
                expect(error.abs(), lessThanOrEqualTo(5), reason: '$e');
              }
            } else {
              // A partir de 10 ms após o ataque: precisão total.
              expectAccurate(e, f);
            }
          }
        });
      }
    }
  });

  group('restrição de frequência (60–450 Hz)', () {
    test('abaixo da faixa não gera estimativa confiável', () {
      for (final f in [40.0, 50.0, 55.0]) {
        final e = detectTone(f, 48000, 4096, harmonics: const [1, 0.5, 0.3]);
        expect(
          e == null || e.confidence < minConfidence,
          isTrue,
          reason: '$f Hz → $e',
        );
      }
    });

    test('extremos da faixa ainda são detectados', () {
      expectAccurate(detectTone(62, 48000, 8192), 62);
      expectAccurate(detectTone(440, 48000, 4096), 440);
    });

    test('lags respeitam a faixa configurada', () {
      const config = YinConfig();
      expect(config.minLag(48000), 106); // 48000 / 450
      expect(config.maxLag(48000), 800); // 48000 / 60
      expect(config.minFrameSize(48000), 1602);
      expect(config.minFrameSize(44100), 1472);
    });

    test('faixa configurável', () {
      final narrow = YinPitchDetector(
        config: const YinConfig(minFrequencyHz: 150),
      );
      final e2 = SyntheticSignals.frame(
        SyntheticSignals.tone(
          frequencyHz: 82.41,
          sampleRate: 48000,
          length: 4096,
        ),
        48000,
      );
      final e = narrow.detect(e2);
      expect(e == null || e.confidence < minConfidence, isTrue);
    });
  });

  group('contrato', () {
    test('frame menor que o mínimo lança ArgumentError', () {
      final frame = AudioFrame(
        samples: Float32List(1601),
        sampleRate: 48000,
        timestamp: Duration.zero,
      );
      expect(() => detector.detect(frame), throwsArgumentError);
    });

    test('frame do tamanho mínimo é aceito', () {
      final f = Tuning.standard.strings.last.targetFrequency;
      final frame = SyntheticSignals.frame(
        SyntheticSignals.tone(frequencyHz: f, sampleRate: 48000, length: 1602),
        48000,
      );
      expectAccurate(detector.detect(frame), f);
    });

    test('não modifica as amostras de entrada', () {
      final samples = SyntheticSignals.tone(
        frequencyHz: 110,
        sampleRate: 48000,
        length: 4096,
        dcOffset: 0.2,
      );
      final copy = Float32List.fromList(samples);
      detector.detect(SyntheticSignals.frame(samples, 48000));
      expect(samples, copy);
    });

    test('resultado não depende de frames anteriores', () {
      final fresh = YinPitchDetector();
      final f = Tuning.standard.strings[2].targetFrequency;
      final target = SyntheticSignals.frame(
        SyntheticSignals.tone(frequencyHz: f, sampleRate: 44100, length: 8192),
        44100,
      );
      final first = fresh.detect(target);
      fresh.detect(
        SyntheticSignals.frame(
          SyntheticSignals.whiteNoise(length: 4096, seed: 9),
          48000,
        ),
      );
      final again = fresh.detect(target);
      expect(again!.frequencyHz, first!.frequencyHz);
      expect(again.confidence, first.confidence);
    });
  });
}
