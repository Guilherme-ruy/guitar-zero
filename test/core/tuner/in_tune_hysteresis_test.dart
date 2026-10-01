import 'package:flutter_test/flutter_test.dart';
import 'package:guitar_zero/core/music/tuning.dart';
import 'package:guitar_zero/core/tuner/in_tune_hysteresis.dart';

void main() {
  final a2 = Tuning.standard.strings[1];
  final d3 = Tuning.standard.strings[2];
  InTuneHysteresis newH() => InTuneHysteresis(enterCents: 3, leaveCents: 6);

  test('entra em ≤ 3 e sai só acima de 6', () {
    final h = newH();
    expect(h.update(a2, 4), isFalse);
    expect(h.update(a2, 3), isTrue);
    expect(h.update(a2, 5.9), isTrue);
    expect(h.update(a2, -6), isTrue);
    expect(h.update(a2, 6.1), isFalse);
    expect(h.update(a2, 4), isFalse);
  });

  test('sem flicker com leitura oscilando em torno de 3 cents', () {
    final h = newH();
    final states = [
      for (var i = 0; i < 50; i++) h.update(a2, i.isEven ? 2.8 : 3.4),
    ];
    expect(states.first, isTrue);
    expect(states.toSet(), {true});
  });

  test('sem flicker com leitura oscilando em torno de 6 cents fora', () {
    final h = newH();
    final states = [
      for (var i = 0; i < 50; i++) h.update(a2, i.isEven ? 5.7 : 6.3),
    ];
    expect(states.toSet(), {false});
  });

  test('trocar de corda exige entrar de novo pelo limite estrito', () {
    final h = newH()..update(a2, 0);
    expect(h.update(d3, 5), isFalse);
  });
}
