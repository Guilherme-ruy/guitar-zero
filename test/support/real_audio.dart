import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:guitar_zero/core/audio/microphone_audio_input.dart';
import 'package:guitar_zero/core/audio/pcm_framer.dart';
import 'package:guitar_zero/core/dsp/harmonic_pitch_detector.dart';
import 'package:guitar_zero/core/tuner/tuner_config.dart';
import 'package:guitar_zero/core/tuner/tuner_pipeline.dart';
import 'package:guitar_zero/core/tuner/tuner_reading.dart';

import 'synthetic_signals.dart';
import 'wav.dart';

/// Gravações reais em `test/fixtures/nsynth/` (44.1 kHz), por nota.
const realFixtures = {
  'E2': 'guitar_acoustic_015-040-050',
  'A2': 'guitar_acoustic_014-045-050',
  'D3': 'guitar_acoustic_010-050-050',
  'G3': 'guitar_electronic_028-055-050',
  'B3': 'guitar_electronic_022-059-075',
  'E4': 'guitar_acoustic_021-064-127',
};

const int realSampleRate = 44100;

/// Amostras em ponto flutuante de uma gravação de referência.
Float32List loadRealNote(String note, {String dir = 'test/fixtures/nsynth'}) {
  final pcm = ByteData.sublistView(
    readWavPcm16(File('$dir/${realFixtures[note]}.wav')),
  );
  return Float32List.fromList([
    for (var i = 0; i < pcm.lengthInBytes ~/ 2; i++)
      pcm.getInt16(i * 2, Endian.little) / 32768,
  ]);
}

/// Um som posicionado numa mixagem.
typedef Layer = ({Float32List samples, double startSeconds, double gain});

/// Soma camadas (com início e ganho) e, opcionalmente, ruído branco com a
/// relação sinal/ruído [snrDb] medida sobre o RMS da mixagem.
Float32List mix(
  List<Layer> layers, {
  required double seconds,
  double? snrDb,
  int seed = 1,
}) {
  final out = Float32List((seconds * realSampleRate).round());
  for (final layer in layers) {
    final start = (layer.startSeconds * realSampleRate).round();
    for (var i = 0; i < layer.samples.length && start + i < out.length; i++) {
      out[start + i] += layer.gain * layer.samples[i];
    }
  }
  if (snrDb != null) {
    var energy = 0.0;
    for (final v in out) {
      energy += v * v;
    }
    final signalRms = math.sqrt(energy / out.length);
    // Ruído uniforme em [−p, p] tem RMS p/√3.
    final peak = signalRms / math.pow(10, snrDb / 20) * math.sqrt(3);
    final rng = Xorshift32(seed);
    for (var i = 0; i < out.length; i++) {
      out[i] += peak * rng.nextSigned();
    }
  }
  return out;
}

/// Leituras exibidas (não-nulas) ao processar [samples] como o app faz.
List<({int ms, TunerReading reading})> runRealPipeline(
  Float32List samples, {
  TunerConfig config = const TunerConfig(),
}) {
  const capture = AudioCaptureConfig();
  final frames = PcmFramer(
    sampleRate: realSampleRate,
    frameSize: capture.frameSize,
    hopSize: capture.hopSize,
  ).addSamples(samples);
  final detector = HarmonicPitchDetector();
  final pipeline = TunerPipeline(config: config);
  return [
    for (final frame in frames)
      if (pipeline.process(detector.detect(frame), frame.timestamp)
          case final reading?)
        (ms: frame.timestamp.inMilliseconds, reading: reading),
  ];
}
