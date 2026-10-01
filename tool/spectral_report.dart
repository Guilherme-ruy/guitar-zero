// Relatório da análise espectral (HarmonicPitchDetector) com sinais
// sintéticos. Uso: dart run tool/spectral_report.dart
//
// Não é teste: imprime tabelas. Critérios em test/core/dsp/.
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:guitar_zero/core/audio/audio_frame.dart';
import 'package:guitar_zero/core/dsp/harmonic_pitch_detector.dart';
import 'package:guitar_zero/core/dsp/pitch_estimate.dart';
import 'package:guitar_zero/core/dsp/yin_pitch_detector.dart';
import 'package:guitar_zero/core/music/pitch_math.dart';
import 'package:guitar_zero/core/music/tuning.dart';

import '../test/support/synthetic_signals.dart';

final strings = Tuning.standard.strings;
final yin = YinPitchDetector();
final harmonic = HarmonicPitchDetector();
const configs = [(44100, 4096), (44100, 8192), (48000, 4096), (48000, 8192)];

AudioFrame frameOf(Float32List s, int sr) => SyntheticSignals.frame(s, sr);

Float32List tone(
  double f,
  int sr,
  int n, {
  List<double> h = const [1],
  double noise = 0,
  int seed = 1,
}) => SyntheticSignals.tone(
  frequencyHz: f,
  sampleRate: sr,
  length: n,
  harmonics: h,
  noise: noise,
  seed: seed,
);

String oct(PitchEstimate? e, double f0) {
  if (e == null) return '—';
  final o = (centsBetween(e.frequencyHz, f0) / 1200).round();
  return o == 0 ? 'ok' : 'OIT${o > 0 ? '+' : ''}$o';
}

String f2(double v, [int d = 2]) => v.toStringAsFixed(d);

