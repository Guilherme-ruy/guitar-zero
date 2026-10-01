import 'package:flutter_test/flutter_test.dart';
import 'package:guitar_zero/core/dsp/yin_pitch_detector.dart';
import 'package:guitar_zero/core/music/pitch_math.dart';
import 'package:guitar_zero/core/music/tuning.dart';
import 'package:guitar_zero/core/tuner/tuner_config.dart';

import '../../support/synthetic_signals.dart';

// Caracterização de erros de oitava do YIN, ANTES de qualquer correção.
//
// Os testes marcados "LIMITAÇÃO CONHECIDA" afirmam o comportamento ERRADO
// atual, para que fique explícito e para que a futura correção (verificação
// de sub-harmônico / refinamento harmônico) quebre estes testes de propósito
// — nesse momento eles devem ser invertidos.
//
// Detalhes e números: docs/DSP_STRATEGY.md, "Resultados da fase 1 — YIN".

final detector = YinPitchDetector();
final minConfidence = const TunerConfig().minConfidence;
final strings = Tuning.standard.strings;

/// Desvio em oitavas (arredondado) do pitch detectado em relação a [f0], e a
/// confiança. `null` se não houve estimativa.
({int octave, double confidence})? octaveOf(
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
    confidence: e.confidence,
  );
}

void main() {
  const configs = [(44100, 4096), (44100, 8192), (48000, 4096), (48000, 8192)];

  group('oitava correta', () {
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
            final r = octaveOf(
              string.targetFrequency,
              harmonics,
              sampleRate: sr,
              frameSize: size,
            );
            expect(r?.octave, 0, reason: '${string.note} @ $sr/$size');
          }
        }
      });
    }
  });

  group('LIMITAÇÃO CONHECIDA: H2 dominante + fundamental e H3 fracos', () {
    // Com H2 = 1 e H3 ≈ 0, o primeiro mínimo da CMNDF abaixo do limiar (0.15)
    // aparece em T/2: d'(T/2) ≈ energia dos harmônicos ímpares / energia total.
    const weak = [0.1, 1.0, 0.1, 0.3];

    test('E2, A2, D3, G3 saem UMA OITAVA ACIMA com confiança ≥ 0.90', () {
      for (final string in strings.take(4)) {
        for (final (sr, size) in configs) {
          final r = octaveOf(
            string.targetFrequency,
            weak,
            sampleRate: sr,
            frameSize: size,
          )!;
          expect(r.octave, 1, reason: '${string.note} @ $sr/$size');
          // O gate de confiança NÃO protege contra este erro.
          expect(r.confidence, greaterThanOrEqualTo(minConfidence));
        }
      }
    });

    test('B3 e E4 ficam corretos: o H2 (> 450 Hz) está fora da faixa', () {
      for (final string in strings.skip(4)) {
        for (final (sr, size) in configs) {
          final r = octaveOf(
            string.targetFrequency,
            weak,
            sampleRate: sr,
            frameSize: size,
          );
          expect(r?.octave, 0, reason: '${string.note} @ $sr/$size');
        }
      }
    });

    test('E2 sem H3: erro a partir de fundamental ≈ 0.28 × H2', () {
      final e2 = strings.first.targetFrequency;
      for (final size in [4096, 8192]) {
        expect(octaveOf(e2, [0.35, 1, 0, 0.2], frameSize: size)!.octave, 0);
        expect(octaveOf(e2, [0.25, 1, 0, 0.2], frameSize: size)!.octave, 1);
      }
    });

    test('E2: H3 ≥ 0.4 elimina o erro mesmo com fundamental 0.01', () {
      final e2 = strings.first.targetFrequency;
      expect(octaveOf(e2, [0.01, 1, 0.4, 0.2])!.octave, 0);
    });
  });

  test('sinal só com harmônicos pares tem período T/2 de fato '
      '(oitava acima é a resposta matematicamente correta)', () {
    final e2 = strings.first.targetFrequency;
    expect(octaveOf(e2, [0, 1, 0, 0.5])!.octave, 1);
  });

  group('LIMITAÇÃO CONHECIDA: tons acima de 450 Hz', () {
    test(
      '500 Hz é reportado como 250 Hz (sub-harmônico) com confiança alta',
      () {
        final e = detector.detect(
          SyntheticSignals.frame(
            SyntheticSignals.tone(
              frequencyHz: 500,
              sampleRate: 48000,
              length: 4096,
              harmonics: const [1, 0.5, 0.3],
            ),
            48000,
          ),
        )!;
        expect(e.frequencyHz, closeTo(250, 0.1));
        expect(e.confidence, greaterThanOrEqualTo(minConfidence));
      },
    );
  });
}
