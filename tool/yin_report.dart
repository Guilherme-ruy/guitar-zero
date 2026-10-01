// Relatório de caracterização do YinPitchDetector com sinais sintéticos.
//
// Uso: dart run tool/yin_report.dart
//
// Não é teste: imprime tabelas para análise humana. Os critérios de
// aprovação ficam em test/core/dsp/.
import 'dart:io';
import 'dart:math' as math;

import 'package:guitar_zero/core/dsp/pitch_estimate.dart';
import 'package:guitar_zero/core/dsp/yin_pitch_detector.dart';
import 'package:guitar_zero/core/music/pitch_math.dart';
import 'package:guitar_zero/core/music/tuning.dart';

import '../test/support/synthetic_signals.dart';

const sampleRates = [44100, 48000];
const frameSizes = [4096, 8192];

void main() {
  final detector = YinPitchDetector();
  final strings = Tuning.standard.strings;

  PitchEstimate? run(
    double f,
    int sr,
    int size, {
    List<double> harmonics = const [1],
    double amplitude = 0.5,
    double dc = 0,
  }) => detector.detect(
    SyntheticSignals.frame(
      SyntheticSignals.tone(
        frequencyHz: f,
        sampleRate: sr,
        length: size,
        harmonics: harmonics,
        amplitude: amplitude,
        dcOffset: dc,
      ),
      sr,
    ),
  );

  String fmt(double v, [int d = 3]) => v.toStringAsFixed(d);

  stdout.writeln('== 1. Senoide pura: erro máximo |cents| e confiança mínima');
  stdout.writeln('   (6 cordas × desvios −25/0/+25 cents)');
  for (final sr in sampleRates) {
    for (final size in frameSizes) {
      var maxErr = 0.0;
      var minConf = 1.0;
      var misses = 0;
      for (final s in strings) {
        for (final detune in [-25.0, 0.0, 25.0]) {
          final f = frequencyFromMidi(s.note.midi + detune / 100);
          final e = run(f, sr, size);
          if (e == null) {
            misses++;
            continue;
          }
          maxErr = math.max(maxErr, centsBetween(e.frequencyHz, f).abs());
          minConf = math.min(minConf, e.periodicity);
        }
      }
      stdout.writeln(
        '   $sr Hz / $size: max ${fmt(maxErr, 4)} cents, '
        'conf min ${fmt(minConf, 4)}, sem estimativa: $misses',
      );
    }
  }

  stdout.writeln('\n== 2. Perfis harmônicos (erro em cents vs f0; oitava)');
  const profiles = <String, List<double>>{
    'violão típico [1 .6 .4 .25 .15]': [1.0, 0.6, 0.4, 0.25, 0.15],
    'rico [1 .8 .7 .6 .5 .4 .3 .2]': [1.0, 0.8, 0.7, 0.6, 0.5, 0.4, 0.3, 0.2],
    'H2 dominante [.5 1 .3 .2]': [0.5, 1.0, 0.3, 0.2],
    'H2 dominante [.3 1 .2]': [0.3, 1.0, 0.2],
    'fundamental fraca [.1 1 .6 .4]': [0.1, 1.0, 0.6, 0.4],
    'fundamental fraca [.1 1 .1 .3]': [0.1, 1.0, 0.1, 0.3],
    'só pares [.1 1 0 .5]': [0.1, 1.0, 0.0, 0.5],
    'sem fundamental [0 1 .7 .5]': [0.0, 1.0, 0.7, 0.5],
    'sem fundamental, só pares [0 1 0 .5]': [0.0, 1.0, 0.0, 0.5],
  };
  for (final entry in profiles.entries) {
    stdout.writeln('   ${entry.key}');
    for (final sr in [48000]) {
      for (final size in frameSizes) {
        final cells = <String>[];
        for (final s in strings) {
          final f = s.targetFrequency;
          final e = run(f, sr, size, harmonics: entry.value);
          if (e == null) {
            cells.add('${s.note}: —');
            continue;
          }
          final c = centsBetween(e.frequencyHz, f);
          final oct = (c / 1200).round();
          final tag = oct == 0 ? '' : ' OITAVA${oct > 0 ? '+' : ''}$oct';
          cells.add(
            '${s.note}: ${fmt(c - oct * 1200, 2)}c '
            'conf ${fmt(e.periodicity, 2)}$tag',
          );
        }
        stdout.writeln('     $sr/$size  ${cells.join(' | ')}');
      }
    }
  }

  stdout.writeln(
    '\n== 3. Varredura E2: amplitude da fundamental (H2 = 1, H3 = x) '
    'até ocorrer erro de oitava',
  );
  for (final h3 in [0.0, 0.1, 0.2, 0.4]) {
    for (final size in frameSizes) {
      final f = strings.first.targetFrequency;
      double? threshold;
      for (var a1 = 1.0; a1 >= 0; a1 -= 0.01) {
        final e = run(f, 48000, size, harmonics: [a1, 1, h3, 0.2]);
        if (e == null) continue;
        if ((centsBetween(e.frequencyHz, f) / 1200).round() != 0) {
          threshold = a1;
          break;
        }
      }
      stdout.writeln(
        '   H3=$h3, 48000/$size: oitava errada a partir de a1 ≤ '
        '${threshold == null ? 'nunca' : fmt(threshold, 2)}',
      );
    }
  }

  stdout.writeln('\n== 4. DC offset e amplitude (A2, 48 kHz / 4096)');
  final a2 = strings[1].targetFrequency;
  for (final dc in [0.0, 0.2, 0.5]) {
    for (final amp in [0.9, 0.1, 0.01, 0.006, 0.005]) {
      final e = run(
        a2,
        48000,
        4096,
        amplitude: amp,
        dc: dc,
        harmonics: [1, .5, .3],
      );
      stdout.writeln(
        '   dc $dc amp $amp: '
        '${e == null ? 'sem estimativa' : '${fmt(centsBetween(e.frequencyHz, a2), 4)}c conf ${fmt(e.periodicity)} rms ${fmt(e.rms!, 4)}'}',
      );
    }
  }

  stdout.writeln('\n== 5. Ruído branco (100 sementes por configuração)');
  for (final sr in sampleRates) {
    for (final size in frameSizes) {
      for (final peak in [0.5, 0.02]) {
        var nulls = 0;
        var maxConf = 0.0;
        var confident = 0;
        for (var seed = 1; seed <= 100; seed++) {
          final e = detector.detect(
            SyntheticSignals.frame(
              SyntheticSignals.whiteNoise(length: size, peak: peak, seed: seed),
              sr,
            ),
          );
          if (e == null) {
            nulls++;
          } else {
            maxConf = math.max(maxConf, e.periodicity);
            if (e.periodicity >= 0.9) confident++;
          }
        }
        stdout.writeln(
          '   $sr/$size pico $peak: sem estimativa $nulls, '
          'conf máx ${fmt(maxConf)}, conf ≥ 0.90: $confident',
        );
      }
    }
  }

  stdout.writeln('\n== 5b. Tom + ruído branco (48 kHz / 4096, violão típico)');
  for (final peak in [0.02, 0.05, 0.1, 0.2]) {
    var maxErr = 0.0;
    var minConf = 1.0;
    for (final s in strings) {
      final f = s.targetFrequency;
      final e = detector.detect(
        SyntheticSignals.frame(
          SyntheticSignals.tone(
            frequencyHz: f,
            sampleRate: 48000,
            length: 4096,
            harmonics: const [1, 0.6, 0.4, 0.25],
            noise: peak,
          ),
          48000,
        ),
      );
      if (e == null) continue;
      maxErr = math.max(maxErr, centsBetween(e.frequencyHz, f).abs());
      minConf = math.min(minConf, e.periodicity);
    }
    stdout.writeln(
      '   ruído pico $peak: erro máx ${fmt(maxErr)} cents, conf mín ${fmt(minConf)}',
    );
  }

  stdout.writeln('\n== 6. Silêncio');
  for (final sr in sampleRates) {
    for (final size in frameSizes) {
      final zero = detector.detect(
        SyntheticSignals.frame(
          SyntheticSignals.tone(
            frequencyHz: 100,
            sampleRate: sr,
            length: size,
            amplitude: 0,
          ),
          sr,
        ),
      );
      stdout.writeln('   $sr/$size: ${zero ?? 'sem estimativa'}');
    }
  }

  stdout.writeln(
    '\n== 7. Palhetada com ataque ruidoso (frames com hop de ~10 ms)',
  );
  for (final s in [strings.first, strings[3], strings.last]) {
    for (final size in frameSizes) {
      const sr = 48000;
      final f = s.targetFrequency;
      final signal = SyntheticSignals.pluck(
        frequencyHz: f,
        sampleRate: sr,
        length: size + sr ~/ 10,
      );
      final cells = <String>[];
      for (var offset = 0; offset <= sr ~/ 10; offset += 480) {
        final e = detector.detect(
          SyntheticSignals.frame(signal, sr, offset: offset, length: size),
        );
        cells.add(
          e == null
              ? '—'
              : '${fmt(centsBetween(e.frequencyHz, f), 1)}/${fmt(e.periodicity, 2)}',
        );
      }
      stdout.writeln('   ${s.note} $sr/$size (cents/conf): ${cells.join(' ')}');
    }
  }

  stdout.writeln('\n== 8. Fora da faixa (48 kHz / 4096)');
  for (final f in [40.0, 55.0, 470.0, 500.0, 660.0, 900.0]) {
    final e = run(f, 48000, 4096, harmonics: [1, .5, .3]);
    stdout.writeln(
      '   $f Hz: ${e == null ? 'sem estimativa' : '${fmt(e.frequencyHz, 2)} Hz conf ${fmt(e.periodicity)}'}',
    );
  }
}
