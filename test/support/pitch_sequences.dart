import 'package:guitar_zero/core/dsp/pitch_estimate.dart';
import 'package:guitar_zero/core/music/pitch_math.dart';
import 'package:guitar_zero/core/tuner/tuner_pipeline.dart';
import 'package:guitar_zero/core/tuner/tuner_reading.dart';

import 'synthetic_signals.dart';

/// Um passo de uma sequência temporal de estimativas.
typedef TimedEstimate = ({Duration t, PitchEstimate? estimate});

/// Constrói sequências determinísticas de [PitchEstimate] com timestamps,
/// simulando a saída do detector a cada [hop].
class PitchSequenceBuilder {
  PitchSequenceBuilder({
    this.hop = const Duration(milliseconds: 40),
    int seed = 1,
  }) : _rng = Xorshift32(seed);

  final Duration hop;
  final Xorshift32 _rng;
  final List<TimedEstimate> _steps = [];
  Duration _t = Duration.zero;

  Duration get now => _t;

  void _add(PitchEstimate? estimate) {
    _steps.add((t: _t, estimate: estimate));
    _t += hop;
  }

  /// [count] estimativas em [baseHz] deslocado de [cents], com jitter
  /// uniforme em ±[jitterCents].
  void note(
    double baseHz,
    int count, {
    double cents = 0,
    double jitterCents = 0,
    double periodicity = 0.97,
  }) {
    for (var i = 0; i < count; i++) {
      final c = cents + jitterCents * _rng.nextSigned();
      _add(
        PitchEstimate(
          frequencyHz: baseHz * _centsRatio(c),
          periodicity: periodicity,
        ),
      );
    }
  }

  /// Rampa linear de [fromCents] a [toCents] (inclusive) em [count] passos.
  void ramp(
    double baseHz,
    int count, {
    required double fromCents,
    required double toCents,
    double jitterCents = 0,
  }) {
    for (var i = 0; i < count; i++) {
      final c =
          fromCents +
          (toCents - fromCents) * i / (count - 1) +
          jitterCents * _rng.nextSigned();
      _add(
        PitchEstimate(frequencyHz: baseHz * _centsRatio(c), periodicity: 0.97),
      );
    }
  }

  /// [count] frames sem estimativa.
  void silence(int count) {
    for (var i = 0; i < count; i++) {
      _add(null);
    }
  }

  /// Uma estimativa arbitrária.
  void estimate(PitchEstimate? estimate) => _add(estimate);

  /// Frequências aleatórias e independentes em [minHz, maxHz] (ruído).
  void randomFrequencies(
    int count, {
    double minHz = 80,
    double maxHz = 400,
    double periodicity = 0.95,
  }) {
    for (var i = 0; i < count; i++) {
      final u = (_rng.nextSigned() + 1) / 2;
      _add(
        PitchEstimate(
          frequencyHz: minHz * _centsRatio(u * centsBetween(maxHz, minHz)),
          periodicity: periodicity,
        ),
      );
    }
  }

  /// Glissandos aleatórios, como fala: velocidade de até ±[maxCentsPerSecond]
  /// sorteada a cada 200 ms, mais jitter de ±5 cents.
  void speechLike(
    int count, {
    double startHz = 160,
    double maxCentsPerSecond = 600,
    double periodicity = 0.95,
  }) {
    var cents = 0.0;
    var velocity = 0.0;
    final stepsPerChange = (200 / hop.inMilliseconds).round();
    for (var i = 0; i < count; i++) {
      if (i % stepsPerChange == 0) {
        velocity = maxCentsPerSecond * _rng.nextSigned();
      }
      cents += velocity * hop.inMicroseconds / 1e6;
      if (cents.abs() > 900) velocity = -velocity;
      _add(
        PitchEstimate(
          frequencyHz: startHz * _centsRatio(cents + 5 * _rng.nextSigned()),
          periodicity: periodicity,
        ),
      );
    }
  }

  List<TimedEstimate> build() => List.unmodifiable(_steps);

  static double _centsRatio(double cents) =>
      frequencyFromMidi(69 + cents / 100) / kA4Frequency;
}

/// Executa [steps] em [pipeline] e devolve a saída de cada passo.
List<TunerReading?> runPipeline(
  TunerPipeline pipeline,
  List<TimedEstimate> steps,
) => [for (final s in steps) pipeline.process(s.estimate, s.t)];
