import 'dart:math' as math;

import '../../music/pitch_math.dart';
import '../pitch_estimate.dart';
import '../pitch_filter.dart';

/// Proteção **temporal** contra erros de oitava.
///
/// Mantém uma referência (a última frequência aceita). Se uma estimativa
/// nova está a ~±1200 cents da referência (dentro de [toleranceCents] de uma
/// razão exata 2:1 ou 1:2), ela é tratada como erro de oitava do detector e
/// dobrada de volta para a oitava da referência.
///
/// Se a outra oitava persistir continuamente por [confirmDuration], é aceita
/// como mudança real (ex.: harmônico na casa 12) e vira a nova referência.
/// Qualquer estimativa na oitava da referência cancela a confirmação.
///
/// Limitação: sem histórico não há o que proteger. Se a primeira detecção
/// após o silêncio (ou após [memory]) já vier na oitava errada, ela é aceita.
/// A correção dessa situação depende de análise espectral (fase futura).
class OctaveJumpGuard implements PitchFilter {
  OctaveJumpGuard({
    required this.toleranceCents,
    required this.confirmDuration,
    required this.memory,
  });

  final double toleranceCents;
  final Duration confirmDuration;
  final Duration memory;

  double? _referenceHz;
  Duration? _lastSeen;
  int _pendingOctave = 0;
  Duration? _pendingSince;

  /// Frequência de referência atual (para diagnóstico e testes).
  double? get referenceHz => _referenceHz;

  @override
  PitchEstimate? process(PitchEstimate? estimate, Duration timestamp) {
    if (estimate == null) return null;

    final lastSeen = _lastSeen;
    if (lastSeen != null && timestamp - lastSeen > memory) reset();

    final reference = _referenceHz;
    _lastSeen = timestamp;
    if (reference == null) {
      _referenceHz = estimate.frequencyHz;
      return estimate;
    }

    final cents = centsBetween(estimate.frequencyHz, reference);
    final octave = (cents / 1200).round();
    final isOctaveJump =
        octave.abs() == 1 && (cents - octave * 1200).abs() <= toleranceCents;

    if (!isOctaveJump) {
      _clearPending();
      _referenceHz = estimate.frequencyHz;
      return estimate;
    }

    if (_pendingOctave != octave) {
      _pendingOctave = octave;
      _pendingSince = timestamp;
    }
    if (timestamp - _pendingSince! >= confirmDuration) {
      // A outra oitava persistiu: é uma mudança real.
      _clearPending();
      _referenceHz = estimate.frequencyHz;
      return estimate;
    }

    final folded = estimate.frequencyHz / math.pow(2, octave);
    _referenceHz = folded;
    return estimate.copyWith(frequencyHz: folded);
  }

  void _clearPending() {
    _pendingOctave = 0;
    _pendingSince = null;
  }

  @override
  void reset() {
    _referenceHz = null;
    _lastSeen = null;
    _clearPending();
  }
}
