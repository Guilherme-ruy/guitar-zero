// Avaliação do DSP com gravações reais (NSynth, CC BY 4.0) — fora do CI.
//
// Uso:
//   dart run tool/real_audio_eval.dart <dir_wav_44k> <selected.json>
//
// <dir_wav_44k>: WAVs PCM16 mono 44.1 kHz (NSynth reamostrado com ffmpeg).
// <selected.json>: {nome: {pitch, instrument, source}} (MIDI esperado).
// Ver docs/DSP_STRATEGY.md, "Avaliação com gravações reais".
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:guitar_zero/core/audio/pcm_framer.dart';
import 'package:guitar_zero/core/dsp/harmonic_pitch_detector.dart';
import 'package:guitar_zero/core/dsp/yin_pitch_detector.dart';
import 'package:guitar_zero/core/music/pitch_math.dart';
import 'package:guitar_zero/core/music/tuning.dart';
import 'package:guitar_zero/core/tuner/tuner_config.dart';
import 'package:guitar_zero/core/tuner/tuner_pipeline.dart';
import 'package:guitar_zero/core/tuner/tuner_reading.dart';

import '../test/support/wav.dart';

String f1(double v) => v.isNaN ? '—' : v.toStringAsFixed(1);
String f2(double v) => v.isNaN ? '—' : v.toStringAsFixed(2);

double percentile(List<double> values, double p) {
  if (values.isEmpty) return double.nan;
  final s = [...values]..sort();
  return s[((s.length - 1) * p).round()];
}

