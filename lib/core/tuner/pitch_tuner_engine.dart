import 'dart:async';

import '../audio/audio_frame.dart';
import '../audio/audio_input.dart';
import '../dsp/pitch_detector.dart';
import '../dsp/pitch_filter.dart';
import '../music/guitar_string.dart';
import 'frame_processor.dart';
import 'tuner_config.dart';
import 'tuner_diagnostics.dart';
import 'tuner_engine.dart';
import 'tuner_reading.dart';

/// [TunerEngine] que compõe:
///
/// AudioInput → [FrameProcessor] (PitchDetector + TunerPipeline) →
/// TunerReading
///
/// Esta classe só orquestra áudio e streams. Toda a lógica de detecção e
/// estabilização está no detector e no `TunerPipeline`; onde ela roda
/// (inline ou em outro isolate) é decidido pelo [FrameProcessor].
class PitchTunerEngine implements TunerEngine {
  /// Processamento inline com o [detector] informado.
  PitchTunerEngine({
    required AudioInput audioInput,
    required PitchDetector detector,
    TunerConfig config = const TunerConfig(),
    PitchFilter? pitchFilter,
  }) : this.withProcessor(
         audioInput: audioInput,
         config: config,
         processor: InlineFrameProcessor(
           detector: detector,
           config: config,
           pitchFilter: pitchFilter,
         ),
       );

  PitchTunerEngine.withProcessor({
    required this._audioInput,
    required this._processor,
    this.config = const TunerConfig(),
  });

  final AudioInput _audioInput;
  final FrameProcessor _processor;
  final StreamController<TunerReading?> _readings =
      StreamController<TunerReading?>.broadcast();
  StreamSubscription<AudioFrame>? _frameSubscription;
  StreamSubscription<TunerReading?>? _readingSubscription;
  bool _processorStarted = false;

  @override
  final TunerConfig config;

  @override
  Stream<TunerReading?> get readings => _readings.stream;

  @override
  Stream<TunerDiagnostics> get diagnostics => _processor.diagnostics;

  @override
  void setTargetString(GuitarString? string) =>
      _processor.setTargetString(string);

  @override
  Future<void> start() async {
    if (_frameSubscription != null) return;
    if (!_processorStarted) {
      _readingSubscription = _processor.readings.listen(_readings.add);
      await _processor.start();
      _processorStarted = true;
    }
    _processor.reset();
    _frameSubscription = _audioInput.frames.listen(
      _processor.process,
      onError: _onCaptureError,
      onDone: () => _onCaptureError(
        const AudioInputException(
          AudioInputFailure.unavailable,
          'captura encerrada',
        ),
      ),
    );
    try {
      await _audioInput.start();
    } catch (_) {
      await _frameSubscription?.cancel();
      _frameSubscription = null;
      rethrow;
    }
  }

  /// Falha da captura durante o uso (microfone tomado por outro app,
  /// interrupção, stream encerrado): vai para quem escuta [readings].
  void _onCaptureError(Object error) {
    _frameSubscription = null;
    _processor.reset();
    if (_readings.isClosed) return;
    _readings.addError(
      error is AudioInputException
          ? error
          : AudioInputException(AudioInputFailure.unavailable, '$error'),
    );
  }

  @override
  Future<void> stop() async {
    await _frameSubscription?.cancel();
    _frameSubscription = null;
    await _audioInput.stop();
    _processor.reset();
    if (!_readings.isClosed) _readings.add(null);
  }

  @override
  Future<void> dispose() async {
    await _frameSubscription?.cancel();
    _frameSubscription = null;
    await _audioInput.dispose();
    await _readingSubscription?.cancel();
    await _processor.dispose();
    await _readings.close();
  }
}
