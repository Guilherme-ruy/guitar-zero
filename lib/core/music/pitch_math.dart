import 'dart:math' as math;

/// Frequência de referência do Lá central (A4), em Hz.
const double kA4Frequency = 440.0;

/// Número MIDI do A4.
const int kA4Midi = 69;

/// Diferença em cents entre [frequency] e [reference].
///
/// Valores negativos indicam que [frequency] está abaixo (bemol) da
/// referência; positivos, acima (sustenido). 100 cents = 1 semitom.
double centsBetween(double frequency, double reference) {
  assert(frequency > 0 && reference > 0, 'Frequências devem ser positivas.');
  return 1200 * math.log(frequency / reference) / math.ln2;
}

/// Número MIDI (fracionário) correspondente a [frequency], em temperamento
/// igual com A4 = [kA4Frequency].
double midiFromFrequency(double frequency) =>
    kA4Midi + centsBetween(frequency, kA4Frequency) / 100;

/// Frequência, em Hz, da nota MIDI [midi] em temperamento igual.
double frequencyFromMidi(num midi) =>
    kA4Frequency * math.pow(2, (midi - kA4Midi) / 12).toDouble();

/// Desvio em cents de [frequency] em relação a [reference], ignorando a
/// oitava: resultado em (−600, 600].
double octaveFoldedCents(double frequency, double reference) {
  final cents = centsBetween(frequency, reference);
  final folded = cents - 1200 * (cents / 1200).round();
  // Meio-oitava exata (com erro de arredondamento) vai para +600.
  return folded <= -600 + 1e-9 ? 600 : folded;
}
