import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:guitar_zero/core/music/tuning.dart';
import 'package:guitar_zero/core/tuner/tuner_config.dart';
import 'package:guitar_zero/core/tuner/tuner_pipeline.dart';
import 'package:guitar_zero/core/tuner/tuner_reading.dart';

import '../../support/pitch_sequences.dart';

// Cenários temporais do pipeline completo, com estimativas sintéticas a
// cada 40 ms. Critérios definidos antes de executar; números detalhados em
// `dart run tool/temporal_report.dart` e docs/DSP_STRATEGY.md.

final strings = Tuning.standard.strings;
final e2 = strings[0].targetFrequency;
final a2 = strings[1].targetFrequency;
final d3 = strings[2].targetFrequency;

TunerPipeline pipeline({int window = 3}) =>
    TunerPipeline(config: TunerConfig(stabilityWindow: window));

List<TunerReading?> run(PitchSequenceBuilder b, {int window = 3}) =>
    runPipeline(pipeline(window: window), b.build());

Iterable<TunerReading> live(Iterable<TunerReading?> out) =>
    out.whereType<TunerReading>().where((r) => !r.isHeld);

int inTuneTransitions(List<TunerReading?> out) {
  var n = 0;
  for (var i = 1; i < out.length; i++) {
    if ((out[i]?.isInTune ?? false) != (out[i - 1]?.isInTune ?? false)) n++;
  }
  return n;
}

