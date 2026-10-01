import 'dart:math' as math;

import '../../audio/audio_frame.dart';
import '../../music/pitch_math.dart';
import 'spectrum.dart';

/// Parâmetros do [HarmonicAnalyzer]. Valores iniciais; nenhum é definitivo.
class HarmonicAnalyzerConfig {
  const HarmonicAnalyzerConfig({
    this.maxHarmonics = 12,
    this.maxAnalysisHz = 5000,
    this.minFundamentalHz = 60,
    this.searchToleranceFraction = 0.03,
    this.frequencyToleranceCents = 40,
    this.prominenceRatio = 12,
    this.minRelativePower = 1e-4,
    this.minOddEnergyRatio = 0.003,
    this.minResolvedBins = 3,
    this.bandHalfWidthBins = 2,
    this.significantHarmonicRatio = 1e-3,
  });

  /// Quantos harmônicos considerar.
  final int maxHarmonics;

  /// Limite superior da análise (e no máximo 45% da taxa de amostragem).
  final double maxAnalysisHz;

  /// Uma correção para baixo nunca produz fundamental abaixo disto.
  final double minFundamentalHz;

  /// Meia-largura da busca por pico em torno de h·f0, como fração de h·f0
  /// (cobre inarmonicidade); no mínimo 2 bins.
  final double searchToleranceFraction;

  /// O pico interpolado precisa estar a no máximo isto de h·f0.
  final double frequencyToleranceCents;

  /// Um pico só conta se sua potência for ≥ isto × a mediana da vizinhança
  /// (12× ≈ 10.8 dB, valor inspirado no fgnass/tuner).
  final double prominenceRatio;

  /// …e ≥ isto × a maior potência do espectro (−40 dB).
  final double minRelativePower;

  /// Correção de oitava para baixo: fração mínima da energia harmônica de
  /// f/2 que precisa estar nos harmônicos ímpares de f/2 (que não existem
  /// se f for a fundamental verdadeira). 0.003 ≈ −25 dB.
  final double minOddEnergyRatio;

  /// A fundamental candidata precisa estar a pelo menos isto em bins (abaixo
  /// disso a FFT não a resolve; a análise não decide).
  final double minResolvedBins;

  /// Meia-largura, em bins, da banda de energia de cada harmônico (lóbulo
  /// principal da Hann = ±2 bins).
  final int bandHalfWidthBins;

  /// Para a completude da série, só contam harmônicos com potência ≥ isto ×
  /// a do harmônico mais forte (−30 dB).
  final double significantHarmonicRatio;
}

enum OctaveCorrection {
  /// A fundamental do detector foi mantida.
  none,

  /// O detector travou no 2º harmônico: fundamental = semente / 2.
  down,

  /// O detector reportou um sub-harmônico: fundamental = semente × 2.
  up,
}

/// Resultado da análise espectral de um frame dada uma semente.
class HarmonicAnalysis {
  const HarmonicAnalysis({
    required this.fundamentalHz,
    required this.correction,
    required this.harmonicity,
    required this.refinedHz,
    required this.harmonicsFound,
    required this.lowerOddEnergyRatio,
  });

  /// Fundamental escolhida: a semente, a metade ou o dobro dela (preserva a
  /// precisão do detector de período).
  final double fundamentalHz;

  final OctaveCorrection correction;

  /// Coerência do espectro com a série harmônica de [fundamentalHz], de 0
  /// a 1: energia explicada pelos harmônicos × completude da série.
  final double harmonicity;

  /// Fundamental estimada pela média ponderada de `f_h / h` dos harmônicos
  /// encontrados, ou `null` se nenhum foi encontrado.
  final double? refinedHz;

  /// Quantos harmônicos de [fundamentalHz] foram encontrados como picos.
  final int harmonicsFound;

  /// Diagnóstico: fração de energia nos harmônicos ímpares de semente/2
  /// (`NaN` quando não avaliado).
  final double lowerOddEnergyRatio;
}

