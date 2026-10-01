import 'guitar_string.dart';
import 'pitch_math.dart';
import 'string_matcher.dart';
import 'tuning.dart';

/// Associa frequências a cordas com **histerese**: a corda ativa só é
/// trocada quando outra fica mais próxima por pelo menos
/// [switchMarginCents]. Evita que a corda "pisque" quando o pitch está
/// entre duas cordas.
class StringTracker {
  StringTracker({
    required this.tuning,
    required this.switchMarginCents,
    required double maxDeviationCents,
  }) : _matcher = StringMatcher(
         tuning: tuning,
         maxDeviationCents: maxDeviationCents,
       );

  final Tuning tuning;
  final double switchMarginCents;
  final StringMatcher _matcher;

  GuitarString? _current;

  /// Corda ativa, ou `null` antes da primeira detecção / após [reset].
  GuitarString? get current => _current;

  StringMatch? match(double frequencyHz) {
    final nearest = _matcher.match(frequencyHz);
    if (nearest == null) return null;

    final current = _current;
    if (current != null && current != nearest.string) {
      final currentCents = centsBetween(frequencyHz, current.targetFrequency);
      final advantage = currentCents.abs() - nearest.cents.abs();
      if (advantage < switchMarginCents &&
          currentCents.abs() <= _matcher.maxDeviationCents) {
        return StringMatch(string: current, cents: currentCents);
      }
    }
    _current = nearest.string;
    return nearest;
  }

  void reset() => _current = null;
}