void main() {
  stdout.writeln('== 1. Casos de H2 dominante (YIN → harmônico), 6 cordas');
  const profiles = <String, List<double>>{
    '[.1 1 .1 .3]': [0.1, 1, 0.1, 0.3],
    '[.25 1 0 .2]': [0.25, 1, 0, 0.2],
    '[.1 1 0 .5]': [0.1, 1, 0, 0.5],
    '[.05 1 .05 .3]': [0.05, 1, 0.05, 0.3],
    '[.02 1 .02 .3]': [0.02, 1, 0.02, 0.3],
  };
  for (final MapEntry(key: name, value: h) in profiles.entries) {
    for (final (sr, n) in configs) {
      final cells = <String>[];
      for (final s in strings) {
        final f = s.targetFrequency;
        final sig = frameOf(tone(f, sr, n, h: h), sr);
        cells.add(
          '${s.note}:${oct(yin.detect(sig), f)}→${oct(harmonic.detect(sig), f)}',
        );
      }
      stdout.writeln('   $name $sr/$n  ${cells.join(' ')}');
    }
  }

  stdout.writeln('\n== 2. Varredura E2 (H2 = 1): menor a1 corrigido');
  for (final h3 in [0.0, 0.1, 0.2]) {
    for (final (sr, n) in configs) {
      final f = strings.first.targetFrequency;
      final wrongYin = <double>[];
      final stillWrong = <double>[];
      for (var a1 = 0.30; a1 >= 0; a1 -= 0.01) {
        final sig = frameOf(tone(f, sr, n, h: [a1, 1, h3, 0.2]), sr);
        if (oct(yin.detect(sig), f) != 'ok') {
          wrongYin.add(a1);
          if (oct(harmonic.detect(sig), f) != 'ok') stillWrong.add(a1);
        }
      }
      stdout.writeln(
        '   H3=$h3 $sr/$n: YIN erra para a1 ≤ ${wrongYin.isEmpty ? '—' : f2(wrongYin.first)}; '
        'após correção ainda erra em ${stillWrong.length} valores'
        '${stillWrong.isEmpty ? '' : ' (a1 ≤ ${f2(stillWrong.first)})'}',
      );
    }
  }

  stdout.writeln(
    '\n== 3. Falsos positivos (notas corretas não podem mudar de oitava)',
  );
  const okProfiles = <List<double>>[
    [1],
    [1, 0.6, 0.4, 0.25, 0.15],
    [1, 0.8, 0.7, 0.6, 0.5, 0.4, 0.3, 0.2],
    [0.5, 1, 0.3, 0.2],
    [0.1, 1, 0.6, 0.4],
    [0, 1, 0.7, 0.5],
  ];
  var checked = 0;
  var changed = 0;
  for (final h in okProfiles) {
    for (final (sr, n) in configs) {
      for (final s in strings) {
        for (final detune in [-25.0, 0.0, 25.0]) {
          final f = frequencyFromMidi(s.note.midi + detune / 100);
          checked++;
          if (oct(harmonic.detect(frameOf(tone(f, sr, n, h: h), sr)), f) !=
              'ok') {
            changed++;
          }
        }
      }
    }
  }
  stdout.writeln('   $changed/$checked casos mudaram de oitava');
  // Ressonância simpática: D3 tocada, A2 e E2 vibrando junto (fracas).
  for (final (sr, n) in configs) {
    final d3 = strings[2].targetFrequency;
    final comps = <({double hz, double amplitude})>[
      for (var h = 1; h <= 6; h++) (hz: d3 * h, amplitude: 1 / h),
      for (var h = 1; h <= 6; h++)
        (hz: strings[1].targetFrequency * h, amplitude: 0.15 / h),
      for (var h = 1; h <= 6; h++)
        (hz: strings[0].targetFrequency * h, amplitude: 0.1 / h),
    ];
    final sig = frameOf(
      SyntheticSignals.partials(components: comps, sampleRate: sr, length: n),
      sr,
    );
    stdout.writeln(
      '   D3 + A2/E2 simpáticas $sr/$n: YIN ${oct(yin.detect(sig), d3)}, '
      'harmônico ${oct(harmonic.detect(sig), d3)} '
      '(${harmonic.lastAnalysis?.correction.name})',
    );
  }

  stdout.writeln('\n== 4. Acima da faixa (YIN reporta sub-harmônico)');
  for (final hz in [470.0, 500.0, 660.0, 900.0]) {
    for (final h in [
      [1.0],
      [1.0, 0.5, 0.3],
    ]) {
      final sig = frameOf(tone(hz, 48000, 4096, h: h), 48000);
      final y = yin.detect(sig);
      final r = harmonic.detect(sig);
      stdout.writeln(
        '   $hz Hz h=$h: YIN ${y == null ? '—' : '${f2(y.frequencyHz)} Hz'}, '
        'harmônico ${r == null ? 'rejeitado' : '${f2(r.frequencyHz)} Hz'} '
        '(${harmonic.lastAnalysis?.correction.name ?? 'sem análise'})',
      );
    }
  }

  stdout.writeln(
    '\n== 5. Precisão: YIN vs refinamento espectral (erro máx |cents|)',
  );
  final refined = harmonic;
  for (final (label, h, noise) in [
    ('violão típico, limpo', [1.0, 0.6, 0.4, 0.25, 0.15], 0.0),
    ('rico, limpo', [1.0, 0.8, 0.7, 0.6, 0.5, 0.4, 0.3, 0.2], 0.0),
    ('violão típico, ruído 0.1', [1.0, 0.6, 0.4, 0.25, 0.15], 0.1),
    ('violão típico, ruído 0.2', [1.0, 0.6, 0.4, 0.25, 0.15], 0.2),
  ]) {
    for (final (sr, n) in configs) {
      var eY = 0.0;
      var eR = 0.0;
      for (final s in strings) {
        for (final detune in [-25.0, 0.0, 25.0]) {
          for (var seed = 1; seed <= (noise > 0 ? 10 : 1); seed++) {
            final f = frequencyFromMidi(s.note.midi + detune / 100);
            final sig = frameOf(
              tone(f, sr, n, h: h, noise: noise, seed: seed),
              sr,
            );
            final y = yin.detect(sig);
            final r = refined.detect(sig);
            if (y != null) {
              eY = math.max(eY, centsBetween(y.frequencyHz, f).abs());
            }
            if (r != null) {
              eR = math.max(eR, centsBetween(r.frequencyHz, f).abs());
            }
          }
        }
      }
      stdout.writeln(
        '   $label $sr/$n: YIN ${f2(eY, 3)}c, refinado ${f2(eR, 3)}c',
      );
    }
  }

  stdout.writeln(
    '\n== 5b. Inarmonicidade (f_h = h·f0·√(1+B·h²)), 10 harmônicos: '
    'erro vs f0 (cents)',
  );
  for (final b in [1e-4, 3e-4, 1e-3]) {
    for (final (sr, n) in [(48000, 4096), (48000, 8192)]) {
      var eY = 0.0;
      var eR = 0.0;
      for (final s in strings) {
        final f = s.targetFrequency;
        final sig = frameOf(
          SyntheticSignals.tone(
            frequencyHz: f,
            sampleRate: sr,
            length: n,
            harmonics: const [1, .7, .5, .4, .3, .25, .2, .15, .1, .08],
            inharmonicity: b,
          ),
          sr,
        );
        final y = centsBetween(yin.detect(sig)!.frequencyHz, f);
        final r = centsBetween(harmonic.detect(sig)!.frequencyHz, f);
        if (y.abs() > eY.abs()) eY = y;
        if (r.abs() > eR.abs()) eR = r;
      }
      stdout.writeln(
        '   B=$b $sr/$n: YIN ${f2(eY)}c, refinado ${f2(eR)}c (pior corda)',
      );
    }
  }

  stdout.writeln('\n== 6. Harmonicidade (média [mín–máx] nas 6 cordas)');
  void harmonicityRow(
    String label,
    Float32List Function(double f, int sr, int n) gen,
  ) {
    for (final (sr, n) in [(48000, 4096), (48000, 8192)]) {
      final values = <double>[];
      var nulls = 0;
      for (final s in strings) {
        final e = harmonic.detect(frameOf(gen(s.targetFrequency, sr, n), sr));
        if (e?.harmonicity == null) {
          nulls++;
        } else {
          values.add(e!.harmonicity!);
        }
      }
      final mean = values.isEmpty
          ? double.nan
          : values.reduce((a, b) => a + b) / values.length;
      stdout.writeln(
        '   $label $sr/$n: ${values.isEmpty ? '—' : '${f2(mean)} [${f2(values.reduce(math.min))}–${f2(values.reduce(math.max))}]'}'
        '${nulls > 0 ? ' (sem estimativa: $nulls)' : ''}',
      );
    }
  }

  harmonicityRow('senoide pura', tone);
  harmonicityRow(
    'corda rica',
    (f, sr, n) => tone(f, sr, n, h: [1, .8, .7, .6, .5, .4, .3, .2]),
  );
  harmonicityRow(
    'fundamental fraca',
    (f, sr, n) => tone(f, sr, n, h: [.1, 1, .6, .4]),
  );
  harmonicityRow(
    'fundamental ausente',
    (f, sr, n) => tone(f, sr, n, h: [0, 1, .7, .5]),
  );
  harmonicityRow(
    'H2 dominante [.1 1 .1 .3]',
    (f, sr, n) => tone(f, sr, n, h: [.1, 1, .1, .3]),
  );
  harmonicityRow(
    'corda + ruído 0.1',
    (f, sr, n) => tone(f, sr, n, h: [1, .6, .4, .25], noise: .1),
  );
  harmonicityRow(
    'corda + ruído 0.2',
    (f, sr, n) => tone(f, sr, n, h: [1, .6, .4, .25], noise: .2),
  );
  harmonicityRow(
    'parciais inarmônicos (f, 1.37f, 2.21f, 3.53f)',
    (f, sr, n) => SyntheticSignals.partials(
      components: [
        (hz: f, amplitude: 1),
        (hz: f * 1.37, amplitude: .8),
        (hz: f * 2.21, amplitude: .6),
        (hz: f * 3.53, amplitude: .5),
      ],
      sampleRate: sr,
      length: n,
    ),
  );
  harmonicityRow(
    'mistura: corda + outra corda a 1 trítono (×1.414)',
    (f, sr, n) => SyntheticSignals.partials(
      components: [
        for (var h = 1; h <= 5; h++) (hz: f * h, amplitude: 1 / h),
        for (var h = 1; h <= 5; h++) (hz: f * 1.4142 * h, amplitude: 0.8 / h),
      ],
      sampleRate: sr,
      length: n,
    ),
  );
  for (final speed in [150.0, 600.0, 2000.0]) {
    harmonicityRow(
      'glissando $speed c/s',
      (f, sr, n) => SyntheticSignals.glide(
        startHz: f,
        centsPerSecond: speed,
        sampleRate: sr,
        length: n,
      ),
    );
  }

  stdout.writeln('\n== 7. Ruído branco (100 sementes)');
  for (final (sr, n) in configs) {
    final values = <double>[];
    var nulls = 0;
    for (var seed = 1; seed <= 100; seed++) {
      final e = harmonic.detect(
        frameOf(SyntheticSignals.whiteNoise(length: n, seed: seed), sr),
      );
      if (e?.harmonicity == null) {
        nulls++;
      } else {
        values.add(e!.harmonicity!);
      }
    }
    final sorted = [...values]..sort();
    stdout.writeln(
      '   $sr/$n: harmonicidade mediana ${values.isEmpty ? '—' : f2(sorted[sorted.length ~/ 2])}, '
      'máx ${values.isEmpty ? '—' : f2(sorted.last)}, sem estimativa $nulls',
    );
  }

  stdout.writeln('\n== 8. Robustez a ruído da correção (20 sementes)');
  for (final noise in [0.05, 0.1, 0.2]) {
    for (final (sr, n) in [(48000, 4096), (48000, 8192)]) {
      var fixed = 0;
      var total = 0;
      var falsePos = 0;
      var totalOk = 0;
      for (final s in strings.take(4)) {
        final f = s.targetFrequency;
        for (var seed = 1; seed <= 20; seed++) {
          final bad = frameOf(
            tone(f, sr, n, h: [.1, 1, .1, .3], noise: noise, seed: seed),
            sr,
          );
          final r = harmonic.detect(bad);
          if (r != null) {
            total++;
            if (oct(r, f) == 'ok') fixed++;
          }
          final good = frameOf(
            tone(f, sr, n, h: [1, .6, .4, .25], noise: noise, seed: seed),
            sr,
          );
          final g = harmonic.detect(good);
          if (g != null) {
            totalOk++;
            if (oct(g, f) != 'ok') falsePos++;
          }
        }
      }
      stdout.writeln(
        '   ruído $noise $sr/$n: H2 dominante corrigido $fixed/$total; '
        'notas normais com oitava trocada $falsePos/$totalOk',
      );
    }
  }
}
