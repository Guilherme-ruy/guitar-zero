import 'package:flutter_test/flutter_test.dart';
import 'package:guitar_zero/core/dsp/harmonic_pitch_detector.dart';
import 'package:guitar_zero/core/dsp/pitch_detector.dart';
import 'package:guitar_zero/core/dsp/yin_pitch_detector.dart';
import 'package:guitar_zero/core/music/pitch_math.dart';
import 'package:guitar_zero/core/music/tuning.dart';
import 'package:guitar_zero/core/tuner/tuner_config.dart';

import '../../support/synthetic_signals.dart';

// Erros de oitava: o YIN isolado (fase 1) e a correção espectral (fase 3).
//
// Os casos que na fase 1 eram "LIMITAÇÃO CONHECIDA" continuam afirmando o
// erro do YIN ISOLADO (que segue verdadeiro: o YIN não mudou) e agora também
// exigem que o HarmonicPitchDetector retorne a oitava correta.
//
// Números: docs/DSP_STRATEGY.md, fases 1 e 3.

final yin = YinPitchDetector();
final harmonic = HarmonicPitchDetector();
final minConfidence = const TunerConfig().minConfidence;
final strings = Tuning.standard.strings;
const configs = [(44100, 4096), (44100, 8192), (48000, 4096), (48000, 8192)];

/// Desvio em oitavas (arredondado) da estimativa de [detector] em relação a
/// [f0], e a periodicidade. `null` se não houve estimativa.
({int octave, double periodicity})? octaveOf(
  PitchDetector detector,
  double f0,
  List<double> harmonics, {
  int sampleRate = 48000,
  int frameSize = 4096,
}) {
  final e = detector.detect(
    SyntheticSignals.frame(
      SyntheticSignals.tone(
        frequencyHz: f0,
        sampleRate: sampleRate,
        length: frameSize,
        harmonics: harmonics,
      ),
      sampleRate,
    ),
  );
  if (e == null) return null;
  return (
    octave: (centsBetween(e.frequencyHz, f0) / 1200).round(),
    periodicity: e.periodicity,
  );
}

void main() {
  group('oitava correta (YIN e detector harmônico)', () {
    final cases = <String, List<double>>{
      'H2 dominante, fundamental 0.5': [0.5, 1, 0.3, 0.2],
      'H2 dominante, fundamental 0.3, sem H3': [0.3, 1, 0, 0.2],
      'fundamental fraca (0.1) com H3 forte (0.6)': [0.1, 1, 0.6, 0.4],
      'fundamental ausente com H3 (0.7)': [0, 1, 0.7, 0.5],
    };
    for (final MapEntry(key: name, value: harmonics) in cases.entries) {
      test('$name — todas as cordas e configurações', () {
        for (final string in strings) {
          for (final (sr, size) in configs) {
            for (final detector in [yin, harmonic]) {
              final r = octaveOf(
                detector,
                string.targetFrequency,
                harmonics,
                sampleRate: sr,
                frameSize: size,
              );
              expect(
                r?.octave,
                0,
                reason: '${detector.runtimeType} ${string.note} @ $sr/$size',
              );
            }
          }
        }
      });
    }
  });

  group('H2 dominante + fundamental e H3 fracos [.1 1 .1 .3]', () {
    const weak = [0.1, 1.0, 0.1, 0.3];

    test('YIN isolado: E2, A2, D3, G3 saem UMA OITAVA ACIMA com '
        'periodicidade ≥ 0.90 (limitação da fase 1, ainda verdadeira)', () {
      for (final string in strings.take(4)) {
        for (final (sr, size) in configs) {
          final r = octaveOf(
            yin,
            string.targetFrequency,
            weak,
            sampleRate: sr,
            frameSize: size,
          )!;
          expect(r.octave, 1, reason: '${string.note} @ $sr/$size');
          expect(r.periodicity, greaterThanOrEqualTo(minConfidence));
        }
      }
    });

    test('CORRIGIDO: detector harmônico retorna a fundamental de E2, A2, '
        'D3, G3', () {
      for (final string in strings.take(4)) {
        for (final (sr, size) in configs) {
          final r = octaveOf(
            harmonic,
            string.targetFrequency,
            weak,
            sampleRate: sr,
            frameSize: size,
          );
          expect(r?.octave, 0, reason: '${string.note} @ $sr/$size');
        }
      }
    });

    test('B3 e E4 continuam corretos (YIN e detector harmônico)', () {
      for (final string in strings.skip(4)) {
        for (final (sr, size) in configs) {
          for (final detector in [yin, harmonic]) {
            final r = octaveOf(
              detector,
              string.targetFrequency,
              weak,
              sampleRate: sr,
              frameSize: size,
            );
            expect(r?.octave, 0, reason: '${string.note} @ $sr/$size');
          }
        }
      }
    });
  });

  group('E2 sem H3: varredura da fundamental', () {
    final e2 = strings.first.targetFrequency;

    test('YIN isolado erra a partir de fundamental ≈ 0.28 × H2', () {
      for (final size in [4096, 8192]) {
        expect(
          octaveOf(yin, e2, [0.35, 1, 0, 0.2], frameSize: size)!.octave,
          0,
        );
        expect(
          octaveOf(yin, e2, [0.25, 1, 0, 0.2], frameSize: size)!.octave,
          1,
        );
      }
    });

    test('CORRIGIDO: detector harmônico acerta de 0.28 até 0.06', () {
      for (final size in [4096, 8192]) {
        for (var a1 = 0.28; a1 >= 0.06; a1 -= 0.01) {
          expect(
            octaveOf(harmonic, e2, [a1, 1, 0, 0.2], frameSize: size)!.octave,
            0,
            reason: 'a1 = ${a1.toStringAsFixed(2)} @ $size',
          );
        }
      }
    });

    test('LIMITAÇÃO: com fundamental ≤ 0.05 × H2 e sem H3 não há evidência '
        'suficiente; o erro do YIN permanece', () {
      expect(octaveOf(harmonic, e2, [0.04, 1, 0, 0.2])!.octave, 1);
    });

    test('H3 ≥ 0.4 elimina o erro mesmo no YIN isolado', () {
      expect(octaveOf(yin, e2, [0.01, 1, 0.4, 0.2])!.octave, 0);
    });
  });

  test('sinal só com harmônicos pares tem período T/2 de fato: ambos '
      'reportam a oitava acima (resposta matematicamente correta)', () {
    final e2 = strings.first.targetFrequency;
    expect(octaveOf(yin, e2, [0, 1, 0, 0.5])!.octave, 1);
    expect(octaveOf(harmonic, e2, [0, 1, 0, 0.5])!.octave, 1);
  });

  group('tons acima de 450 Hz', () {
    for (final hz in [500.0, 660.0, 900.0]) {
      final frame = SyntheticSignals.frame(
        SyntheticSignals.tone(
          frequencyHz: hz,
          sampleRate: 48000,
          length: 4096,
          harmonics: const [1, 0.5, 0.3],
        ),
        48000,
      );

      test('$hz Hz — YIN isolado reporta o sub-harmônico ${hz / 2} Hz', () {
        final e = yin.detect(frame)!;
        expect(e.frequencyHz, closeTo(hz / 2, 0.1));
        expect(e.periodicity, greaterThanOrEqualTo(minConfidence));
      });

      test(
        '$hz Hz — CORRIGIDO: detector harmônico rejeita (fora da faixa)',
        () {
          expect(harmonic.detect(frame), isNull);
        },
      );
    }
  });
}
