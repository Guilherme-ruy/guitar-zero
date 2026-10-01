import 'dart:math' as math;
import 'dart:typed_data';

/// FFT complexa radix-2 (Cooley–Tukey iterativa, decimação no tempo), in
/// place. Implementação própria.
///
/// Tabelas de twiddles e de bit-reversal são calculadas uma vez por tamanho;
/// [transform] não aloca. Custo O(N log N).
class Fft {
  Fft(this.size)
    : assert(size >= 2 && (size & (size - 1)) == 0, 'size deve ser 2^k'),
      _cos = Float64List(size ~/ 2),
      _sin = Float64List(size ~/ 2),
      _reversed = Int32List(size) {
    for (var i = 0; i < size ~/ 2; i++) {
      final angle = -2 * math.pi * i / size;
      _cos[i] = math.cos(angle);
      _sin[i] = math.sin(angle);
    }
    final bits = size.bitLength - 1;
    for (var i = 0; i < size; i++) {
      var r = 0;
      for (var b = 0; b < bits; b++) {
        r |= ((i >> b) & 1) << (bits - 1 - b);
      }
      _reversed[i] = r;
    }
  }

  final int size;
  final Float64List _cos;
  final Float64List _sin;
  final Int32List _reversed;

  /// Transformada direta `X[k] = Σ x[n]·e^(−2πikn/N)` sobre [re] e [im].
  void transform(Float64List re, Float64List im) {
    assert(re.length == size && im.length == size);
    for (var i = 0; i < size; i++) {
      final j = _reversed[i];
      if (j > i) {
        final tr = re[i];
        re[i] = re[j];
        re[j] = tr;
        final ti = im[i];
        im[i] = im[j];
        im[j] = ti;
      }
    }
    for (var half = 1; half < size; half <<= 1) {
      final step = size ~/ (half << 1);
      for (var start = 0; start < size; start += half << 1) {
        for (var k = 0; k < half; k++) {
          final wr = _cos[k * step];
          final wi = _sin[k * step];
          final a = start + k;
          final b = a + half;
          final xr = re[b] * wr - im[b] * wi;
          final xi = re[b] * wi + im[b] * wr;
          re[b] = re[a] - xr;
          im[b] = im[a] - xi;
          re[a] += xr;
          im[a] += xi;
        }
      }
    }
  }
}
