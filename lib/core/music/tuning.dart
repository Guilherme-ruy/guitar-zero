import 'guitar_string.dart';
import 'note.dart';

/// Uma afinação: conjunto de cordas e suas notas alvo.
class Tuning {
  const Tuning({required this.name, required this.strings});

  /// Nome exibido da afinação.
  final String name;

  /// Cordas ordenadas da mais grave para a mais aguda.
  final List<GuitarString> strings;

  /// Afinação padrão (E2 A2 D3 G3 B3 E4) para guitarra e violão de 6 cordas.
  ///
  /// Frequências: 82.41, 110.00, 146.83, 196.00, 246.94 e 329.63 Hz.
  static const Tuning standard = Tuning(
    name: 'Standard',
    strings: [
      GuitarString(number: 6, note: Note(40)), // E2
      GuitarString(number: 5, note: Note(45)), // A2
      GuitarString(number: 4, note: Note(50)), // D3
      GuitarString(number: 3, note: Note(55)), // G3
      GuitarString(number: 2, note: Note(59)), // B3
      GuitarString(number: 1, note: Note(64)), // E4
    ],
  );
}
