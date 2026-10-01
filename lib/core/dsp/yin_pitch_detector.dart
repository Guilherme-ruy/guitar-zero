import 'dart:math' as math;
import 'dart:typed_data';

import '../audio/audio_frame.dart';
import 'pitch_detector.dart';
import 'pitch_estimate.dart';

/// Parâmetros do [YinPitchDetector].
class YinConfig {
  const YinConfig({
    this.minFrequencyHz = 60,
    this.maxFrequencyHz = 450,
    this.threshold = 0.15,
    this.minRms = 0.004,
  }) : assert(minFrequencyHz > 0 && maxFrequencyHz > minFrequencyHz),
       assert(threshold > 0 && threshold < 1),
       assert(minRms >= 0);

  /// Menor fundamental procurada, em Hz. Define o maior lag analisado.
  final double minFrequencyHz;

  /// Maior fundamental procurada, em Hz. Define o menor lag analisado.
  final double maxFrequencyHz;

  /// Limiar absoluto do YIN (passo 4 do paper): o primeiro mínimo da CMNDF
  /// abaixo deste valor é escolhido como período.
  final double threshold;

  /// Frames com RMS (após remoção de DC) abaixo disto são tratados como
  /// silêncio e não produzem estimativa.
  final double minRms;

  /// Menor lag analisado, em amostras.
  int minLag(int sampleRate) =>
      math.max(2, (sampleRate / maxFrequencyHz).floor());

  /// Maior lag analisado, em amostras.
  int maxLag(int sampleRate) => (sampleRate / minFrequencyHz).ceil();

  /// Menor frame aceito: a janela de integração precisa ser pelo menos tão
  /// longa quanto o maior lag (+1 vizinho para a interpolação).
  int minFrameSize(int sampleRate) => 2 * (maxLag(sampleRate) + 1);
}

/// Detector de frequência fundamental baseado no YIN.
///
/// Implementação própria a partir de: A. de Cheveigné, H. Kawahara, "YIN, a
/// fundamental frequency estimator for speech and music", JASA 111(4), 2002.
/// Os projetos fgnass/tuner (MIT) e PitchKit (Apache 2.0) foram usados como
/// referência técnica e de parâmetros; nenhum código foi copiado.
///
/// Etapas por frame:
/// 1. remoção de DC (média) e cálculo do RMS; abaixo de [YinConfig.minRms],
///    retorna `null`;
/// 2. função diferença `d(τ) = Σ (x[i] − x[i+τ])²`, `i ∈ [0, W)`, com janela
///    de integração `W = N − (τmax + 1)` (usa todo o frame disponível);
/// 3. CMNDF `d'(τ) = d(τ) · τ / Σ_{j=1..τ} d(j)`, `d'(0) = 1`;
/// 4. busca restrita a `τ ∈ [sr/fmax, sr/fmin]`: primeiro vale de `d'`
///    abaixo de `threshold` (região contígua), escolhendo o menor valor do
///    vale; sem nenhum, usa o mínimo global da faixa (com confiança baixa);
/// 5. o mínimo precisa ser um mínimo local verdadeiro — se encosta na borda
///    da faixa, a fundamental real está fora dela e retorna `null`;
/// 6. interpolação parabólica sobre `d(τ)` bruto (o paper recomenda `d` em
///    vez de `d'` para evitar viés), `f = sr / τ_refinado`;
/// 7. `confidence = 1 − d'(τ)`, limitada a [0, 1].
///
/// Síncrono, sem I/O e sem alocação por frame (buffers reaproveitados).
class YinPitchDetector implements PitchDetector {
  YinPitchDetector({this.config = const YinConfig()});

  final YinConfig config;

  Float64List _signal = Float64List(0);
  Float64List _diff = Float64List(0);
  Float64List _cmnd = Float64List(0);

