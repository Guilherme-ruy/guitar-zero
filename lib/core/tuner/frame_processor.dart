import 'dart:async';
import 'dart:isolate';
import 'dart:typed_data';

import '../audio/audio_frame.dart';
import '../dsp/harmonic_pitch_detector.dart';
import '../dsp/pitch_detector.dart';
import '../dsp/pitch_filter.dart';
import 'tuner_config.dart';
import 'tuner_pipeline.dart';
import 'tuner_reading.dart';

/// Executa detector + [TunerPipeline] sobre frames de áudio.
///
/// Separa *onde* o DSP roda (inline ou em outro isolate) do *que* ele faz.
abstract interface class FrameProcessor {
  /// Uma leitura (ou `null`) por frame processado, em ordem.
  Stream<TunerReading?> get readings;

  Future<void> start();

  /// Envia um frame. Implementações podem descartar frames se o
  /// processamento estiver atrasado (os filtros usam timestamps).
  void process(AudioFrame frame);

  /// Descarta o estado (detector, filtros, histereses) e resultados ainda
  /// não entregues.
  void reset();

  Future<void> dispose();
}

/// Processa no isolate atual, de forma síncrona. Usado em testes e quando o
/// custo por frame é irrelevante.
class InlineFrameProcessor implements FrameProcessor {
  InlineFrameProcessor({
    required this.detector,
    TunerConfig config = const TunerConfig(),
    PitchFilter? pitchFilter,
  }) : _pipeline = TunerPipeline(config: config, pitchFilter: pitchFilter);

  final PitchDetector detector;
  final TunerPipeline _pipeline;
  final StreamController<TunerReading?> _readings =
      StreamController<TunerReading?>.broadcast(sync: true);

  @override
  Stream<TunerReading?> get readings => _readings.stream;

  @override
  Future<void> start() async {}

  @override
  void process(AudioFrame frame) =>
      _readings.add(_pipeline.process(detector.detect(frame), frame.timestamp));

  @override
  void reset() {
    detector.reset();
    _pipeline.reset();
  }

  @override
  Future<void> dispose() => _readings.close();
}

/// Cria o detector dentro do isolate de processamento.
typedef PitchDetectorFactory = PitchDetector Function();

PitchDetector _defaultDetector() => HarmonicPitchDetector();

/// Processa em um isolate dedicado, para que o DSP (3–9 ms por frame num
/// servidor; mais num celular) nunca dispute tempo com a UI.
///
/// Backpressure: no máximo um frame em processamento e um pendente; um frame
/// novo substitui o pendente (o mais recente é o que importa). Resultados de
/// frames enviados antes de um [reset] são descartados.
class IsolateFrameProcessor implements FrameProcessor {
  IsolateFrameProcessor({
    this.config = const TunerConfig(),
    this.detectorFactory = _defaultDetector,
  });

  final TunerConfig config;
  final PitchDetectorFactory detectorFactory;

  final StreamController<TunerReading?> _readings =
      StreamController<TunerReading?>.broadcast();
  Isolate? _isolate;
  ReceivePort? _fromWorker;
  SendPort? _toWorker;
  int _generation = 0;
  bool _busy = false;
  AudioFrame? _pending;

  /// Frames descartados por backpressure (diagnóstico).
  int droppedFrames = 0;

  @override
  Stream<TunerReading?> get readings => _readings.stream;

  @override
  Future<void> start() async {
    if (_isolate != null) return;
    final fromWorker = ReceivePort();
    _fromWorker = fromWorker;
    final ready = Completer<SendPort>();
    fromWorker.listen((Object? message) {
      switch (message) {
        case final SendPort port:
          ready.complete(port);
        case _WorkerResult(:final generation, :final reading):
          _busy = false;
          if (generation == _generation && !_readings.isClosed) {
            _readings.add(reading);
          }
          final next = _pending;
          if (next != null) {
            _pending = null;
            _send(next);
          }
      }
    });
    _isolate = await Isolate.spawn(
      _workerMain,
      _WorkerSetup(fromWorker.sendPort, config, detectorFactory),
      debugName: 'guitar_zero_dsp',
    );
    _toWorker = await ready.future;
  }

  @override
  void process(AudioFrame frame) {
    if (_toWorker == null) return;
    if (_busy) {
      if (_pending != null) droppedFrames++;
      _pending = frame;
      return;
    }
    _send(frame);
  }

  void _send(AudioFrame frame) {
    _busy = true;
    _toWorker!.send(
      _WorkerFrame(
        _generation,
        frame.samples,
        frame.sampleRate,
        frame.timestamp.inMicroseconds,
      ),
    );
  }

  @override
  void reset() {
    _generation++;
    _pending = null;
    _toWorker?.send(const _WorkerReset());
  }

  @override
  Future<void> dispose() async {
    _isolate?.kill(priority: Isolate.immediate);
    _isolate = null;
    _fromWorker?.close();
    _toWorker = null;
    await _readings.close();
  }
}

class _WorkerSetup {
  const _WorkerSetup(this.replyTo, this.config, this.detectorFactory);

  final SendPort replyTo;
  final TunerConfig config;
  final PitchDetectorFactory detectorFactory;
}

class _WorkerFrame {
  const _WorkerFrame(
    this.generation,
    this.samples,
    this.sampleRate,
    this.timestampMicros,
  );

  final int generation;
  final Float32List samples;
  final int sampleRate;
  final int timestampMicros;
}

class _WorkerReset {
  const _WorkerReset();
}

class _WorkerResult {
  const _WorkerResult(this.generation, this.reading);

  final int generation;
  final TunerReading? reading;
}

void _workerMain(_WorkerSetup setup) {
  final detector = setup.detectorFactory();
  final pipeline = TunerPipeline(config: setup.config);
  final inbox = ReceivePort();
  setup.replyTo.send(inbox.sendPort);
  inbox.listen((Object? message) {
    switch (message) {
      case _WorkerFrame():
        final frame = AudioFrame(
          samples: message.samples,
          sampleRate: message.sampleRate,
          timestamp: Duration(microseconds: message.timestampMicros),
        );
        TunerReading? reading;
        try {
          reading = pipeline.process(detector.detect(frame), frame.timestamp);
        } catch (_) {
          // Um frame problemático não pode derrubar o worker: sem resposta,
          // o processador ficaria esperando para sempre. Trata como silêncio.
          reading = pipeline.process(null, frame.timestamp);
        }
        setup.replyTo.send(_WorkerResult(message.generation, reading));
      case _WorkerReset():
        detector.reset();
        pipeline.reset();
    }
  });
}
