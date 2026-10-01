import 'dart:collection';
import 'dart:math' as math;

import '../../music/pitch_math.dart';
import '../pitch_estimate.dart';
import '../pitch_filter.dart';

/// Só libera estimativas quando as últimas [windowSize] concordam entre si
/// dentro de [toleranceCents] (máx − mín).
///
/// Uma corda tocada mantém pitch estável; fala, ruído e o ataque da
/// palhetada variam. Qualquer `null` (silêncio, baixa confiança) esvazia a
/// janela: a aquisição recomeça do zero.
///
/// Custo: a primeira saída só aparece após [windowSize] estimativas, e um
/// outlier isolado bloqueia a saída enquanto estiver dentro da janela.
class StabilityGate implements PitchFilter {
  StabilityGate({required this.windowSize, required this.toleranceCents})
    : assert(windowSize >= 1);

  final int windowSize;
  final double toleranceCents;

  final Queue<double> _history = Queue<double>();

  @override
  PitchEstimate? process(PitchEstimate? estimate, Duration timestamp) {
    if (estimate == null) {
      _history.clear();
      return null;
    }
    _history.addLast(midiFromFrequency(estimate.frequencyHz) * 100);
    while (_history.length > windowSize) {
      _history.removeFirst();
    }
    if (_history.length < windowSize) return null;

    var lo = double.infinity;
    var hi = double.negativeInfinity;
    for (final c in _history) {
      lo = math.min(lo, c);
      hi = math.max(hi, c);
    }
    return hi - lo <= toleranceCents ? estimate : null;
  }

  @override
  void reset() => _history.clear();
}