/// Análise espectral de um frame a partir de uma fundamental "semente"
/// (normalmente do YIN). Responsabilidades:
///
/// 1. **Correção para baixo** (erro do YIN no 2º harmônico): aceita f/2
///    somente se (a) existe pico proeminente e preciso **em f/2** e (b) os
///    harmônicos ímpares de f/2 — que não existiriam se f fosse a
///    fundamental — somam ≥ [HarmonicAnalyzerConfig.minOddEnergyRatio] da
///    energia harmônica de f/2. Exigir o pico em f/2 evita falsos positivos
///    por ressonância de outras cordas, que produzem componentes em 1.5·f
///    (quintas/quartas) mas nunca uma oitava abaixo da corda mais grave.
/// 2. **Correção para cima** (sub-harmônico): se a semente não tem pico na
///    própria frequência nem em nenhum harmônico ímpar, mas tem em 2·f, o
///    sinal é melhor explicado por 2·f.
/// 3. **Harmonicidade** da fundamental escolhida.
/// 4. **Refinamento** por média ponderada (amplitude) de `f_h / h`.
///
/// Sem estado entre frames. Implementação própria; ideias de verificação de
/// sub-harmônico e proeminência por mediana inspiradas no fgnass/tuner
/// (MIT, @ b59d8b9) — nenhum código copiado.
class HarmonicAnalyzer {
  HarmonicAnalyzer({this.config = const HarmonicAnalyzerConfig()});

  final HarmonicAnalyzerConfig config;
  final Spectrum _spectrum = Spectrum();
  double _maxPower = 0;
  double _limitHz = 0;

  /// Analisa [frame] dada a semente [seedHz]. Retorna `null` se a FFT não
  /// resolve a semente (frame curto demais) ou o espectro está vazio.
  HarmonicAnalysis? analyze(AudioFrame frame, double seedHz) {
    _spectrum.compute(frame.samples, frame.sampleRate);
    if (_spectrum.fftSize == 0 ||
        seedHz / _spectrum.binHz < config.minResolvedBins) {
      return null;
    }
    _limitHz = math.min(config.maxAnalysisHz, 0.45 * frame.sampleRate);
    _maxPower = 0;
    final maxBin = math.min(
      _spectrum.binCount - 1,
      (_limitHz / _spectrum.binHz).floor(),
    );
    for (var k = 1; k <= maxBin; k++) {
      _maxPower = math.max(_maxPower, _spectrum.power(k));
    }
    if (_maxPower == 0) return null;

    var fundamental = seedHz;
    var correction = OctaveCorrection.none;
    var lowerOddRatio = double.nan;

    final lower = seedHz / 2;
    if (lower >= config.minFundamentalHz &&
        lower / _spectrum.binHz >= config.minResolvedBins) {
      final evidence = _oddEvidence(lower);
      lowerOddRatio = evidence.oddRatio;
      if (evidence.hasFirst && evidence.oddRatio >= config.minOddEnergyRatio) {
        fundamental = lower;
        correction = OctaveCorrection.down;
      }
    }
    if (correction == OctaveCorrection.none) {
      final own = _oddEvidence(seedHz);
      if (own.oddPeaks == 0 && _peakNear(2 * seedHz) != null) {
        fundamental = 2 * seedHz;
        correction = OctaveCorrection.up;
      }
    }

    final refinement = _refine(fundamental);
    return HarmonicAnalysis(
      fundamentalHz: fundamental,
      correction: correction,
      harmonicity: _harmonicity(fundamental),
      refinedHz: refinement.hz,
      harmonicsFound: refinement.count,
      lowerOddEnergyRatio: lowerOddRatio,
    );
  }

  /// Pico proeminente e preciso perto de [hz]: (bin, frequência
  /// interpolada) ou `null`.
  ({int bin, double hz})? _peakNear(double hz) {
    if (hz > _limitHz) return null;
    final binHz = _spectrum.binHz;
    final center = (hz / binHz).round();
    final halfWidth = math.max(
      2,
      (config.searchToleranceFraction * hz / binHz).round(),
    );
    final bin = _spectrum.localMaximumNear(center, halfWidth);
    if (bin < 0) return null;
    final p = _spectrum.power(bin);
    if (p < config.minRelativePower * _maxPower) return null;
    final floor = _spectrum.medianPower(center, 6 * halfWidth, bin);
    if (p < config.prominenceRatio * floor) return null;
    final peakHz = _spectrum.interpolatedBin(bin) * binHz;
    if (centsBetween(peakHz, hz).abs() > config.frequencyToleranceCents) {
      return null;
    }
    return (bin: bin, hz: peakHz);
  }