void main() {
  group('1. nota perfeitamente estável', () {
    for (final window in [3, 5]) {
      test('janela $window: aquisição em ${(window - 1) * 40} ms, depois '
          'leitura contínua e exata', () {
        final out = run(PitchSequenceBuilder()..note(a2, 30), window: window);
        final first = out.indexWhere((r) => r != null);
        expect(first, window - 1);
        for (final r in out.skip(first)) {
          expect(r!.isHeld, isFalse);
          expect(r.string.note.toString(), 'A2');
          expect(r.cents, closeTo(0, 0.01));
          expect(r.isInTune, isTrue);
        }
      });
    }
  });

  group('2. jitter', () {
    for (final jitter in [1.0, 3.0, 10.0]) {
      test('±${jitter.toInt()} cents: menos variação na saída, sem viés', () {
        final out = run(
          PitchSequenceBuilder(seed: 5)..note(a2, 200, jitterCents: jitter),
        );
        final settled = live(out.skip(25)).map((r) => r.cents).toList();
        expect(settled.length, 175, reason: 'nenhum frame bloqueado');
        final p2p = settled.reduce(math.max) - settled.reduce(math.min);
        final mean = settled.reduce((a, b) => a + b) / settled.length;
        expect(p2p, lessThan(2 * jitter));
        expect(mean.abs(), lessThan(1));
      });
    }

    test('±1 e ±3 cents em torno de 0: "afinado" não pisca', () {
      for (final jitter in [1.0, 3.0]) {
        final out = run(
          PitchSequenceBuilder(seed: 5)..note(a2, 200, jitterCents: jitter),
        );
        expect(inTuneTransitions(out.skip(2).toList()), 0);
      }
    });

    test('leitura oscilando entre +1 e +5.5 cents não pisca o "afinado"', () {
      final out = run(
        PitchSequenceBuilder(seed: 9)
          ..note(a2, 200, cents: 3.25, jitterCents: 2.25),
      );
      // Pode entrar uma vez; nunca sai (máximo 5.5 < 6).
      expect(inTuneTransitions(out), lessThanOrEqualTo(1));
    });
  });

  group('3. outlier único', () {
    for (final window in [3, 5]) {
      test('janela $window: nunca aparece na tela; leitura congela por '
          '$window frames', () {
        final out = run(
          PitchSequenceBuilder()
            ..note(a2, 15)
            ..note(a2, 1, cents: 80)
            ..note(a2, 15),
          window: window,
        );
        for (final r in out.skip(window - 1)) {
          expect(r, isNotNull);
          expect(r!.cents.abs(), lessThan(0.01));
        }
        expect(out.skip(15).takeWhile((r) => r!.isHeld).length, window);
      });
    }
  });

  group('4. ruído e fala', () {
    test(
      'frequências aleatórias quase nunca passam (janela 3) e nunca (5)',
      () {
        final steps = (PitchSequenceBuilder(
          seed: 11,
        )..randomFrequencies(2000)).build();
        final n3 = live(runPipeline(pipeline(), steps)).length;
        final n5 = live(runPipeline(pipeline(window: 5), steps)).length;
        expect(n3, lessThan(10)); // < 0.5 %
        expect(n5, 0);
      },
    );

    test('glissandos tipo fala: janela 5 aceita menos que janela 3', () {
      final steps = (PitchSequenceBuilder(seed: 12)..speechLike(2000)).build();
      final n3 = live(runPipeline(pipeline(), steps)).length;
      final n5 = live(runPipeline(pipeline(window: 5), steps)).length;
      expect(n5, lessThan(n3));
      // LIMITAÇÃO documentada: glissandos lentos passam pelo gate.
      expect(n3, greaterThan(0));
    });
  });

  group('5–6. ajuste gradual de −40 até 0 e ultrapassagem até +10', () {
    test('acompanha a rampa sem bloquear, com atraso ≤ 5 cents', () {
      final out = run(
        PitchSequenceBuilder()
          ..note(a2, 5, cents: -40)
          ..ramp(a2, 51, fromCents: -40, toCents: 0) // 20 cents/s
          ..note(a2, 15),
      );
      for (var i = 0; i < 51; i++) {
        final r = out[5 + i]!;
        expect(r.isHeld, isFalse);
        final truth = -40 + 40 * i / 50;
        expect(r.cents, inInclusiveRange(truth - 5, truth));
      }
      expect(out.last!.cents, closeTo(0, 0.5));
      expect(out.last!.isInTune, isTrue);
    });

    test('ultrapassar o zero: entra afinado em −3, sai acima de +6', () {
      final out = run(
        PitchSequenceBuilder()
          ..note(a2, 5, cents: -40)
          ..ramp(a2, 101, fromCents: -40, toCents: 10) // 12.5 cents/s
          ..note(a2, 15, cents: 10),
      );
      expect(inTuneTransitions(out), 2);
      final enter = out.indexWhere((r) => r?.isInTune ?? false);
      final leave = out.indexWhere((r) => !(r?.isInTune ?? true), enter);
      expect(out[enter]!.cents, inInclusiveRange(-3, 0));
      expect(out[leave]!.cents, greaterThan(6));
      expect(out[leave - 1]!.cents, lessThanOrEqualTo(6));
    });
  });

  group('7. mudança de corda', () {
    for (final window in [3, 5]) {
      test('janela $window: E2 → A2 sem leituras intermediárias', () {
        final out = run(
          PitchSequenceBuilder()
            ..note(e2, 20, cents: -8)
            ..note(a2, 20, cents: 12),
          window: window,
        );
        final afterSwitch = out.sublist(20);
        // Enquanto a nova nota é adquirida, a tela mantém E2 (hold).
        final heldE2 = afterSwitch.takeWhile((r) => r!.isHeld).toList();
        expect(heldE2.length, window - 1);
        expect(heldE2.every((r) => r!.string.note.toString() == 'E2'), isTrue);
        // A primeira leitura de A2 já está no valor real (sem deslizar).
        final firstA2 = afterSwitch[window - 1]!;
        expect(firstA2.string.note.toString(), 'A2');
        expect(firstA2.cents, closeTo(12, 0.01));
      });
    }
  });

  group('8. salto de oitava', () {
    test('temporário (E2 → E3 por 200 ms): leitura continua em E2', () {
      final out = run(
        PitchSequenceBuilder()
          ..note(e2, 20, cents: -5)
          ..note(e2 * 2, 5, cents: -5)
          ..note(e2, 20, cents: -5),
      );
      for (final r in out.skip(2)) {
        expect(r!.isHeld, isFalse);
        expect(r.string.note.toString(), 'E2');
        expect(r.cents, closeTo(-5, 0.01));
      }
    });

    test('caminho inverso (D3 → D2 por 200 ms): leitura continua em D3', () {
      final out = run(
        PitchSequenceBuilder()
          ..note(d3, 20, cents: 4)
          ..note(d3 / 2, 5, cents: 4)
          ..note(d3, 20, cents: 4),
      );
      for (final r in out.skip(2)) {
        expect(r!.string.note.toString(), 'D3');
        expect(r.cents, closeTo(4, 0.01));
      }
    });

    test('alternando (YIN instável entre oitavas): nunca troca de oitava', () {
      final b = PitchSequenceBuilder()..note(e2, 10);
      for (var i = 0; i < 30; i++) {
        b.note(i.isEven ? e2 * 2 : e2, 1);
      }
      final out = run(b);
      for (final r in out.skip(2)) {
        expect(r!.string.note.toString(), 'E2');
        expect(r.cents.abs(), lessThan(0.01));
      }
    });

    test('persistente por 1 s: aceito como mudança real após ~600 ms', () {
      final out = run(
        PitchSequenceBuilder()
          ..note(e2, 20)
          ..note(e2 * 2, 25), // E3: entre D3 e G3
      );
      final afterJump = out.sublist(20);
      final stillE2 = afterJump.takeWhile(
        (r) => r!.string.note.toString() == 'E2',
      );
      // 15 frames (600 ms) dobrados + aquisição pelo stability gate.
      expect(stillE2.length, inInclusiveRange(15, 18));
      expect(afterJump.last!.string.note.toString(), isNot('E2'));
    });

    test(
      'LIMITAÇÃO: oitava errada desde a primeira detecção não é corrigida',
      () {
        final out = run(PitchSequenceBuilder()..note(e2 * 2, 20));
        expect(out.last!.frequency, closeTo(e2 * 2, 0.01));
      },
    );
  });

  group('9–10. silêncio e retorno', () {
    test('sinal some: mantém por 700 ms (isHeld), depois espera', () {
      final out = run(
        PitchSequenceBuilder()
          ..note(a2, 10, cents: 7)
          ..silence(25),
      );
      final silence = out.sublist(10);
      // Última leitura em 360 ms; hold até 1060 ms → frames 400..1040.
      for (final r in silence.take(17)) {
        expect(r!.isHeld, isTrue);
        expect(r.cents, closeTo(7, 0.01));
      }
      expect(silence.skip(17), everyElement(isNull));
    });

    test('retorno durante o hold: não passa pelo estado de espera', () {
      final out = run(
        PitchSequenceBuilder()
          ..note(a2, 10, cents: 7)
          ..silence(10)
          ..note(a2, 10, cents: 2),
      );
      expect(out.skip(2), everyElement(isNotNull));
      expect(out.last!.isHeld, isFalse);
      expect(out.last!.cents, closeTo(2, 2));
    });

    test('após o hold, a próxima nota começa sem histerese de corda', () {
      final out = run(
        PitchSequenceBuilder()
          ..note(e2, 10)
          ..silence(25)
          ..note(e2, 10, cents: 260), // mais perto de A2
      );
      expect(out.last!.string.note.toString(), 'A2');
    });
  });

  group('11. nova nota após salto > 250 cents', () {
    test('E2 → D3 (1000 cents): primeira leitura já no valor real', () {
      final out = run(
        PitchSequenceBuilder()
          ..note(e2, 20)
          ..note(d3, 10, cents: -15),
      );
      final firstD3 = out.firstWhere((r) => r?.string.note.toString() == 'D3')!;
      expect(firstD3.cents, closeTo(-15, 0.01));
    });

    test('mesma corda, salto de 300 cents: sem deslizar', () {
      final out = run(
        PitchSequenceBuilder()
          ..note(a2, 20, cents: -150)
          ..note(a2, 10, cents: 150),
      );
      final firstAfter = out.sublist(20).firstWhere((r) => !r!.isHeld)!;
      expect(firstAfter.cents, closeTo(150, 0.01));
    });

    test('salto menor que o limiar (40 cents) é suavizado', () {
      final out = run(
        PitchSequenceBuilder()
          ..note(a2, 20, cents: -20)
          ..note(a2, 10, cents: 20),
      );
      final firstAfter = out.sublist(20).firstWhere((r) => !r!.isHeld)!;
      expect(firstAfter.cents, lessThan(20));
    });
  });

  group('janela 3 vs 5: giro rápido da tarraxa (200 cents/s)', () {
    test('janela 3 acompanha; janela 5 congela (mostra leitura antiga)', () {
      PitchSequenceBuilder sequence() => PitchSequenceBuilder()
        ..note(a2, 10, cents: -60)
        ..ramp(a2, 16, fromCents: -60, toCents: 60)
        ..note(a2, 20, cents: 60);
      final out3 = run(sequence()).sublist(10, 26);
      final out5 = run(sequence(), window: 5).sublist(10, 26);
      expect(live(out3).length, 16);
      expect(live(out5).length, lessThan(8));
    });
  });

  group('latência de aquisição (hop 40 ms)', () {
    for (final (window, expectedMs) in [(3, 80), (5, 160)]) {
      test('janela $window: $expectedMs ms após a primeira estimativa', () {
        final steps = (PitchSequenceBuilder()..note(a2, 10)).build();
        final out = runPipeline(pipeline(window: window), steps);
        final first = out.indexWhere((r) => r != null);
        expect(steps[first].t.inMilliseconds, expectedMs);
      });
    }
  });

  test('determinístico: mesma sequência → mesma saída', () {
    final steps =
        (PitchSequenceBuilder(seed: 3)
              ..note(a2, 30, jitterCents: 3)
              ..silence(5)
              ..note(d3, 30, jitterCents: 3))
            .build();
    final a = runPipeline(pipeline(), steps).map((r) => r?.cents).toList();
    final b = runPipeline(pipeline(), steps).map((r) => r?.cents).toList();
    expect(a, b);
  });
}
