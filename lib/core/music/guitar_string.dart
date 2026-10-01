import 'note.dart';

/// Uma corda do instrumento e a nota em que deve ser afinada.
class GuitarString {
  const GuitarString({required this.number, required this.note});

  /// Numeração tradicional: 1 = corda mais aguda, 6 = corda mais grave.
  final int number;

  /// Nota alvo da corda na afinação atual.
  final Note note;

  /// Frequência alvo, em Hz.
  double get targetFrequency => note.frequency;

  @override
  bool operator ==(Object other) =>
      other is GuitarString && other.number == number && other.note == note;

  @override
  int get hashCode => Object.hash(number, note);

  @override
  String toString() => 'GuitarString($number, $note)';
}
