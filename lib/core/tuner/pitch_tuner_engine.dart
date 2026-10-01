import 'dart:async';

import '../audio/audio_frame.dart';
import '../audio/audio_input.dart';
import '../dsp/pitch_detector.dart';
import '../dsp/pitch_filter.dart';
import '../music/string_matcher.dart';
import 'tuner_config.dart';
import 'tuner_engine.dart';
import 'tuner_reading.dart';

/// [TunerEngine] que compõe o pipeline:
///
/// AudioInput → PitchDetector → PitchFilter → StringMatcher → TunerReading
///
/// Esta classe só orquestra; cada etapa é injetada e testável isoladamente.
class PitchTunerEngine implements TunerEngine {
  PitchTunerEngine({
    required this._audioInput,
    required this._detector,
    this._filter = const PitchFilterChain([]),
    this.config = const TunerConfig(),
  }) : _matcher = StringMatcher(tuning: config.tuning);

  final AudioInput _audioInput;
  final PitchDetector _detector;
  final PitchFilter _filter;
  final StringMatcher _matcher;
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
    _filter.reset();
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
    var estimate = _detector.detect(frame);
    if (estimate != null && estimate.confidence < config.minConfidence) {
      estimate = null;
    }
    final filtered = _filter.process(estimate);
    _readings.add(
      filtered == null
          ? null
          : _toReading(filtered.frequency, filtered.confidence),
    );
  }

  TunerReading? _toReading(double frequency, double confidence) {
    final match = _matcher.match(frequency);
    if (match == null) return null;
    return TunerReading(
      frequency: frequency,
      confidence: confidence,
      string: match.string,
      cents: match.cents,
      isInTune: match.cents.abs() <= config.inTuneToleranceCents,
    );
  }
}
