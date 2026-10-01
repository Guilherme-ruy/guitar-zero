import 'dart:async';
import 'dart:isolate';
import 'dart:typed_data';

import '../audio/audio_frame.dart';
import '../dsp/harmonic_pitch_detector.dart';
import '../dsp/pitch_detector.dart';
import '../dsp/pitch_estimate.dart';
import '../dsp/pitch_filter.dart';
import '../music/guitar_string.dart';
import 'tuner_config.dart';
import 'tuner_diagnostics.dart';
import 'tuner_pipeline.dart';
import 'tuner_reading.dart';

/// Executa detector + [TunerPipeline] sobre frames de áudio.
///
/// Separa *onde* o DSP roda (inline ou em outro isolate) do *que* ele faz.
abstract interface class FrameProcessor {
  /// Uma leitura (ou `null`) por frame processado, em ordem.
  Stream<TunerReading?> get readings;

  /// Medidas por frame processado (depuração e calibração).
  Stream<TunerDiagnostics> get diagnostics;

  Future<void> start();

  /// Envia um frame. Implementações podem descartar frames se o
  /// processamento estiver atrasado (os filtros usam timestamps).
  void process(AudioFrame frame);

  /// Descarta o estado (detector, filtros, histereses) e resultados ainda
  /// não entregues.
  void reset();

  /// Corda alvo do modo manual (`null` = automático).
  void setTargetString(GuitarString? string);

  Future<void> dispose();
}

/// Processa um frame e mede o tempo gasto.
({TunerReading? reading, TunerDiagnostics diagnostics}) _processFrame(
  PitchDetector detector,
  TunerPipeline pipeline,
  AudioFrame frame,
) {
  final stopwatch = Stopwatch()..start();
  PitchEstimate? estimate;
  TunerReading? reading;
  try {
    estimate = detector.detect(frame);
    reading = pipeline.process(estimate, frame.timestamp);
  } catch (_) {
    // Um frame problemático não pode derrubar o processamento (no isolate,
    // o worker ficaria sem responder). Trata como silêncio.
    estimate = null;
    reading = pipeline.process(null, frame.timestamp);
  }
  return (
    reading: reading,
    diagnostics: TunerDiagnostics(
      timestamp: frame.timestamp,
      processingTime: stopwatch.elapsed,
      estimate: estimate,
    ),
  );
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
  final StreamController<TunerDiagnostics> _diagnostics =
      StreamController<TunerDiagnostics>.broadcast(sync: true);

  @override
  Stream<TunerReading?> get readings => _readings.stream;

  @override
  Stream<TunerDiagnostics> get diagnostics => _diagnostics.stream;

  @override
  Future<void> start() async {}

  @override
  void process(AudioFrame frame) {
    final result = _processFrame(detector, _pipeline, frame);
    _diagnostics.add(result.diagnostics);
    _readings.add(result.reading);
  }

  @override
  void reset() {
    detector.reset();
    _pipeline.reset();
  }

  @override
  void setTargetString(GuitarString? string) =>
      _pipeline.setTargetString(string);

  @override
  Future<void> dispose() async {
    await _readings.close();
    await _diagnostics.close();
  }
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
  final StreamController<TunerDiagnostics> _diagnostics =
      StreamController<TunerDiagnostics>.broadcast();
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
  Stream<TunerDiagnostics> get diagnostics => _diagnostics.stream;

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
        case _WorkerResult(
          :final generation,
          :final reading,
          :final diagnostics,
        ):
          _busy = false;
          if (generation == _generation && !_readings.isClosed) {
            _diagnostics.add(diagnostics.withDroppedFrames(droppedFrames));
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
    if (_target != null) _toWorker!.send(_WorkerTarget(_target));
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

  GuitarString? _target;

  @override
  void setTargetString(GuitarString? string) {
    _target = string;
    // Leituras em trânsito ainda são do alvo anterior: descartadas.
    _generation++;
    _pending = null;
    _toWorker?.send(_WorkerTarget(string));
  }

  @override
  Future<void> dispose() async {
    _isolate?.kill(priority: Isolate.immediate);
    _isolate = null;
    _fromWorker?.close();
    _toWorker = null;
    await _readings.close();
    await _diagnostics.close();
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

class _WorkerTarget {
  const _WorkerTarget(this.string);

  final GuitarString? string;
}

class _WorkerResult {
  const _WorkerResult(this.generation, this.reading, this.diagnostics);

  final int generation;
  final TunerReading? reading;
  final TunerDiagnostics diagnostics;
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
        final result = _processFrame(detector, pipeline, frame);
        setup.replyTo.send(
          _WorkerResult(message.generation, result.reading, result.diagnostics),
        );
      case _WorkerReset():
        detector.reset();
        pipeline.reset();
      case _WorkerTarget(:final string):
        pipeline.setTargetString(string);
    }
  });
}
