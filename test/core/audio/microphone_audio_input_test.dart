import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:guitar_zero/core/audio/audio_frame.dart';
import 'package:guitar_zero/core/audio/audio_input.dart';
import 'package:guitar_zero/core/audio/microphone_audio_input.dart';

class FakeRecorder implements PcmRecorder {
  bool permission = true;
  Object? startError;
  // Fechado pelo próprio teste quando relevante; o GC cuida do resto.
  // ignore: close_sinks
  final StreamController<Uint8List> pcm = StreamController<Uint8List>();
  int? startedAt;
  int stops = 0;
  bool disposed = false;

  @override
  Future<bool> requestPermission() async => permission;

  @override
  Future<Stream<Uint8List>> startPcm16Stream(int sampleRate) async {
    if (startError != null) throw startError!;
    startedAt = sampleRate;
    return pcm.stream;
  }

  @override
  Future<void> stop() async => stops++;

  @override
  Future<void> dispose() async => disposed = true;
}

void main() {
  const config = AudioCaptureConfig(sampleRate: 1000, frameSize: 100);

  test('entrega frames do tamanho configurado com hop e timestamps', () async {
    final recorder = FakeRecorder();
    final input = MicrophoneAudioInput(recorder: recorder, config: config);
    final frames = <AudioFrame>[];
    input.frames.listen(frames.add);
    await input.start();
    expect(recorder.startedAt, 1000);

    recorder.pcm.add(Uint8List(2 * 180)); // 180 amostras
    await pumpEventQueue();
    expect(frames.map((f) => f.timestamp.inMilliseconds), [100, 140, 180]);
    expect(frames.every((f) => f.samples.length == 100), isTrue);
    await input.dispose();
    expect(recorder.disposed, isTrue);
  });

  test('permissão negada → AudioInputException(permissionDenied)', () async {
    final input = MicrophoneAudioInput(
      recorder: FakeRecorder()..permission = false,
      config: config,
    );
    await expectLater(
      input.start(),
      throwsA(
        isA<AudioInputException>().having(
          (e) => e.failure,
          'failure',
          AudioInputFailure.permissionDenied,
        ),
      ),
    );
  });

  test('falha do gravador → AudioInputException(unavailable)', () async {
    final input = MicrophoneAudioInput(
      recorder: FakeRecorder()..startError = StateError('mic ocupado'),
      config: config,
    );
    await expectLater(
      input.start(),
      throwsA(
        isA<AudioInputException>().having(
          (e) => e.failure,
          'failure',
          AudioInputFailure.unavailable,
        ),
      ),
    );
  });

  test('stop para o gravador e reinicia o relógio dos frames', () async {
    final recorder = FakeRecorder();
    final input = MicrophoneAudioInput(recorder: recorder, config: config);
    final frames = <AudioFrame>[];
    input.frames.listen(frames.add);
    await input.start();
    recorder.pcm.add(Uint8List(2 * 150));
    await pumpEventQueue();
    await input.stop();
    expect(recorder.stops, 1);
    expect(frames, hasLength(2));
  });

  test('hop em amostras', () {
    expect(const AudioCaptureConfig().hopSize, 1764); // 40 ms @ 44.1 kHz
  });
}
