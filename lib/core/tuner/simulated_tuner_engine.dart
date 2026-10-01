import 'dart:async';
import 'dart:math' as math;

import '../music/pitch_math.dart';
import 'tuner_config.dart';
import 'tuner_engine.dart';
import 'tuner_reading.dart';

/// [TunerEngine] que gera leituras sintéticas, sem microfone.
///
/// Usado apenas para desenvolver e revisar a interface enquanto a captura de
/// áudio e o DSP não existem. Percorre as cordas simulando uma afinação que
/// converge para 0 cents, com uma pequena oscilação e pausas de silêncio.
class SimulatedTunerEngine implements TunerEngine {
  SimulatedTunerEngine({
    this.config = const TunerConfig(),
    this.tick = const Duration(milliseconds: 50),
    int seed = 7,
  }) : _random = math.Random(seed);

  @override
  final TunerConfig config;

  final Duration tick;
  final math.Random _random;
  final StreamController<TunerReading?> _readings =
      StreamController<TunerReading?>.broadcast();
  Timer? _timer;

  static const int _ticksPerString = 90;
  static const int _silentTicks = 20;

  int _step = 0;
  int _stringIndex = 0;
  double _startCents = 0;

  @override
  Stream<TunerReading?> get readings => _readings.stream;

  @override
  Future<void> start() async {
    if (_timer != null) return;
    _beginString();
    _timer = Timer.periodic(tick, (_) => _onTick());
  }

  @override
  Future<void> stop() async {
    _timer?.cancel();
    _timer = null;
    _readings.add(null);
  }

  @override
  Future<void> dispose() async {
    _timer?.cancel();
    _timer = null;
    await _readings.close();
  }

  void _beginString() {
    _step = 0;
    final sign = _random.nextBool() ? 1 : -1;
    _startCents = sign * (15 + _random.nextDouble() * 30);
  }

  void _onTick() {
    _step++;
    if (_step > _ticksPerString + _silentTicks) {
      _stringIndex = (_stringIndex + 1) % config.tuning.strings.length;
      _beginString();
    }
    if (_step > _ticksPerString) {
      _readings.add(null);
      return;
    }

    final progress = _step / _ticksPerString;
    final jitter = (_random.nextDouble() - 0.5) * 1.5;
    final cents = _startCents * math.exp(-4 * progress) + jitter;
    final string = config.tuning.strings[_stringIndex];
    _readings.add(
      TunerReading(
        frequency: frequencyFromMidi(string.note.midi + cents / 100),
        confidence: 0.95,
        string: string,
        cents: cents,
        isInTune: cents.abs() <= config.inTuneEnterCents,
      ),
    );
  }
}
