import 'package:flutter_test/flutter_test.dart';
import 'package:guitar_zero/core/dsp/filters/confidence_gate.dart';
import 'package:guitar_zero/core/dsp/filters/octave_jump_guard.dart';
import 'package:guitar_zero/core/dsp/filters/pitch_smoother.dart';
import 'package:guitar_zero/core/dsp/filters/range_gate.dart';
import 'package:guitar_zero/core/dsp/filters/stability_gate.dart';
import 'package:guitar_zero/core/dsp/pitch_estimate.dart';
import 'package:guitar_zero/core/music/pitch_math.dart';

PitchEstimate est(double hz, [double confidence = 0.97]) =>
    PitchEstimate(frequencyHz: hz, confidence: confidence);

Duration ms(int v) => Duration(milliseconds: v);

double cents(PitchEstimate? e, double refHz) =>
    centsBetween(e!.frequencyHz, refHz);

void main() {
  group('ConfidenceGate', () {
    const gate = ConfidenceGate(minConfidence: 0.9);
    test('aceita ≥ mínimo, descarta abaixo e repassa null', () {
      expect(gate.process(est(110, 0.9), Duration.zero), isNotNull);
      expect(gate.process(est(110, 0.89), Duration.zero), isNull);
      expect(gate.process(null, Duration.zero), isNull);
    });
  });

  group('RangeGate', () {
    const gate = RangeGate(minFrequencyHz: 60, maxFrequencyHz: 450);
    test('limites inclusivos', () {
      expect(gate.process(est(60), Duration.zero), isNotNull);
      expect(gate.process(est(450), Duration.zero), isNotNull);
      expect(gate.process(est(59.9), Duration.zero), isNull);
      expect(gate.process(est(450.1), Duration.zero), isNull);
    });
  });

  group('OctaveJumpGuard', () {
    OctaveJumpGuard newGuard() => OctaveJumpGuard(
      toleranceCents: 50,
      confirmDuration: ms(600),
      memory: ms(2000),
    );
    const e2 = 82.41;

    test('oitava acima temporária é dobrada de volta', () {
      final g = newGuard();
      for (var t = 0; t < 400; t += 40) {
        g.process(est(e2), ms(t));
      }
      final folded = g.process(est(e2 * 2 * 1.002), ms(400));
      expect(cents(folded, e2), closeTo(centsBetween(1.002, 1), 1e-6));
    });

    test('caminho inverso: oitava abaixo é dobrada para cima', () {
      final g = newGuard()..process(est(146.83), Duration.zero);
      final folded = g.process(est(146.83 / 2), ms(40));
      expect(folded!.frequencyHz, closeTo(146.83, 1e-9));
    });

    test('oitava diferente persistente é aceita após confirmDuration', () {
      final g = newGuard()..process(est(e2), Duration.zero);
      final outputs = [
        for (var t = 40; t <= 800; t += 40) g.process(est(e2 * 2), ms(t)),
      ];
      // 40..600 ms: dobrada (a contagem começa em 40 ms).
      final foldedCount = outputs.takeWhile(
        (e) => (e!.frequencyHz - e2).abs() < 0.01,
      );
      expect(foldedCount.length, 15); // 40..600 exclusivo de 640
      expect(outputs.last!.frequencyHz, closeTo(e2 * 2, 1e-9));
    });

    test('uma estimativa na oitava certa cancela a confirmação', () {
      final g = newGuard()..process(est(e2), Duration.zero);
      for (var t = 40; t <= 520; t += 40) {
        g.process(est(e2 * 2), ms(t));
      }
      g.process(est(e2), ms(560));
      for (var t = 600; t <= 1000; t += 40) {
        expect(g.process(est(e2 * 2), ms(t))!.frequencyHz, closeTo(e2, 1e-9));
      }
    });

    test('intervalos que não são oitava passam intactos (cordas vizinhas)', () {
      final g = newGuard()..process(est(e2), Duration.zero);
      // D3 está a 1000 cents de E2; B3 a 1900; E4 a 2400 (2 oitavas).
      for (final hz in [146.83, 246.94, 329.63]) {
        g.reset();
        g.process(est(e2), Duration.zero);
        expect(g.process(est(hz), ms(40))!.frequencyHz, hz);
      }
    });

    test('fora da tolerância (oitava ± 60 cents) não é dobrada', () {
      final g = newGuard()..process(est(e2), Duration.zero);
      const hz = e2 * 2 * 1.0353; // +60 cents
      expect(g.process(est(hz), ms(40))!.frequencyHz, hz);
    });

    test('LIMITAÇÃO: sem histórico, a primeira detecção errada é aceita', () {
      final g = newGuard();
      expect(g.process(est(e2 * 2), Duration.zero)!.frequencyHz, e2 * 2);
    });

    test('referência expira após memory sem estimativas', () {
      final g = newGuard()..process(est(e2), Duration.zero);
      expect(g.process(null, ms(1000)), isNull);
      expect(g.process(est(e2 * 2), ms(2100))!.frequencyHz, e2 * 2);
    });
  });

  group('StabilityGate', () {
    for (final window in [3, 5]) {
      test('janela $window: primeira saída após $window estimativas', () {
        final g = StabilityGate(windowSize: window, toleranceCents: 20);
        final out = [for (var i = 0; i < 8; i++) g.process(est(110), ms(i))];
        expect(out.indexWhere((e) => e != null), window - 1);
        expect(out.skip(window - 1), everyElement(isNotNull));
      });

      test('janela $window: outlier bloqueia por $window frames', () {
        final g = StabilityGate(windowSize: window, toleranceCents: 20);
        for (var i = 0; i < 10; i++) {
          g.process(est(110), ms(i));
        }
        final out = [
          g.process(est(110 * 1.05), ms(10)), // ~+84 cents
          for (var i = 11; i < 20; i++) g.process(est(110), ms(i)),
        ];
        expect(out.takeWhile((e) => e == null).length, window);
        expect(out.skip(window), everyElement(isNotNull));
      });
    }

    test('dispersão no limite passa; acima bloqueia', () {
      final g = StabilityGate(windowSize: 3, toleranceCents: 20);
      final up = frequencyFromMidi(45.2); // A2 +20 cents
      g
        ..process(est(110), Duration.zero)
        ..process(est(up), Duration.zero);
      expect(g.process(est(110), Duration.zero), isNotNull);
      expect(g.process(est(frequencyFromMidi(45.21)), Duration.zero), isNull);
    });

    test('null esvazia a janela', () {
      final g = StabilityGate(windowSize: 3, toleranceCents: 20);
      for (var i = 0; i < 5; i++) {
        g.process(est(110), Duration.zero);
      }
      g.process(null, Duration.zero);
      expect(g.process(est(110), Duration.zero), isNull);
      expect(g.process(est(110), Duration.zero), isNull);
      expect(g.process(est(110), Duration.zero), isNotNull);
    });
  });

  group('PitchSmoother', () {
    PitchSmoother newSmoother() => PitchSmoother(
      minCutoffHz: 0.6,
      beta: 0.06,
      derivativeCutoffHz: 1,
      newNoteThresholdCents: 250,
      resetGap: ms(300),
    );

    test('salto > 250 cents reinicia: sem deslizar até a nova nota', () {
      final s = newSmoother();
      for (var t = 0; t < 400; t += 40) {
        s.process(est(82.41), ms(t));
      }
      final jumped = s.process(est(110), ms(400)); // +500 cents
      expect(jumped!.frequencyHz, closeTo(110, 1e-9));
    });

    test('salto < 250 cents é suavizado', () {
      final s = newSmoother();
      for (var t = 0; t < 400; t += 40) {
        s.process(est(110), ms(t));
      }
      final moved = s.process(est(frequencyFromMidi(45.4)), ms(400));
      expect(cents(moved, 110), inExclusiveRange(0, 39));
    });

    test('limiar de nova nota é configurável', () {
      final s = PitchSmoother(
        minCutoffHz: 0.6,
        beta: 0.06,
        derivativeCutoffHz: 1,
        newNoteThresholdCents: 30,
        resetGap: ms(300),
      )..process(est(110), Duration.zero);
      final moved = s.process(est(frequencyFromMidi(45.4)), ms(40));
      expect(cents(moved, 110), closeTo(40, 1e-6));
    });

    test('intervalo maior que resetGap recomeça sem suavizar', () {
      final s = newSmoother()..process(est(110), Duration.zero);
      final after = s.process(est(frequencyFromMidi(45.1)), ms(400));
      expect(cents(after, 110), closeTo(10, 1e-6));
    });

    test('preserva a confiança da estimativa', () {
      final s = newSmoother();
      expect(s.process(est(110, 0.93), Duration.zero)!.confidence, 0.93);
    });
  });
}
