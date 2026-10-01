import 'package:flutter_test/flutter_test.dart';
import 'package:guitar_zero/core/music/pitch_math.dart';

import '../support/real_audio.dart';
import '../support/synthetic_signals.dart';

// Cenários com gravações reais misturadas (NSynth, CC BY 4.0): troca de
// corda com a anterior ainda soando e ruído. Limites das medições da fase 4
// (docs/DSP_STRATEGY.md, "Troca de corda e ruído"), com folga.

int midiOf(String note) => int.parse(realFixtures[note]!.split('-')[1]);

void main() {
  final notes = {for (final n in realFixtures.keys) n: loadRealNote(n)};

  group('troca de corda com a anterior ainda soando (nova em 1.5 s)', () {
    for (final (from, to, maxLatencyMs) in [
      ('E2', 'B3', 400), // ×3: aceita pelo ataque (medido 152 ms)
      ('E2', 'A2', 400), // medido 192 ms
      ('D3', 'G3', 400), // quarta; exige o gate combinado (medido 152 ms)
      ('B3', 'E2', 700), // medido 352 ms
      ('E4', 'A2', 400), // medido 192 ms
    ]) {
      test('$from → $to aparece em ≤ $maxLatencyMs ms e nada além das duas '
          'cordas é exibido', () {
        final shown = runRealPipeline(
          mix([
            (samples: notes[from]!, startSeconds: 0, gain: 1),
            (samples: notes[to]!, startSeconds: 1.5, gain: 1),
          ], seconds: 3.5),
        );
        final firstNew = shown.firstWhere(
          (s) => s.ms > 1500 && s.reading.string.note.toString() == to,
        );
        expect(firstNew.ms - 1500, lessThanOrEqualTo(maxLatencyMs));
        for (final s in shown) {
          final name = s.reading.string.note.toString();
          expect({from, to}, contains(name), reason: 't=${s.ms}');
          final target = frequencyFromMidi(midiOf(name));
          expect(
            (centsBetween(s.reading.frequency, target) / 1200).round(),
            0,
            reason: 'oitava errada em t=${s.ms}',
          );
        }
      });
    }
  });

  group('ruído branco', () {
    for (final snr in [20.0, 10.0]) {
      test('SNR $snr dB: todas as cordas aparecem e nunca erradas', () {
        for (final note in realFixtures.keys) {
          final shown = runRealPipeline(
            mix(
              [(samples: notes[note]!, startSeconds: 0, gain: 1)],
              seconds: 3,
              snrDb: snr,
            ),
          );
          expect(shown, isNotEmpty, reason: note);
          final target = frequencyFromMidi(midiOf(note));
          for (final s in shown) {
            expect(s.reading.string.note.toString(), note);
            expect(
              (centsBetween(s.reading.frequency, target) / 1200).round(),
              0,
            );
          }
        }
      });
    }
  });

  group('sinais não tonais pelo pipeline completo (gate combinado)', () {
    test('ruído branco puro nunca gera leitura', () {
      for (var seed = 1; seed <= 5; seed++) {
        final noise = SyntheticSignals.whiteNoise(
          length: 3 * realSampleRate,
          peak: 0.3,
          seed: seed,
        );
        expect(runRealPipeline(noise), isEmpty, reason: 'semente $seed');
      }
    });

    test('parciais inarmônicos nunca geram leitura', () {
      for (final f in [82.41, 110.0, 146.83, 196.0, 246.94, 329.63]) {
        final signal = SyntheticSignals.partials(
          components: [
            (hz: f, amplitude: 1),
            (hz: f * 1.37, amplitude: 0.8),
            (hz: f * 2.21, amplitude: 0.6),
            (hz: f * 3.53, amplitude: 0.5),
          ],
          sampleRate: realSampleRate,
          length: 3 * realSampleRate,
        );
        expect(runRealPipeline(signal), isEmpty, reason: '$f Hz');
      }
    });
  });
}
