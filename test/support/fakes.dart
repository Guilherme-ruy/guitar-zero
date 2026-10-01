import 'dart:async';
import 'dart:typed_data';

import 'package:guitar_zero/core/audio/audio_frame.dart';
import 'package:guitar_zero/core/audio/audio_input.dart';
import 'package:guitar_zero/core/dsp/pitch_detector.dart';
import 'package:guitar_zero/core/dsp/pitch_estimate.dart';
import 'package:guitar_zero/core/music/guitar_string.dart';
import 'package:guitar_zero/core/tuner/tuner_config.dart';
import 'package:guitar_zero/core/tuner/tuner_diagnostics.dart';
import 'package:guitar_zero/core/tuner/tuner_engine.dart';
import 'package:guitar_zero/core/tuner/tuner_reading.dart';

class FakeAudioInput implements AudioInput {
  final StreamController<AudioFrame> _frames =
      StreamController<AudioFrame>.broadcast(sync: true);
  AudioInputException? failOnStart;
  bool running = false;

  @override
  Stream<AudioFrame> get frames => _frames.stream;

  void fail(Object error) => _frames.addError(error);

  /// Simula o fim inesperado da captura.
  Future<void> end() => _frames.close();

  void emit([AudioFrame? frame]) => _frames.add(
    frame ??
        AudioFrame(
          samples: Float32List(1024),
          sampleRate: 48000,
          timestamp: Duration.zero,
        ),
  );

  @override
  Future<void> start() async {
    if (failOnStart != null) throw failOnStart!;
    running = true;
  }

  @override
  Future<void> stop() async => running = false;

  @override
  Future<void> dispose() => _frames.close();
}

/// Detector que devolve, em ordem, as estimativas programadas.
class ScriptedPitchDetector implements PitchDetector {
  ScriptedPitchDetector(this.script);

  final List<PitchEstimate?> script;
  int _index = 0;
  int resets = 0;

  @override
  PitchEstimate? detect(AudioFrame frame) => script[_index++];

  @override
  void reset() => resets++;
}

class FakeTunerEngine implements TunerEngine {
  final StreamController<TunerReading?> _readings =
      StreamController<TunerReading?>.broadcast(sync: true);
  AudioInputException? failOnStart;

  @override
  TunerConfig get config => const TunerConfig();

  @override
  Stream<TunerReading?> get readings => _readings.stream;

  @override
  Stream<TunerDiagnostics> get diagnostics => const Stream.empty();

  void emit(TunerReading? reading) => _readings.add(reading);

  void fail(Object error) => _readings.addError(error);

  /// Último alvo recebido (modo manual) — `null` no automático.
  GuitarString? target;

  @override
  void setTargetString(GuitarString? string) => target = string;

  @override
  Future<void> start() async {
    if (failOnStart != null) throw failOnStart!;
  }

  @override
  Future<void> stop() async {}

  @override
  Future<void> dispose() => _readings.close();
}
