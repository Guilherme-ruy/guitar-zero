import 'package:flutter_test/flutter_test.dart';
import 'package:guitar_zero/core/music/pitch_math.dart';
import 'package:guitar_zero/core/music/string_matcher.dart';
import 'package:guitar_zero/core/music/tuning.dart';

void main() {
  const matcher = StringMatcher(tuning: Tuning.standard);

  test('frequência exata casa com a corda e 0 cents', () {
    for (final string in Tuning.standard.strings) {
      final match = matcher.match(string.targetFrequency)!;
      expect(match.string, string);
      expect(match.cents, closeTo(0, 1e-9));
    }
  });

  test('desvios pequenos mantêm a corda e o sinal correto', () {
    final low = matcher.match(frequencyFromMidi(45 - 0.2))!; // A2 -20 cents
    expect(low.string.note.toString(), 'A2');
    expect(low.cents, closeTo(-20, 1e-6));

    final high = matcher.match(frequencyFromMidi(64 + 0.3))!; // E4 +30 cents
    expect(high.string.note.toString(), 'E4');
    expect(high.cents, closeTo(30, 1e-6));
  });

  test('escolhe a corda mais próxima em escala logarítmica', () {
    // Entre G3 (55) e B3 (59): 56.9 está mais perto de G3, 57.1 de B3.
    expect(
      matcher.match(frequencyFromMidi(56.9))!.string.note.toString(),
      'G3',
    );
    expect(
      matcher.match(frequencyFromMidi(57.1))!.string.note.toString(),
      'B3',
    );
  });

  test('rejeita frequências fora do alcance do instrumento', () {
    expect(matcher.match(40), isNull);
    expect(matcher.match(1000), isNull);
    expect(matcher.match(0), isNull);
    expect(matcher.match(double.nan), isNull);
  });
}
