// Relatório do pipeline temporal (TunerPipeline) com sequências sintéticas.
//
// Uso: dart run tool/temporal_report.dart
//
// Compara stabilityWindow 3 e 5 em aquisição, outliers, giro de tarraxa,
// fala e jitter. Não é teste; os critérios ficam em test/core/tuner/.
import 'dart:io';
import 'dart:math' as math;

import 'package:guitar_zero/core/music/tuning.dart';
import 'package:guitar_zero/core/tuner/tuner_config.dart';
import 'package:guitar_zero/core/tuner/tuner_pipeline.dart';
import 'package:guitar_zero/core/tuner/tuner_reading.dart';

import '../test/support/pitch_sequences.dart';

void main() {
  final a2 = Tuning.standard.strings[1].targetFrequency;
  const hopMs = 40;

  for (final window in [3, 5]) {
    final config = TunerConfig(stabilityWindow: window);
    TunerPipeline fresh() => TunerPipeline(config: config);
    String ms(int frames) => '${frames * hopMs} ms';

    stdout.writeln('\n===== stabilityWindow = $window =====');

    // Aquisição.
    var b = PitchSequenceBuilder()..note(a2, 20);
    var out = runPipeline(fresh(), b.build());
    final first = out.indexWhere((r) => r != null);
    stdout.writeln(
      'aquisição: 1ª leitura no frame $first (${ms(first)} após a 1ª '
      'estimativa; + janela de análise)',
    );

    // Outlier único.
    b = PitchSequenceBuilder()
      ..note(a2, 15)
      ..note(a2, 1, cents: 80)
      ..note(a2, 15);
    out = runPipeline(fresh(), b.build());
    final held = out.skip(15).takeWhile((r) => r!.isHeld).length;
    final maxDev = out
        .whereType<TunerReading>()
        .map((r) => r.cents.abs())
        .reduce(math.max);
    stdout.writeln(
      'outlier +80c: leitura congelada (hold) por $held frames '
      '(${ms(held)}); desvio máx exibido ${maxDev.toStringAsFixed(2)}c',
    );

    // Giro de tarraxa em várias velocidades: -60 → +60 cents.
    for (final speed in [20, 50, 100, 200, 400]) {
      final steps = (120 / speed * 1000 / hopMs).round() + 1;
      b = PitchSequenceBuilder()
        ..note(a2, 10, cents: -60)
        ..ramp(a2, steps, fromCents: -60, toCents: 60)
        ..note(a2, 25, cents: 60);
      out = runPipeline(fresh(), b.build());
      final during = out.sublist(10, 10 + steps);
      final live = during.where((r) => r != null && !r.isHeld).length;
      // Atraso médio da leitura viva em relação ao valor real.
      var lagSum = 0.0;
      var lagN = 0;
      for (var i = 0; i < steps; i++) {
        final r = during[i];
        if (r == null || r.isHeld) continue;
        lagSum += (-60 + 120 * i / (steps - 1)) - r.cents;
        lagN++;
      }
      final end = out.last!.cents;
      stdout.writeln(
        'tarraxa $speed c/s: leituras vivas $live/$steps, '
        'atraso médio ${lagN == 0 ? '—' : (lagSum / lagN).toStringAsFixed(1)}c, '
        'final ${end.toStringAsFixed(2)}c',
      );
    }

    // Ruído (frequências aleatórias) e fala (glissandos).
    var accepted = 0;
    b = PitchSequenceBuilder(seed: 11)..randomFrequencies(2000);
    out = runPipeline(fresh(), b.build());
    accepted = out.where((r) => r != null && !r.isHeld).length;
    stdout.writeln('ruído aleatório: $accepted/2000 frames aceitos');
    for (final speed in [150, 300, 600]) {
      b = PitchSequenceBuilder(seed: 12)
        ..speechLike(2000, maxCentsPerSecond: speed.toDouble());
      out = runPipeline(fresh(), b.build());
      accepted = out.where((r) => r != null && !r.isHeld).length;
      stdout.writeln(
        'fala (até $speed c/s): $accepted/2000 frames aceitos '
        '(${(accepted / 20).toStringAsFixed(1)}%)',
      );
    }

    // Jitter.
    for (final jitter in [1.0, 3.0, 10.0]) {
      b = PitchSequenceBuilder(seed: 5)..note(a2, 200, jitterCents: jitter);
      out = runPipeline(fresh(), b.build());
      final settled = out
          .skip(25)
          .whereType<TunerReading>()
          .where((r) => !r.isHeld)
          .map((r) => r.cents)
          .toList();
      final inHeld = out.skip(25).where((r) => r != null && r.isHeld).length;
      final p2p = settled.isEmpty
          ? double.nan
          : settled.reduce(math.max) - settled.reduce(math.min);
      final mean = settled.isEmpty
          ? double.nan
          : settled.reduce((a, b) => a + b) / settled.length;
      var transitions = 0;
      for (var i = 26; i < out.length; i++) {
        if (out[i]?.isInTune != out[i - 1]?.isInTune) transitions++;
      }
      stdout.writeln(
        'jitter ±${jitter.toInt()}c: saída p2p ${p2p.toStringAsFixed(2)}c '
        '(entrada ${(2 * jitter).toStringAsFixed(0)}c), média '
        '${mean.toStringAsFixed(2)}c, frames em hold $inHeld, '
        'trocas de "afinado" $transitions',
      );
    }
  }

  stdout.writeln('\n===== One Euro: efeito de beta (janela 3) =====');
  for (final beta in [0.0, 0.02, 0.06, 0.15]) {
    final config = TunerConfig(smoothingBeta: beta);
    final b = PitchSequenceBuilder(seed: 5)..note(a2, 200, jitterCents: 3);
    final out = runPipeline(TunerPipeline(config: config), b.build());
    final settled = out
        .skip(25)
        .whereType<TunerReading>()
        .map((r) => r.cents)
        .toList();
    final p2p = settled.reduce(math.max) - settled.reduce(math.min);
    // Atraso no fim de uma rampa de 100 cents/s.
    final r = PitchSequenceBuilder()
      ..note(a2, 5, cents: -60)
      ..ramp(a2, 31, fromCents: -60, toCents: 60);
    final rampOut = runPipeline(TunerPipeline(config: config), r.build());
    stdout.writeln(
      'beta $beta: jitter ±3c → p2p ${p2p.toStringAsFixed(2)}c; '
      'atraso no fim da rampa 100 c/s ${(60 - rampOut.last!.cents).toStringAsFixed(1)}c',
    );
  }
}
