import 'dart:math' as math;
import 'dart:typed_data';

import 'package:guitar_zero/core/audio/audio_frame.dart';

/// Geração determinística de sinais PCM sintéticos para testar detectores.
///
/// Tudo é função pura dos parâmetros (inclusive o ruído, gerado por um
/// xorshift32 com semente fixa), para que os testes sejam reproduzíveis em
/// qualquer máquina.
abstract final class SyntheticSignals {
  /// Soma de harmônicos: `amplitude · Σ harmonics[h−1] · sin(2π·f_h·t + φh)`
  /// + [dcOffset] + ruído branco uniforme de pico [noise], com
  /// `f_h = h·f0·√(1 + B·h²)` (B = [inharmonicity]; 0 = série ideal).
  ///
  /// As fases `φh` são fixas e diferentes por harmônico para evitar formas de
  /// onda simétricas artificiais. [startTimeSeconds] desloca o tempo (útil
  /// para extrair frames de um sinal contínuo).
  static Float32List tone({
    required double frequencyHz,
    required int sampleRate,
    required int length,
    List<double> harmonics = const [1],
    double amplitude = 0.5,
    double dcOffset = 0,
    double noise = 0,
    int seed = 1,
    double startTimeSeconds = 0,
    double inharmonicity = 0,
  }) {
    final out = Float32List(length);
    final rng = Xorshift32(seed);
    // Parciais esticados como em cordas reais: f_h = h·f0·√(1 + B·h²).
    final partialHz = [
      for (var h = 1; h <= harmonics.length; h++)
        h * frequencyHz * math.sqrt(1 + inharmonicity * h * h),
    ];
    for (var i = 0; i < length; i++) {
      final t = startTimeSeconds + i / sampleRate;
      var s = 0.0;
      for (var h = 1; h <= harmonics.length; h++) {
        final a = harmonics[h - 1];
        if (a == 0 || partialHz[h - 1] >= sampleRate / 2) continue;
        s += a * math.sin(2 * math.pi * partialHz[h - 1] * t + 0.7 * h);
      }
      var v = amplitude * s + dcOffset;
      if (noise > 0) v += noise * rng.nextSigned();
      out[i] = v;
    }
    return out;
  }

  /// Soma de parciais com frequências arbitrárias (não necessariamente
  /// harmônicas): `amplitude · Σ a·sin(2π·f·t + φ)`, mais ruído opcional.
  static Float32List partials({
    required List<({double hz, double amplitude})> components,
    required int sampleRate,
    required int length,
    double amplitude = 0.5,
    double noise = 0,
    int seed = 1,
  }) {
    final out = Float32List(length);
    final rng = Xorshift32(seed);
    for (var i = 0; i < length; i++) {
      final t = i / sampleRate;
      var s = 0.0;
      for (var c = 0; c < components.length; c++) {
        final p = components[c];
        s += p.amplitude * math.sin(2 * math.pi * p.hz * t + 0.9 * (c + 1));
      }
      var v = amplitude * s;
      if (noise > 0) v += noise * rng.nextSigned();
      out[i] = v;
    }
    return out;
  }

  /// Glissando harmônico: a fundamental parte de [startHz] e varia
  /// [centsPerSecond] continuamente (fase integrada, sem descontinuidade).
  static Float32List glide({
    required double startHz,
    required double centsPerSecond,
    required int sampleRate,
    required int length,
    List<double> harmonics = const [1, 0.6, 0.4, 0.25],
    double amplitude = 0.5,
  }) {
    final out = Float32List(length);
    final phases = List<double>.filled(harmonics.length, 0);
    for (var i = 0; i < length; i++) {
      final t = i / sampleRate;
      final f = startHz * math.pow(2, centsPerSecond * t / 1200);
      var s = 0.0;
      for (var h = 1; h <= harmonics.length; h++) {
        phases[h - 1] += 2 * math.pi * h * f / sampleRate;
        s += harmonics[h - 1] * math.sin(phases[h - 1] + 0.7 * h);
      }
      out[i] = amplitude * s;
    }
    return out;
  }

  /// Ruído branco uniforme em [−peak, peak].
  static Float32List whiteNoise({
    required int length,
    double peak = 0.5,
    int seed = 1,
  }) {
    final rng = Xorshift32(seed);
    return Float32List.fromList([
      for (var i = 0; i < length; i++) peak * rng.nextSigned(),
    ]);
  }

  /// Palhetada simplificada: ruído de ataque (~15 ms, decaindo rápido) +
  /// tom harmônico com ataque de 5 ms e decaimento exponencial.
  static Float32List pluck({
    required double frequencyHz,
    required int sampleRate,
    required int length,
    List<double> harmonics = const [1, 0.6, 0.4, 0.25, 0.15],
    double amplitude = 0.5,
    double attackNoise = 0.6,
    int seed = 3,
  }) {
    final out = tone(
      frequencyHz: frequencyHz,
      sampleRate: sampleRate,
      length: length,
      harmonics: harmonics,
      amplitude: amplitude,
    );
    final rng = Xorshift32(seed);
    final attack = 0.005 * sampleRate;
    for (var i = 0; i < length; i++) {
      final t = i / sampleRate;
      final envelope = math.min(1.0, i / attack) * math.exp(-t / 1.5);
      final burst = attackNoise * math.exp(-t / 0.004) * rng.nextSigned();
      out[i] = out[i] * envelope + burst;
    }
    return out;
  }

  /// Trecho [offset, offset + length) de [signal] como [AudioFrame]. O
  /// timestamp é a posição do trecho no sinal, somada a [timestamp].
  static AudioFrame frame(
    Float32List signal,
    int sampleRate, {
    int offset = 0,
    int? length,
    Duration timestamp = Duration.zero,
  }) => AudioFrame(
    samples: Float32List.sublistView(
      signal,
      offset,
      offset + (length ?? signal.length - offset),
    ),
    sampleRate: sampleRate,
    timestamp:
        timestamp +
        Duration(
          microseconds: offset * Duration.microsecondsPerSecond ~/ sampleRate,
        ),
  );
}

/// PRNG xorshift32 (Marsaglia, 2003): determinístico e independente da
/// implementação de `Random` da plataforma.
class Xorshift32 {
  Xorshift32(int seed) : _state = seed == 0 ? 0x9E3779B9 : seed & 0xFFFFFFFF;

  int _state;

  /// Uniforme em [−1, 1).
  double nextSigned() {
    var x = _state;
    x ^= (x << 13) & 0xFFFFFFFF;
    x ^= x >> 17;
    x ^= (x << 5) & 0xFFFFFFFF;
    _state = x;
    return x / 0x80000000 - 1;
  }
}
