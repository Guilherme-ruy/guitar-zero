import 'package:flutter_test/flutter_test.dart';
import 'package:guitar_zero/core/music/pitch_math.dart';
import 'package:guitar_zero/core/music/string_tracker.dart';
import 'package:guitar_zero/core/music/tuning.dart';

void main() {
  StringTracker newTracker() => StringTracker(
    tuning: Tuning.standard,
    switchMarginCents: 30,
    maxDeviationCents: 350,
  );
  // E2 = MIDI 40, A2 = MIDI 45: ponto médio a +250 cents de E2.
  double fromE2(double cents) => frequencyFromMidi(40 + cents / 100);
  String name(StringTracker t, double cents) =>
      t.match(fromE2(cents))!.string.note.toString();

  test('sem corda ativa, escolhe a mais próxima', () {
    expect(name(newTracker(), 240), 'E2');
    expect(name(newTracker(), 260), 'A2');
  });

  test('vindo de E2: só troca para A2 com 30 cents de vantagem (≥ 265)', () {
    final t = newTracker();
    expect(name(t, 0), 'E2');
    for (final c in const [240.0, 250.0, 255.0, 260.0, 264.0]) {
      expect(name(t, c), 'E2', reason: '$c cents');
    }
    expect(name(t, 266), 'A2');
  });

  test('vindo de A2: só volta para E2 com 30 cents de vantagem (≤ 235)', () {
    final t = newTracker();
    expect(name(t, 500), 'A2');
    for (final c in const [260.0, 250.0, 245.0, 240.0, 236.0]) {
      expect(name(t, c), 'A2', reason: '$c cents');
    }
    expect(name(t, 234), 'E2');
  });

  test('oscilação na zona intermediária não pisca', () {
    final t = newTracker()..match(fromE2(0));
    final names = [for (var i = 0; i < 40; i++) name(t, i.isEven ? 240 : 262)];
    expect(names.toSet(), {'E2'});
  });

  test('cents são relativos à corda ativa, não à mais próxima', () {
    final t = newTracker()..match(fromE2(0));
    final m = t.match(fromE2(255))!;
    expect(m.string.note.toString(), 'E2');
    expect(m.cents, closeTo(255, 1e-6));
  });

  test('reset remove a histerese', () {
    final t = newTracker()..match(fromE2(0));
    expect(name(t, 260), 'E2');
    t.reset();
    expect(name(t, 260), 'A2');
  });

  test('frequência sem corda próxima retorna null', () {
    expect(newTracker().match(40), isNull);
  });
}