  /// Energia nos harmônicos ímpares de [f0] (só picos válidos) relativa à
  /// energia em todas as posições harmônicas de [f0].
  ({bool hasFirst, int oddPeaks, double oddRatio}) _oddEvidence(double f0) {
    final binHz = _spectrum.binHz;
    final w = config.bandHalfWidthBins;
    var total = 0.0;
    var odd = 0.0;
    var oddPeaks = 0;
    var hasFirst = false;
    for (var h = 1; h <= config.maxHarmonics && h * f0 <= _limitHz; h++) {
      total += _spectrum.bandPower((h * f0 / binHz).round(), w);
      if (h.isOdd) {
        final peak = _peakNear(h * f0);
        if (peak != null) {
          oddPeaks++;
          odd += _spectrum.bandPower(peak.bin, w);
          if (h == 1) hasFirst = true;
        }
      }
    }
    return (
      hasFirst: hasFirst,
      oddPeaks: oddPeaks,
      oddRatio: total > 0 ? odd / total : 0.0,
    );
  }

  /// Harmonicidade = energia explicada × completude da série.
  ///
  /// - **Energia explicada**: energia nas bandas (±[bandHalfWidthBins]) dos
  ///   picos válidos em h·f0 (proeminentes e a ≤ frequencyToleranceCents),
  ///   dividida pela energia total entre f0/2 e o limite da análise. Ruído
  ///   espalha energia fora dessas bandas.
  /// - **Completude**: harmônicos encontrados ÷ ordem do maior harmônico
  ///   significativo (≥ [HarmonicAnalyzerConfig.significantHarmonicRatio] do
  ///   mais forte). Penaliza "séries" esparsas (ex.: só h = 5, 7, 11, 18 de uma
  ///   fundamental baixa demais), que acontecem quando qualquer conjunto de
  ///   parciais é visto como harmônico de um f0 muito grave. Não penaliza a
  ///   falta de harmônicos acima do último presente (senoide pura = 1).
  double _harmonicity(double f0) {
    final binHz = _spectrum.binHz;
    final w = config.bandHalfWidthBins;
    final lo = math.max(1, (0.5 * f0 / binHz).round());
    final hi = math.min(_spectrum.binCount - 1, (_limitHz / binHz).floor());
    if (hi <= lo) return 0;

    final inBand = List<bool>.filled(hi - lo + 1, false);
    final orders = <int>[];
    final powers = <double>[];
    for (var h = 1; h * f0 <= _limitHz; h++) {
      final peak = _peakNear(h * f0);
      if (peak == null) continue;
      orders.add(h);
      powers.add(_spectrum.power(peak.bin));
      for (var k = peak.bin - w; k <= peak.bin + w; k++) {
        if (k >= lo && k <= hi) inBand[k - lo] = true;
      }
    }
    if (orders.isEmpty) return 0;

    // Completude só sobre harmônicos significativos: um pico de ruído que
    // case por acaso com h·f0 muito alto não deve derrubar a métrica.
    final strongest = powers.reduce(math.max);
    var highest = 0;
    for (var i = 0; i < orders.length; i++) {
      if (powers[i] >= config.significantHarmonicRatio * strongest) {
        highest = orders[i];
      }
    }
    final present = orders.where((h) => h <= highest).length;
    var explained = 0.0;
    var total = 0.0;
    for (var k = lo; k <= hi; k++) {
      final p = _spectrum.power(k);
      total += p;
      if (inBand[k - lo]) explained += p;
    }
    if (total == 0) return 0;
    return (explained / total * present / highest).clamp(0.0, 1.0);
  }

  ({double? hz, int count}) _refine(double f0) {
    var weighted = 0.0;
    var weights = 0.0;
    var count = 0;
    for (var h = 1; h <= config.maxHarmonics && h * f0 <= _limitHz; h++) {
      final peak = _peakNear(h * f0);
      if (peak == null) continue;
      final w = math.sqrt(_spectrum.power(peak.bin));
      weighted += w * peak.hz / h;
      weights += w;
      count++;
    }
    return (hz: weights > 0 ? weighted / weights : null, count: count);
  }
}
