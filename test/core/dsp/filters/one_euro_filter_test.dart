import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:guitar_zero/core/dsp/filters/one_euro_filter.dart';

import '../../../support/synthetic_signals.dart';

OneEuroFilter newFilter({double beta = 0.06}) =>
    OneEuroFilter(minCutoffHz: 0.6, beta: beta, derivativeCutoffHz: 1);

void main() {
  const dt = 0.04;

  test('primeira amostra passa sem alteração', () {
    expect(newFilter().filter(123.4, dt), 123.4);
  });

  test('entrada constante permanece constante', () {
    final f = newFilter();
    for (var i = 0; i < 50; i++) {
      expect(f.filter(-12.5, dt), closeTo(-12.5, 1e-12));
    }
  });

  test('beta = 0 é suavização exponencial com α = 1/(1 + τ/Te)', () {
    final f = newFilter(beta: 0)..filter(0, dt);
    const tau = 1 / (2 * math.pi * 0.6);
    const alpha = 1 / (1 + tau / dt);
    expect(f.filter(10, dt), closeTo(alpha * 10, 1e-12));
  });

  test(
    'nota estável com jitter: saída varia menos que a entrada, sem viés',
    () {
      final f = newFilter();
      final rng = Xorshift32(4);
      final outputs = <double>[];
      for (var i = 0; i < 300; i++) {
        final y = f.filter(3 * rng.nextSigned(), dt);
        if (i >= 25) outputs.add(y);
      }
      final p2p = outputs.reduce(math.max) - outputs.reduce(math.min);
      final mean = outputs.reduce((a, b) => a + b) / outputs.length;
      expect(p2p, lessThan(6));
      expect(mean.abs(), lessThan(0.5));
    },
  );

  test('beta maior responde mais rápido a movimento', () {
    double lagAfterRamp(double beta) {
      final f = newFilter(beta: beta);
      var y = 0.0;
      for (var i = 0; i <= 25; i++) {
        y = f.filter(i * 4.0, dt); // 100 cents/s
      }
      return 100 - y;
    }

    expect(lagAfterRamp(0.06), lessThan(lagAfterRamp(0)));
  });

  test('dt real: amostragem irregular converge para o mesmo valor', () {
    final regular = newFilter();
    final irregular = newFilter();
    regular.filter(0, dt);
    irregular.filter(0, dt);
    var yr = 0.0;
    var yi = 0.0;
    for (var i = 0; i < 40; i++) {
      yr = regular.filter(20, 0.04);
      yi = irregular.filter(20, i.isEven ? 0.02 : 0.06);
    }
    expect(yr, closeTo(20, 0.01));
    expect(yi, closeTo(20, 0.01));
  });

  test('dt maior suaviza menos (mais tempo decorrido)', () {
    final short = newFilter(beta: 0)..filter(0, dt);
    final long = newFilter(beta: 0)..filter(0, dt);
    expect(long.filter(10, 0.2), greaterThan(short.filter(10, 0.02)));
  });

  test('reset descarta o estado', () {
    final f = newFilter()
      ..filter(0, dt)
      ..filter(50, dt)
      ..reset();
    expect(f.value, isNull);
    expect(f.filter(7, dt), 7);
  });
}
