import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:guitar_zero/core/dsp/spectral/spectrum.dart';

void main() {
  test('tamanho da FFT: maior potência de 2 que cabe no frame', () {
    expect(Spectrum.fftSizeFor(4096), 4096);
    expect(Spectrum.fftSizeFor(8191), 4096);
    expect(Spectrum.fftSizeFor(1602), 1024);
    expect(Spectrum.fftSizeFor(1), 0);
  });

  group('interpolação (estimador para Hann)', () {
    const n = 4096;
    const sampleRate = 48000;
    final spectrum = Spectrum();

    for (final fraction in [0.0, 0.13, 0.25, 0.5, 0.71, 0.9]) {
      test('senoide no bin 37 + $fraction: erro < 0.005 bin', () {
        final bin = 37 + fraction;
        final hz = bin * sampleRate / n;
        final samples = Float32List.fromList([
          for (var i = 0; i < n; i++)
            0.5 * math.sin(2 * math.pi * hz * i / sampleRate + 0.3),
        ]);
        spectrum.compute(samples, sampleRate);
        final peak = spectrum.localMaximumNear(37, 2);
        expect(spectrum.interpolatedBin(peak), closeTo(bin, 0.005));
      });
    }
  });

  test('DC é removido antes da janela', () {
    final samples = Float32List(1024)..fillRange(0, 1024, 0.7);
    final spectrum = Spectrum()..compute(samples, 48000);
    for (var k = 0; k < spectrum.binCount; k++) {
      expect(spectrum.power(k), closeTo(0, 1e-12));
    }
  });
}
