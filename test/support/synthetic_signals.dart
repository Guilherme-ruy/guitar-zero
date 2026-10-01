import 'dart:math' as math;
import 'dart:typed_data';

import 'package:guitar_zero/core/audio/audio_frame.dart';

/// Geração determinística de sinais PCM sintéticos para testar detectores.
///
/// Tudo é função pura dos parâmetros (inclusive o ruído, gerado por um
/// xorshift32 com semente fixa), para que os testes sejam reproduzíveis em
/// qualquer máquina.
abstract final class SyntheticSignals {
  /// Soma de harmônicos: `amplitude · Σ harmonics[h−1] · sin(2π·h·f0·t + φh)`
  /// + [dcOffset] + ruído branco uniforme de pico [noise].
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
  }) {
    final out = Float32List(length);
    final rng = Xorshift32(seed);
    for (var i = 0; i < length; i++) {
      final t = startTimeSeconds + i / sampleRate;
      var s = 0.0;
      for (var h = 1; h <= harmonics.length; h++) {
        final a = harmonics[h - 1];
        if (a == 0 || h * frequencyHz >= sampleRate / 2) continue;
        s += a * math.sin(2 * math.pi * h * frequencyHz * t + 0.7 * h);
      }
      var v = amplitude * s + dcOffset;
      if (noise > 0) v += noise * rng.nextSigned();
      out[i] = v;
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
