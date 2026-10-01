import 'dart:async';

import '../audio/audio_frame.dart';
import '../audio/audio_input.dart';
import '../dsp/pitch_detector.dart';
import '../dsp/pitch_filter.dart';
import 'tuner_config.dart';
import 'tuner_engine.dart';
import 'tuner_pipeline.dart';
import 'tuner_reading.dart';

/// [TunerEngine] que compõe:
///
/// AudioInput → PitchDetector → [TunerPipeline] → TunerReading
///
/// Esta classe só orquestra áudio e streams; toda a lógica temporal (gates,
/// oitava, estabilidade, smoothing, histereses, hold) está no
/// [TunerPipeline], que é síncrono e testável sem áudio.
class PitchTunerEngine implements TunerEngine {
  PitchTunerEngine({
    required this._audioInput,
    required this._detector,
    this.config = const TunerConfig(),
    PitchFilter? pitchFilter,
  }) : _pipeline = TunerPipeline(config: config, pitchFilter: pitchFilter);

  final AudioInput _audioInput;
  final PitchDetector _detector;
  final TunerPipeline _pipeline;
  final StreamController<TunerReading?> _readings =
      StreamController<TunerReading?>.broadcast();
  StreamSubscription<AudioFrame>? _subscription;

  @override
  final TunerConfig config;

  @override
  Stream<TunerReading?> get readings => _readings.stream;

  @override
  Future<void> start() async {
    if (_subscription != null) return;
    _detector.reset();
    _pipeline.reset();
    _subscription = _audioInput.frames.listen(_onFrame);
    try {
      await _audioInput.start();
    } catch (_) {
      await _subscription?.cancel();
      _subscription = null;
      rethrow;
    }
  }

  @override
  Future<void> stop() async {
    await _subscription?.cancel();
    _subscription = null;
    await _audioInput.stop();
    _pipeline.reset();
    _readings.add(null);
  }

  @override
  Future<void> dispose() async {
    await _subscription?.cancel();
    _subscription = null;
    await _audioInput.dispose();
    await _readings.close();
  }

  void _onFrame(AudioFrame frame) {
    _readings.add(_pipeline.process(_detector.detect(frame), frame.timestamp));
  }
}
