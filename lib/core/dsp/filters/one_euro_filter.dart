import 'dart:math' as math;

/// Filtro passa-baixa adaptativo "1€" (Casiez, Roussel & Vogel, CHI 2012).
///
/// Implementação própria a partir do paper. A frequência de corte cresce
/// com a velocidade do sinal:
///
///     fc = minCutoff + beta · |dx̂|
///
/// Parado → corte baixo (suaviza muito); em movimento → corte alto (pouco
/// atraso). A derivada `dx̂` é ela mesma suavizada com corte fixo
/// [derivativeCutoffHz].
///
/// Cada passo é uma suavização exponencial com
/// `α = 1 / (1 + τ/Te)`, `τ = 1 / (2π·fc)` e `Te` = intervalo real entre
/// amostras (em segundos), o que torna o filtro correto com amostragem
/// irregular.
class OneEuroFilter {
  OneEuroFilter({
    required this.minCutoffHz,
    required this.beta,
    required this.derivativeCutoffHz,
  }) : assert(minCutoffHz > 0 && derivativeCutoffHz > 0 && beta >= 0);

  final double minCutoffHz;
  final double beta;
  final double derivativeCutoffHz;

  double? _value;
  double _derivative = 0;

  /// Último valor filtrado, ou `null` antes da primeira amostra.
  double? get value => _value;

  /// Filtra [x], amostrado [dtSeconds] após a amostra anterior.
  double filter(double x, double dtSeconds) {
    final previous = _value;
    if (previous == null || dtSeconds <= 0) {
      _value = x;
      _derivative = 0;
      return x;
    }
    final rawDerivative = (x - previous) / dtSeconds;
    _derivative +=
        _alpha(derivativeCutoffHz, dtSeconds) * (rawDerivative - _derivative);
    final cutoff = minCutoffHz + beta * _derivative.abs();
    final filtered = previous + _alpha(cutoff, dtSeconds) * (x - previous);
    _value = filtered;
    return filtered;
  }

  void reset() {
    _value = null;
    _derivative = 0;
  }

  static double _alpha(double cutoffHz, double dtSeconds) {
    final tau = 1 / (2 * math.pi * cutoffHz);
    return 1 / (1 + tau / dtSeconds);
  }
}
