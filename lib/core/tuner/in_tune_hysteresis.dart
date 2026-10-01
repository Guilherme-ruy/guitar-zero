import '../music/guitar_string.dart';

/// Estado "afinado" com histerese: entra com |cents| ≤ [enterCents] e só
/// sai com |cents| > [leaveCents]. Evita que o feedback de afinado pisque
/// quando a leitura oscila em torno do limite.
///
/// Trocar de corda reinicia o estado (a nova corda precisa entrar pelo
/// limite mais estrito).
class InTuneHysteresis {
  InTuneHysteresis({required this.enterCents, required this.leaveCents})
    : assert(leaveCents >= enterCents);

  final double enterCents;
  final double leaveCents;

  bool _inTune = false;
  GuitarString? _string;

  bool update(GuitarString string, double cents) {
    if (string != _string) {
      _string = string;
      _inTune = false;
    }
    _inTune = cents.abs() <= (_inTune ? leaveCents : enterCents);
    return _inTune;
  }

  void reset() {
    _inTune = false;
    _string = null;
  }
}
