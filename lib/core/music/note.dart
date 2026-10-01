import 'pitch_math.dart';

/// Uma nota musical em temperamento igual, identificada pelo número MIDI.
class Note {
  const Note(this.midi);

  /// Número MIDI da nota (ex.: 40 = E2, 69 = A4).
  final int midi;

  static const List<String> _names = [
    'C',
    'C#',
    'D',
    'D#',
    'E',
    'F',
    'F#',
    'G',
    'G#',
    'A',
    'A#',
    'B',
  ];

  static const List<String> _solfege = [
    'Dó',
    'Dó#',
    'Ré',
    'Ré#',
    'Mi',
    'Fá',
    'Fá#',
    'Sol',
    'Sol#',
    'Lá',
    'Lá#',
    'Si',
  ];

  /// Nome da nota sem oitava, em letras (ex.: `E`, `F#`).
  String get name => _names[midi % 12];

  /// Nome da nota sem oitava, em solfejo (ex.: `Mi`, `Fá#`).
  String get solfegeName => _solfege[midi % 12];

  /// Oitava em notação científica (C4 = dó central).
  int get octave => midi ~/ 12 - 1;

  /// Frequência teórica, em Hz.
  double get frequency => frequencyFromMidi(midi);

  @override
  bool operator ==(Object other) => other is Note && other.midi == midi;

  @override
  int get hashCode => midi.hashCode;

  @override
  String toString() => '$name$octave';
}
