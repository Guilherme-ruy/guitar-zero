// Benchmark aproximado do YinPitchDetector. Não roda no CI.
//
// Uso (JIT):  dart run tool/yin_benchmark.dart
// Uso (AOT, mais próximo do app em release):
//   dart compile exe tool/yin_benchmark.dart -o /tmp/yin_bench && /tmp/yin_bench
import 'dart:io';

import 'package:guitar_zero/core/dsp/yin_pitch_detector.dart';

import '../test/support/synthetic_signals.dart';

void main() {
  const warmup = 50;
  const iterations = 300;
  final detector = YinPitchDetector();
  var sink = 0.0;

  stdout.writeln('config        lags   janela W   média     p95       budget*');
  for (final sampleRate in [44100, 48000]) {
    for (final frameSize in [4096, 8192]) {
      final frame = SyntheticSignals.frame(
        SyntheticSignals.tone(
          frequencyHz: 110,
          sampleRate: sampleRate,
          length: frameSize,
          harmonics: const [1, 0.6, 0.4, 0.25],
        ),
        sampleRate,
      );
      for (var i = 0; i < warmup; i++) {
        sink += detector.detect(frame)!.frequencyHz;
      }
      final times = <int>[];
      for (var i = 0; i < iterations; i++) {
        final sw = Stopwatch()..start();
        sink += detector.detect(frame)!.frequencyHz;
        times.add(sw.elapsedMicroseconds);
      }
      times.sort();
      final mean = times.reduce((a, b) => a + b) / times.length;
      final p95 = times[(times.length * 0.95).floor()];
      final maxLag = detector.config.maxLag(sampleRate) + 1;
      final window = frameSize - maxLag;
      // Fração de um hop de 40 ms consumida por frame.
      final budget = mean / 40000 * 100;
      stdout.writeln(
        '$sampleRate/$frameSize  ${maxLag.toString().padLeft(4)}   '
        '${window.toString().padLeft(6)}   '
        '${(mean / 1000).toStringAsFixed(2).padLeft(6)} ms '
        '${(p95 / 1000).toStringAsFixed(2).padLeft(6)} ms  '
        '${budget.toStringAsFixed(1).padLeft(5)} %',
      );
    }
  }
  stdout.writeln(
    '* média / hop de 40 ms. (checksum ${sink.toStringAsFixed(0)})',
  );
}
