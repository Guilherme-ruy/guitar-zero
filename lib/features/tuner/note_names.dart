import '../../core/music/note.dart';
import '../preferences/tuner_preferences.dart';

/// Nomes de nota conforme a preferência de notação.
extension NoteNamingLabels on NoteNaming {
  /// Nome em destaque.
  String primary(Note note) =>
      this == NoteNaming.solfege ? note.solfegeName : note.name;

  /// Nome secundário (pequeno), só no modo "ambos".
  String? secondary(Note note) =>
      this == NoteNaming.both ? note.solfegeName : null;
}
