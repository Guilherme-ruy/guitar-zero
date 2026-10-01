// Benchmark aproximado do DSP por frame. Não roda no CI.
//
// Uso (JIT):  dart run tool/dsp_benchmark.dart
// Uso (AOT, mais próximo do app em release):
//   dart compile exe tool/dsp_benchmark.dart -o /tmp/dsp_bench && /tmp/dsp_bench
import 'dart:io';

import 'package:guitar_zero/core/dsp/harmonic_pitch_detector.dart';
import 'package:guitar_zero/core/dsp/spectral/harmonic_analyzer.dart';
import 'package:guitar_zero/core/dsp/yin_pitch_detector.dart';

import '../test/support/synthetic_signals.dart';

const warmup = 50;
const iterations = 300;

({double mean, int p95}) measure(void Function() body) {
  for (var i = 0; i < warmup; i++) {
    body();
  }
  final times = <int>[];
  for (var i = 0; i < iterations; i++) {
    final sw = Stopwatch()..start();
    body();
    times.add(sw.elapsedMicroseconds);
  }
  times.sort();
  return (
    mean: times.reduce((a, b) => a + b) / times.length,
    p95: times[(times.length * 0.95).floor()],
  );
}

String ms(num us) => (us / 1000).toStringAsFixed(2).padLeft(6);

void main() {
  final yin = YinPitchDetector();
  final analyzer = HarmonicAnalyzer();
  final full = HarmonicPitchDetector();
  var sink = 0.0;

  stdout.writeln(
    'config        YIN média/p95     espectral média/p95   total média/p95   '
    '% hop 40 ms',
  );
  for (final sampleRate in [44100, 48000]) {
    for (final frameSize in [4096, 8192]) {
      final frame = SyntheticSignals.frame(
        SyntheticSignals.tone(
          frequencyHz: 110,
          sampleRate: sampleRate,
          length: frameSize,
          harmonics: const [1, 0.6, 0.4, 0.25, 0.15],
        ),
        sampleRate,
      );
      final y = measure(() => sink += yin.detect(frame)!.frequencyHz);
      final s = measure(
        () => sink += analyzer.analyze(frame, 110)!.harmonicity,
      );
      final t = measure(() => sink += full.detect(frame)!.frequencyHz);
      stdout.writeln(
        '$sampleRate/$frameSize  ${ms(y.mean)} /${ms(y.p95)} ms   '
        '${ms(s.mean)} /${ms(s.p95)} ms     ${ms(t.mean)} /${ms(t.p95)} ms   '
        '${(t.mean / 40000 * 100).toStringAsFixed(1).padLeft(5)} %',
      );
    }
  }
  // Mantém o resultado vivo para o compilador não eliminar o trabalho.
  stdout.writeln('(checksum ${sink.toStringAsFixed(0)})');
}
