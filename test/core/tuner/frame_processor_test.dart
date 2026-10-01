import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:guitar_zero/core/audio/audio_frame.dart';
import 'package:guitar_zero/core/dsp/harmonic_pitch_detector.dart';
import 'package:guitar_zero/core/dsp/pitch_detector.dart';
import 'package:guitar_zero/core/dsp/pitch_estimate.dart';
import 'package:guitar_zero/core/music/pitch_math.dart';
import 'package:guitar_zero/core/tuner/frame_processor.dart';
import 'package:guitar_zero/core/tuner/tuner_reading.dart';

import '../../support/synthetic_signals.dart';

/// 10 frames de A2 −10 cents, 4096 amostras, hop de 40 ms a 48 kHz.
List<AudioFrame> a2Frames() {
  const hop = 1920;
  final signal = SyntheticSignals.tone(
    frequencyHz: frequencyFromMidi(45 - 0.1),
    sampleRate: 48000,
    length: 4096 + hop * 9,
    harmonics: const [1, 0.6, 0.4, 0.25],
  );
  return [
    for (var i = 0; i < 10; i++)
      SyntheticSignals.frame(signal, 48000, offset: i * hop, length: 4096),
  ];
}

Future<List<TunerReading?>> collect(
  FrameProcessor processor,
  int count, {
  required void Function() feed,
}) async {
  final out = <TunerReading?>[];
  final done = Completer<void>();
  final sub = processor.readings.listen((r) {
    out.add(r);
    if (out.length == count && !done.isCompleted) done.complete();
  });
  feed();
  await done.future.timeout(const Duration(seconds: 20));
  await sub.cancel();
  return out;
}

void main() {
  test(
    'isolate produz as mesmas leituras que o processamento inline',
    () async {
      final frames = a2Frames();

      final inline = InlineFrameProcessor(detector: HarmonicPitchDetector());
      final expected = <TunerReading?>[];
      inline.readings.listen(expected.add);
      frames.forEach(inline.process);

      final isolate = IsolateFrameProcessor();
      await isolate.start();
      // Envia um frame por vez, esperando o resultado (sem descarte).
      final got = <TunerReading?>[];
      for (final frame in frames) {
        got.addAll(
          await collect(isolate, 1, feed: () => isolate.process(frame)),
        );
      }
      await isolate.dispose();
      await inline.dispose();

      expect(got.length, expected.length);
      for (var i = 0; i < got.length; i++) {
        expect(got[i]?.cents, expected[i]?.cents);
        expect(got[i]?.string, expected[i]?.string);
      }
      expect(got.last!.cents, closeTo(-10, 0.05));
    },
  );

  test('backpressure: rajada de frames → só processa o atual e o mais '
      'recente', () async {
    final frames = a2Frames();
    final processor = IsolateFrameProcessor();
    await processor.start();
    final out = <TunerReading?>[];
    processor.readings.listen(out.add);
    frames.forEach(processor.process); // 10 de uma vez
    await Future<void>.delayed(const Duration(seconds: 2));
    expect(out, hasLength(2));
    expect(processor.droppedFrames, 8);
    await processor.dispose();
  });

  test('reset descarta resultados atrasados de frames anteriores', () async {
    final frames = a2Frames();
    final processor = IsolateFrameProcessor();
    await processor.start();
    final out = <TunerReading?>[];
    processor.readings.listen(out.add);
    processor
      ..process(frames[0])
      ..reset();
    await Future<void>.delayed(const Duration(seconds: 1));
    expect(out, isEmpty);
    await processor.dispose();
  });

  test('exceção no detector não trava o worker', () async {
    final processor = IsolateFrameProcessor(detectorFactory: _ThrowingOnce.new);
    await processor.start();
    final frames = a2Frames();
    final first = await collect(
      processor,
      1,
      feed: () => processor.process(frames[0]),
    );
    expect(first.single, isNull);
    final second = await collect(
      processor,
      1,
      feed: () => processor.process(frames[1]),
    );
    expect(second, hasLength(1));
    await processor.dispose();
  });
}

/// Lança no primeiro frame e depois funciona normalmente.
class _ThrowingOnce implements PitchDetector {
  final HarmonicPitchDetector _inner = HarmonicPitchDetector();
  bool _thrown = false;

  @override
  PitchEstimate? detect(AudioFrame frame) {
    if (!_thrown) {
      _thrown = true;
      throw StateError('falha simulada');
    }
    return _inner.detect(frame);
  }

  @override
  void reset() => _inner.reset();
}
