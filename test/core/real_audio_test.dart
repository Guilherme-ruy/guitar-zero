import 'dart:io';
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:guitar_zero/core/audio/microphone_audio_input.dart';
import 'package:guitar_zero/core/audio/pcm_framer.dart';
import 'package:guitar_zero/core/dsp/harmonic_pitch_detector.dart';
import 'package:guitar_zero/core/music/pitch_math.dart';
import 'package:guitar_zero/core/tuner/tuner_pipeline.dart';
import 'package:guitar_zero/core/tuner/tuner_reading.dart';

import '../support/wav.dart';

// Regressão com gravações reais (NSynth, CC BY 4.0; ver
// test/fixtures/nsynth/README.md), na configuração do app: 44.1 kHz,
// frames de 4096, hop de 40 ms, HarmonicPitchDetector + TunerPipeline.
//
// Os limites vêm das medições da fase 4 (docs/DSP_STRATEGY.md), com folga.
// O desvio médio em relação à nota nominal reflete a afinação de cada
// amostra, não erro do detector.

const fixtures = {
  'guitar_acoustic_015-040-050': 'E2',
  'guitar_acoustic_014-045-050': 'A2',
  'guitar_acoustic_010-050-050': 'D3',
  'guitar_electronic_028-055-050': 'G3',
  'guitar_electronic_022-059-075': 'B3',
  'guitar_acoustic_021-064-127': 'E4',
};

void main() {
  const capture = AudioCaptureConfig();

  for (final MapEntry(key: name, value: note) in fixtures.entries) {
    test('$note real ($name)', () {
      final midi = int.parse(name.split('-')[1]);
      final target = frequencyFromMidi(midi);
      final frames = PcmFramer(
        sampleRate: capture.sampleRate,
        frameSize: capture.frameSize,
        hopSize: capture.hopSize,
      ).addPcm16(readWavPcm16(File('test/fixtures/nsynth/$name.wav')));
      final detector = HarmonicPitchDetector();
      final pipeline = TunerPipeline();

      final shown = <({int ms, TunerReading r})>[];
      for (final frame in frames) {
        final r = pipeline.process(detector.detect(frame), frame.timestamp);
        if (r != null) shown.add((ms: frame.timestamp.inMilliseconds, r: r));
      }

      expect(shown, isNotEmpty);
      // Sempre a corda certa e a oitava certa — inclusive na cauda (> 3 s),
      // onde o detector pode pegar o 3º harmônico.
      for (final s in shown) {
        expect(s.r.string.note.toString(), note, reason: 't=${s.ms} ms');
        expect(
          (centsBetween(s.r.frequency, target) / 1200).round(),
          0,
          reason: 't=${s.ms} ms',
        );
      }
      // Aquisição: medido 173–613 ms.
      expect(shown.first.ms, lessThanOrEqualTo(1000));

      // Estabilidade na sustentação (0.3–2.5 s): medido p2p ≤ 4.1 cents.
      final sustain = shown
          .where((s) => !s.r.isHeld && s.ms >= 300 && s.ms <= 2500)
          .map((s) => s.r.cents)
          .toList();
      expect(sustain.length, greaterThan(40));
      final p2p = sustain.reduce(math.max) - sustain.reduce(math.min);
      expect(p2p, lessThan(6));
    });
  }
}
