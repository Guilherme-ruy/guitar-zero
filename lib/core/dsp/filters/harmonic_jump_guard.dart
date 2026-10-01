import 'dart:collection';
import 'dart:math' as math;

import '../../music/pitch_math.dart';
import '../pitch_estimate.dart';
import '../pitch_filter.dart';

/// Proteção **temporal** contra saltos harmônicos do detector: oitava (×2) e
/// décima segunda (×3), para cima ou para baixo.
///
/// Mantém uma referência (a última frequência aceita). Uma estimativa a
/// ±1200 ou ±1902 cents da referência (dentro de [toleranceCents]) é tratada
/// como erro do detector — por exemplo, o fim de uma nota grave em que a
/// fundamental morre antes do 3º harmônico — e dobrada de volta para a
/// referência, **a menos que haja um ataque**: RMS ≥ [onsetThresholdDb]
/// acima do mínimo em [onsetWindow]. Um ataque indica corda tocada de novo.
///
/// Isso é necessário porque, na afinação Standard, E2→B3 e A2→E4 são
/// exatamente intervalos ×3: só o ataque distingue "toquei a corda B3" de
/// "o detector pegou o H3 do E2".
///
/// Sem ataque, um salto que persista por [confirmDuration] também é aceito.
/// Estimativas sem RMS (`rms == null`) nunca contam como ataque.
///
/// Limitação: sem histórico (após silêncio > [memory]) não há o que
/// proteger; esse caso é tratado pela análise espectral do detector.
class HarmonicJumpGuard implements PitchFilter {
  HarmonicJumpGuard({
    required this.toleranceCents,
    required this.confirmDuration,
    required this.memory,
    required this.onsetThresholdDb,
    required this.onsetWindow,
  });

  final double toleranceCents;
  final Duration confirmDuration;
  final Duration memory;
  final double onsetThresholdDb;
  final Duration onsetWindow;

  static const List<double> _ratios = [2, 3];

  double? _referenceHz;
  Duration? _lastSeen;
  double _pendingFactor = 1;
  Duration? _pendingSince;
  final Queue<({Duration t, double rms})> _recentRms = Queue();

  /// Frequência de referência atual (para diagnóstico e testes).
  double? get referenceHz => _referenceHz;

  @override
  PitchEstimate? process(PitchEstimate? estimate, Duration timestamp) {
    if (estimate == null) return null;

    final lastSeen = _lastSeen;
    if (lastSeen != null && timestamp - lastSeen > memory) reset();
    _lastSeen = timestamp;

    final onset = _isOnset(estimate.rms, timestamp);
    final reference = _referenceHz;
    if (reference == null) {
      _referenceHz = estimate.frequencyHz;
      return estimate;
    }

    final factor = _jumpFactor(centsBetween(estimate.frequencyHz, reference));
    if (factor == null || onset) {
      _clearPending();
      _referenceHz = estimate.frequencyHz;
      return estimate;
    }

    if (_pendingFactor != factor) {
      _pendingFactor = factor;
      _pendingSince = timestamp;
    }
    if (timestamp - _pendingSince! >= confirmDuration) {
      // O salto persistiu: é uma mudança real.
      _clearPending();
      _referenceHz = estimate.frequencyHz;
      return estimate;
    }

    final folded = estimate.frequencyHz / factor;
    _referenceHz = folded;
    return estimate.copyWith(frequencyHz: folded);
  }

  /// Fator (2, 3, 1/2 ou 1/3) se [cents] é um salto harmônico; senão null.
  double? _jumpFactor(double cents) {
    for (final ratio in _ratios) {
      final interval = 1200 * math.log(ratio) / math.ln2;
      if ((cents - interval).abs() <= toleranceCents) return ratio;
      if ((cents + interval).abs() <= toleranceCents) return 1 / ratio;
    }
    return null;
  }

  bool _isOnset(double? rms, Duration timestamp) {
    if (rms == null) return false;
    while (_recentRms.isNotEmpty &&
        timestamp - _recentRms.first.t > onsetWindow) {
      _recentRms.removeFirst();
    }
    var minimum = double.infinity;
    for (final r in _recentRms) {
      minimum = math.min(minimum, r.rms);
    }
    _recentRms.addLast((t: timestamp, rms: rms));
    if (minimum == double.infinity || minimum <= 0) return false;
    return 20 * math.log(rms / minimum) / math.ln10 >= onsetThresholdDb;
  }

  void _clearPending() {
    _pendingFactor = 1;
    _pendingSince = null;
  }

  @override
  void reset() {
    _referenceHz = null;
    _lastSeen = null;
    _recentRms.clear();
    _clearPending();
  }
}
