import 'dart:math' as math;
import 'dart:typed_data';

import 'fft.dart';

/// Espectro de potência de um frame (janela Hann periódica + FFT radix-2),
/// com utilitários para localizar e medir picos.
///
/// O tamanho da FFT é a maior potência de 2 que cabe no frame; as amostras
/// iniciais são usadas. Buffers são reaproveitados entre chamadas.
class Spectrum {
  Fft? _fft;
  Float64List _window = Float64List(0);
  Float64List _re = Float64List(0);
  Float64List _im = Float64List(0);
  Float64List _power = Float64List(0);
  int _sampleRate = 0;

  int get fftSize => _fft?.size ?? 0;

  /// Resolução em Hz por bin.
  double get binHz => _sampleRate / fftSize;

  /// Número de bins úteis (0..N/2).
  int get binCount => fftSize ~/ 2 + 1;

  /// Potência `|X[k]|²` (sem normalização absoluta; só razões importam).
  double power(int bin) => _power[bin];

  /// Maior potência de 2 ≤ [length].
  static int fftSizeFor(int length) =>
      length < 2 ? 0 : 1 << (length.bitLength - 1);

  /// Calcula o espectro de [samples] (DC removido antes da janela).
  void compute(Float32List samples, int sampleRate) {
    final n = fftSizeFor(samples.length);
    if (n != fftSize) _resize(n);
    _sampleRate = sampleRate;

    var mean = 0.0;
    for (var i = 0; i < n; i++) {
      mean += samples[i];
    }
    mean /= n;
    for (var i = 0; i < n; i++) {
      _re[i] = (samples[i] - mean) * _window[i];
      _im[i] = 0;
    }
    _fft!.transform(_re, _im);
    for (var k = 0; k < binCount; k++) {
      _power[k] = _re[k] * _re[k] + _im[k] * _im[k];
    }
  }

  void _resize(int n) {
    _fft = Fft(n);
    _window = Float64List(n);
    for (var i = 0; i < n; i++) {
      // Hann periódica: torna exato o estimador de [interpolatedBin].
      _window[i] = 0.5 * (1 - math.cos(2 * math.pi * i / n));
    }
    _re = Float64List(n);
    _im = Float64List(n);
    _power = Float64List(n ~/ 2 + 1);
  }

  /// Bin de maior potência que é máximo local dentro de
  /// [center − halfWidth, center + halfWidth], ou −1.
  int localMaximumNear(int center, int halfWidth) {
    var best = -1;
    final lo = math.max(1, center - halfWidth);
    final hi = math.min(binCount - 2, center + halfWidth);
    for (var k = lo; k <= hi; k++) {
      final p = _power[k];
      if (p >= _power[k - 1] &&
          p >= _power[k + 1] &&
          (best < 0 || p > _power[best])) {
        best = k;
      }
    }
    return best;
  }

  /// Posição fracionária do pico em [bin] pelo estimador de razão de
  /// amplitudes para janela Hann (Grandke, 1983):
  /// `δ = (2α − 1)/(α + 1)`, `α = |X[k±1]| / |X[k]|` do lado do maior
  /// vizinho. Exato para uma senoide isolada.
  double interpolatedBin(int bin) {
    final center = math.sqrt(_power[bin]);
    if (center == 0) return bin.toDouble();
    final left = math.sqrt(_power[bin - 1]);
    final right = math.sqrt(_power[bin + 1]);
    final rightSide = right >= left;
    final alpha = (rightSide ? right : left) / center;
    final delta = ((2 * alpha - 1) / (alpha + 1)).clamp(0.0, 1.0);
    return rightSide ? bin + delta : bin - delta;
  }

  /// Soma de potência em [center − halfWidth, center + halfWidth].
  double bandPower(int center, int halfWidth) {
    var sum = 0.0;
    final lo = math.max(0, center - halfWidth);
    final hi = math.min(binCount - 1, center + halfWidth);
    for (var k = lo; k <= hi; k++) {
      sum += _power[k];
    }
    return sum;
  }

  /// Mediana da potência em [center − radius, center + radius], ignorando
  /// [exclude] ± 2 bins (o próprio pico e seu lóbulo principal).
  double medianPower(int center, int radius, int exclude) {
    final values = <double>[];
    final lo = math.max(1, center - radius);
    final hi = math.min(binCount - 1, center + radius);
    for (var k = lo; k <= hi; k++) {
      if ((k - exclude).abs() > 2) values.add(_power[k]);
    }
    if (values.isEmpty) return 0;
    values.sort();
    return values[values.length ~/ 2];
  }
}
