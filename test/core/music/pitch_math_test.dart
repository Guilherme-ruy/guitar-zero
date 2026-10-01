import 'package:flutter_test/flutter_test.dart';
import 'package:guitar_zero/core/music/note.dart';
import 'package:guitar_zero/core/music/pitch_math.dart';
import 'package:guitar_zero/core/music/tuning.dart';

void main() {
  group('pitch math', () {
    test('cents: oitava = 1200, semitom = 100, igualdade = 0', () {
      expect(centsBetween(880, 440), closeTo(1200, 1e-9));
      expect(centsBetween(440, 880), closeTo(-1200, 1e-9));
      expect(centsBetween(frequencyFromMidi(70), 440), closeTo(100, 1e-9));
      expect(centsBetween(440, 440), 0);
    });

    test('midi <-> frequência', () {
      expect(frequencyFromMidi(69), 440);
      expect(midiFromFrequency(440), closeTo(69, 1e-12));
      expect(midiFromFrequency(frequencyFromMidi(40)), closeTo(40, 1e-12));
    });

    test('nomes e oitavas das notas', () {
      expect(const Note(40).toString(), 'E2');
      expect(const Note(60).toString(), 'C4');
      expect(const Note(69).toString(), 'A4');
      expect(const Note(61).name, 'C#');
    });
  });

  test('afinação Standard tem as frequências de referência', () {
    final expected = [82.41, 110.00, 146.83, 196.00, 246.94, 329.63];
    final strings = Tuning.standard.strings;
    expect(strings.map((s) => s.note.toString()), [
      'E2',
      'A2',
      'D3',
      'G3',
      'B3',
      'E4',
    ]);
    expect(strings.map((s) => s.number), [6, 5, 4, 3, 2, 1]);
    for (var i = 0; i < strings.length; i++) {
      expect(strings[i].targetFrequency, closeTo(expected[i], 0.005));
    }
  });

  test('nomes em solfejo', () {
    expect(Tuning.standard.strings.map((s) => s.note.solfegeName), [
      'Mi',
      'Lá',
      'Ré',
      'Sol',
      'Si',
      'Mi',
    ]);
    expect(const Note(61).solfegeName, 'Dó#');
  });

  test('cents dobrados por oitava ficam em (−600, 600]', () {
    expect(octaveFoldedCents(330, 82.5), closeTo(0, 1e-9));
    expect(octaveFoldedCents(440 * 1.5, 440), closeTo(-498.04, 0.01));
    expect(octaveFoldedCents(frequencyFromMidi(75), 440), 600);
    expect(octaveFoldedCents(frequencyFromMidi(63), 440), 600);
  });
}
