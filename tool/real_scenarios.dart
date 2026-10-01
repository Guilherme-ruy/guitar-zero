// Cenários com gravações reais misturadas (fora do CI):
// troca de corda com a anterior ainda soando, cordas simpáticas e ruído.
//
// Uso: dart run tool/real_scenarios.dart
import 'dart:io';

import 'package:guitar_zero/core/music/pitch_math.dart';

import '../test/support/real_audio.dart';

void main() {
  final notes = {for (final n in realFixtures.keys) n: loadRealNote(n)};

  stdout.writeln(
    '== Troca de corda com a anterior ainda soando (nova em 1.5 s)',
  );
  for (final (from, to) in [
    ('E2', 'B3'),
    ('A2', 'E4'),
    ('E2', 'A2'),
    ('D3', 'G3'),
    ('B3', 'E2'),
    ('E4', 'A2'),
  ]) {
    for (final gainNew in [1.0, 0.5, 0.25]) {
      final shown = runRealPipeline(
        mix([
          (samples: notes[from]!, startSeconds: 0, gain: 1),
          (samples: notes[to]!, startSeconds: 1.5, gain: gainNew),
        ], seconds: 3.5),
      );
      final firstNew = shown.where(
        (s) => s.ms > 1500 && s.reading.string.note.toString() == to,
      );
      final latency = firstNew.isEmpty ? null : firstNew.first.ms - 1500;
      final others = shown
          .where((s) => s.ms > 1500 + (latency ?? 0))
          .map((s) => s.reading.string.note.toString())
          .where((n) => n != to)
          .toSet();
      stdout.writeln(
        '   $from → $to (nova a ${(gainNew * 100).round()}%): '
        '${latency == null ? 'NUNCA aparece' : 'aparece em $latency ms'}'
        '${others.isEmpty ? '' : '; depois ainda mostra $others'}',
      );
    }
  }

  stdout.writeln(
    '\n== Corda tocada com outra soando por baixo (desde o início)',
  );
  for (final (main, under) in [('B3', 'E2'), ('E4', 'A2'), ('D3', 'A2')]) {
    for (final gainUnder in [0.1, 0.3]) {
      final shown = runRealPipeline(
        mix([
          (samples: notes[main]!, startSeconds: 0, gain: 1),
          (samples: notes[under]!, startSeconds: 0, gain: gainUnder),
        ], seconds: 3),
      );
      final names = shown.map((s) => s.reading.string.note.toString()).toSet();
      stdout.writeln(
        '   $main + $under a ${(gainUnder * 100).round()}%: cordas exibidas $names',
      );
    }
  }

  stdout.writeln('\n== Ruído branco (SNR sobre o RMS da nota inteira)');
  for (final snr in [30.0, 20.0, 10.0, 5.0]) {
    final cells = <String>[];
    for (final note in realFixtures.keys) {
      final target = frequencyFromMidi(
        int.parse(realFixtures[note]!.split('-')[1]),
      );
      final shown = runRealPipeline(
        mix(
          [(samples: notes[note]!, startSeconds: 0, gain: 1)],
          seconds: 3,
          snrDb: snr,
        ),
      );
      final wrong = shown
          .where(
            (s) =>
                s.reading.string.note.toString() != note ||
                (centsBetween(s.reading.frequency, target) / 1200).round() != 0,
          )
          .length;
      final live = shown.where((s) => !s.reading.isHeld).length;
      cells.add(
        '$note ${shown.isEmpty ? '—' : '${shown.first.ms}ms'}'
        ' vivas $live${wrong > 0 ? ' ERRADAS $wrong' : ''}',
      );
    }
    stdout.writeln('   SNR $snr dB: ${cells.join(' | ')}');
  }
}