void main(List<String> args) {
  final dir = Directory(args[0]);
  final meta = (jsonDecode(File(args[1]).readAsStringSync()) as Map)
      .cast<String, Map<String, dynamic>>();
  const config = TunerConfig();
  const sampleRate = 44100;
  final openMidis = Tuning.standard.strings.map((s) => s.note.midi).toSet();

  var yinFrames = 0;
  var yinOctaveErrors = 0;
  var harmonicFrames = 0;
  var harmonicOctaveErrors = 0;
  var harmonicNoteErrors = 0;
  var yinRejectedByGate = 0;
  final periodicity = <double>[];
  final harmonicity = <double>[];
  final firstReadingMs = <double>[];
  var notesWithoutReading = 0;
  var notesWithWrongOctaveShown = 0;
  final openRows = <String>[];
  final sustainP2p = <double>[];
  final sustainStd = <double>[];
  final refinedVsYin = <double>[];

  final names = meta.keys.toList()..sort();
  for (final name in names) {
    final info = meta[name]!;
    final midi = info['pitch'] as int;
    final target = frequencyFromMidi(midi);
    final pcm = readWavPcm16(File('${dir.path}/$name.wav'));
    final frames = PcmFramer(
      sampleRate: sampleRate,
      frameSize: 4096,
      hopSize: 1764,
    ).addPcm16(pcm);

    final yin = YinPitchDetector();
    final harmonic = HarmonicPitchDetector();
    final pipeline = TunerPipeline();
    final shown = <({double t, TunerReading r})>[];

    for (final frame in frames) {
      final y = yin.detect(frame);
      if (y != null) {
        if (y.periodicity >= config.minConfidence) {
          yinFrames++;
          if ((centsBetween(y.frequencyHz, target) / 1200).round() != 0) {
            yinOctaveErrors++;
          }
        } else {
          yinRejectedByGate++;
        }
      }
      final h = harmonic.detect(frame);
      if (h != null && h.periodicity >= config.minConfidence) {
        harmonicFrames++;
        final c = centsBetween(h.frequencyHz, target);
        if ((c / 1200).round() != 0) {
          harmonicOctaveErrors++;
        } else if (c.abs() > 50) {
          harmonicNoteErrors++;
        }
        periodicity.add(h.periodicity);
        if (h.harmonicity != null) harmonicity.add(h.harmonicity!);
        if (y != null && (c / 1200).round() == 0) {
          refinedVsYin.add(
            centsBetween(h.frequencyHz, y.frequencyHz) -
                1200 * (centsBetween(y.frequencyHz, target) / 1200).round(),
          );
        }
      }
      final r = pipeline.process(h, frame.timestamp);
      if (r != null && !r.isHeld) {
        shown.add((t: frame.timestamp.inMicroseconds / 1000, r: r));
      }
    }

    if (shown.isEmpty) {
      notesWithoutReading++;
    } else {
      firstReadingMs.add(shown.first.t);
      if (shown.any(
        (s) => (centsBetween(s.r.frequency, target) / 1200).round() != 0,
      )) {
        notesWithWrongOctaveShown++;
      }
    }

    if (openMidis.contains(midi)) {
      final sustain = shown
          .where((s) => s.t >= 300 && s.t <= 2500)
          .map((s) => centsBetween(s.r.frequency, target))
          .toList();
      final mean = sustain.isEmpty
          ? double.nan
          : sustain.reduce((a, b) => a + b) / sustain.length;
      final p2p = sustain.isEmpty
          ? double.nan
          : sustain.reduce(math.max) - sustain.reduce(math.min);
      final std = sustain.isEmpty
          ? double.nan
          : math.sqrt(
              sustain
                      .map((c) => (c - mean) * (c - mean))
                      .reduce((a, b) => a + b) /
                  sustain.length,
            );
      if (!p2p.isNaN) {
        sustainP2p.add(p2p);
        sustainStd.add(std);
      }
      final strings = shown.map((s) => s.r.string.note.toString()).toSet();
      final lastMs = shown.isEmpty ? double.nan : shown.last.t;
      openRows.add(
        '${noteName(midi).padRight(3)} ${name.padRight(30)} '
        '1ª leitura ${f1(shown.isEmpty ? double.nan : shown.first.t).padLeft(6)} ms, '
        'até ${f1(lastMs).padLeft(6)} ms, '
        'desvio médio ${f1(mean).padLeft(6)} c, p2p ${f2(p2p).padLeft(5)} c, '
        'cordas $strings',
      );
    }
  }

  stdout.writeln(
    '== Notas: ${names.length} (MIDI 38–66, guitar acoustic/electronic)',
  );
  stdout.writeln('\n== Por frame (periodicidade ≥ ${config.minConfidence})');
  stdout.writeln(
    'YIN isolado: $yinFrames frames, erros de oitava $yinOctaveErrors '
    '(${f2(100 * yinOctaveErrors / yinFrames)}%); '
    'frames com estimativa abaixo do gate: $yinRejectedByGate',
  );
  stdout.writeln(
    'Harmônico: $harmonicFrames frames, erros de oitava $harmonicOctaveErrors '
    '(${f2(100 * harmonicOctaveErrors / harmonicFrames)}%), '
    'nota errada (> 50 c) $harmonicNoteErrors',
  );
  stdout.writeln(
    'periodicidade p5/p50: ${f2(percentile(periodicity, .05))}/${f2(percentile(periodicity, .5))}; '
    'harmonicidade p5/p25/p50: ${f2(percentile(harmonicity, .05))}/'
    '${f2(percentile(harmonicity, .25))}/${f2(percentile(harmonicity, .5))}',
  );
  stdout.writeln(
    'refinado − YIN (cents) p5/p50/p95: ${f2(percentile(refinedVsYin, .05))}/'
    '${f2(percentile(refinedVsYin, .5))}/${f2(percentile(refinedVsYin, .95))}',
  );
  stdout.writeln('\n== Pipeline completo (o que a tela mostraria)');
  stdout.writeln(
    'notas sem nenhuma leitura: $notesWithoutReading; '
    'notas que exibiram oitava errada em algum momento: $notesWithWrongOctaveShown',
  );
  stdout.writeln(
    '1ª leitura (ms desde o início do arquivo) p50/p90/máx: '
    '${f1(percentile(firstReadingMs, .5))}/${f1(percentile(firstReadingMs, .9))}/'
    '${f1(percentile(firstReadingMs, 1))}',
  );
  stdout.writeln(
    '\n== Cordas soltas (${openRows.length} notas): sustentação 0.3–2.5 s',
  );
  openRows.forEach(stdout.writeln);
  stdout.writeln(
    'p2p da leitura exibida p50/p90/máx: ${f2(percentile(sustainP2p, .5))}/'
    '${f2(percentile(sustainP2p, .9))}/${f2(percentile(sustainP2p, 1))} c; '
    'desvio-padrão p50/máx: ${f2(percentile(sustainStd, .5))}/${f2(percentile(sustainStd, 1))} c',
  );
}

String noteName(int midi) {
  const names = [
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
  return '${names[midi % 12]}${midi ~/ 12 - 1}';
}
