import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:guitar_zero/core/dsp/spectral/fft.dart';

import '../../../support/synthetic_signals.dart';

/// DFT direta O(N²), referência para validar a FFT.
(Float64List, Float64List) naiveDft(Float64List re, Float64List im) {
  final n = re.length;
  final outRe = Float64List(n);
  final outIm = Float64List(n);
  for (var k = 0; k < n; k++) {
    for (var t = 0; t < n; t++) {
      final a = -2 * math.pi * k * t / n;
      outRe[k] += re[t] * math.cos(a) - im[t] * math.sin(a);
      outIm[k] += re[t] * math.sin(a) + im[t] * math.cos(a);
    }
  }
  return (outRe, outIm);
}

void main() {
  for (final n in [2, 8, 64, 512]) {
    test('igual à DFT direta (N = $n, entrada complexa aleatória)', () {
      final rng = Xorshift32(n);
      final re = Float64List.fromList([
        for (var i = 0; i < n; i++) rng.nextSigned(),
      ]);
      final im = Float64List.fromList([
        for (var i = 0; i < n; i++) rng.nextSigned(),
      ]);
      final (expRe, expIm) = naiveDft(re, im);
      Fft(n).transform(re, im);
      for (var k = 0; k < n; k++) {
        expect(re[k], closeTo(expRe[k], 1e-9));
        expect(im[k], closeTo(expIm[k], 1e-9));
      }
    });
  }

  test('impulso → espectro plano', () {
    final re = Float64List(16)..[0] = 1;
    final im = Float64List(16);
    Fft(16).transform(re, im);
    for (var k = 0; k < 16; k++) {
      expect(re[k], closeTo(1, 1e-12));
      expect(im[k], closeTo(0, 1e-12));
    }
  });

  test('cosseno no bin 5 → energia só nos bins 5 e N−5', () {
    const n = 64;
    final re = Float64List.fromList([
      for (var i = 0; i < n; i++) math.cos(2 * math.pi * 5 * i / n),
    ]);
    final im = Float64List(n);
    Fft(n).transform(re, im);
    for (var k = 0; k < n; k++) {
      final mag = math.sqrt(re[k] * re[k] + im[k] * im[k]);
      expect(mag, closeTo(k == 5 || k == n - 5 ? n / 2 : 0, 1e-9));
    }
  });

  test('Parseval: Σ|x|² = Σ|X|²/N (N = 4096)', () {
    const n = 4096;
    final rng = Xorshift32(7);
    final re = Float64List.fromList([
      for (var i = 0; i < n; i++) rng.nextSigned(),
    ]);
    final im = Float64List(n);
    final timeEnergy = re.fold<double>(0, (s, v) => s + v * v);
    Fft(n).transform(re, im);
    var freqEnergy = 0.0;
    for (var k = 0; k < n; k++) {
      freqEnergy += re[k] * re[k] + im[k] * im[k];
    }
    expect(freqEnergy / n, closeTo(timeEnergy, 1e-6 * timeEnergy));
  });

  test('tamanho que não é potência de 2 é rejeitado', () {
    expect(() => Fft(100), throwsA(isA<AssertionError>()));
  });
}