  @override
  PitchEstimate? detect(AudioFrame frame) {
    final sampleRate = frame.sampleRate;
    final input = frame.samples;
    final n = input.length;
    final minLag = config.minLag(sampleRate);
    final maxLag = config.maxLag(sampleRate);
    // Calcula até maxLag + 1 para ter o vizinho direito do último candidato.
    final lastLag = maxLag + 1;
    final window = n - lastLag;
    if (window < lastLag) {
      throw ArgumentError.value(
        n,
        'frame.samples.length',
        'Frame curto demais: mínimo ${config.minFrameSize(sampleRate)} '
            'amostras a $sampleRate Hz',
      );
    }
    _ensureCapacity(n, lastLag + 1);
    final x = _signal;
    final d = _diff;
    final cmnd = _cmnd;

    // 1. Remoção de DC e RMS.
    var mean = 0.0;
    for (var i = 0; i < n; i++) {
      mean += input[i];
    }
    mean /= n;
    var sumSquares = 0.0;
    for (var i = 0; i < n; i++) {
      final v = input[i] - mean;
      x[i] = v;
      sumSquares += v * v;
    }
    final rms = math.sqrt(sumSquares / n);
    if (rms < config.minRms || rms == 0) return null;

    // 2. Função diferença.
    d[0] = 0;
    for (var tau = 1; tau <= lastLag; tau++) {
      var sum = 0.0;
      for (var i = 0; i < window; i++) {
        final delta = x[i] - x[i + tau];
        sum += delta * delta;
      }
      d[tau] = sum;
    }

    // 3. CMNDF.
    cmnd[0] = 1;
    var runningSum = 0.0;
    for (var tau = 1; tau <= lastLag; tau++) {
      runningSum += d[tau];
      cmnd[tau] = runningSum > 0 ? d[tau] * tau / runningSum : 1;
    }

    // 4. Primeiro mínimo abaixo do limiar; senão, mínimo global da faixa.
    // O "vale" é a região contígua abaixo do limiar; usa-se o menor valor da
    // região inteira (e não o primeiro mínimo local), para que ondulações
    // causadas por ruído dentro do vale não interrompam a busca.
    var tau = -1;
    for (var t = minLag; t <= maxLag; t++) {
      if (cmnd[t] < config.threshold) {
        tau = t;
        while (t < lastLag && cmnd[t + 1] < config.threshold) {
          t++;
          if (cmnd[t] < cmnd[tau]) tau = t;
        }
        break;
      }
    }
    if (tau == -1) {
      tau = minLag;
      for (var t = minLag + 1; t <= maxLag; t++) {
        if (cmnd[t] < cmnd[tau]) tau = t;
      }
    }

    // 5. Restrição de faixa: precisa ser mínimo local dentro de [min, max].
    if (tau > maxLag ||
        cmnd[tau - 1] < cmnd[tau] ||
        cmnd[tau + 1] < cmnd[tau]) {
      return null;
    }

    // 6. Interpolação parabólica em d(τ).
    final refinedLag = tau + _parabolicOffset(d[tau - 1], d[tau], d[tau + 1]);
    final frequency = sampleRate / refinedLag;
    if (frequency < config.minFrequencyHz ||
        frequency > config.maxFrequencyHz) {
      return null;
    }

    // 7. Confiança.
    final confidence = (1 - cmnd[tau]).clamp(0.0, 1.0);
    return PitchEstimate(
      frequencyHz: frequency,
      confidence: confidence,
      rms: rms,
    );
  }

  @override
  void reset() {
    // Sem estado entre frames além dos buffers de trabalho.
  }

  void _ensureCapacity(int frameLength, int lagCount) {
    if (_signal.length < frameLength) _signal = Float64List(frameLength);
    if (_diff.length < lagCount) {
      _diff = Float64List(lagCount);
      _cmnd = Float64List(lagCount);
    }
  }

  /// Deslocamento, em amostras, do vértice da parábola que passa por
  /// (−1, a), (0, b), (1, c). Limitado a [−1, 1]; 0 se não houver mínimo.
  static double _parabolicOffset(double a, double b, double c) {
    final denominator = a - 2 * b + c;
    if (denominator <= 0) return 0;
    return (0.5 * (a - c) / denominator).clamp(-1.0, 1.0);
  }
}
