import 'guitar_string.dart';
import 'pitch_math.dart';
import 'tuning.dart';

/// Resultado da associação de uma frequência a uma corda.
class StringMatch {
  const StringMatch({required this.string, required this.cents});

  final GuitarString string;

  /// Desvio em cents em relação à nota alvo da corda.
  final double cents;
}

/// Determina qual corda de uma [Tuning] uma frequência provavelmente
/// representa, e o desvio em cents.
class StringMatcher {
  const StringMatcher({required this.tuning, this.maxDeviationCents = 350});

  final Tuning tuning;

  /// Frequências mais distantes que isto (em cents) da corda mais próxima são
  /// descartadas, pois provavelmente não vêm de uma corda do instrumento.
  final double maxDeviationCents;

  /// Retorna a corda mais próxima (em escala logarítmica) de [frequency], ou
  /// `null` se nenhuma estiver dentro de [maxDeviationCents].
  StringMatch? match(double frequency) {
    if (!frequency.isFinite || frequency <= 0) return null;

    StringMatch? best;
    for (final string in tuning.strings) {
      final cents = centsBetween(frequency, string.targetFrequency);
      if (best == null || cents.abs() < best.cents.abs()) {
        best = StringMatch(string: string, cents: cents);
      }
    }
    if (best == null || best.cents.abs() > maxDeviationCents) return null;
    return best;
  }
}
