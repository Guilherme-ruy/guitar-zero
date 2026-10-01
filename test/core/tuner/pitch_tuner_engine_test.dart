import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:guitar_zero/core/audio/audio_frame.dart';
import 'package:guitar_zero/core/audio/audio_input.dart';
import 'package:guitar_zero/core/dsp/pitch_estimate.dart';
import 'package:guitar_zero/core/dsp/pitch_filter.dart';
import 'package:guitar_zero/core/dsp/yin_pitch_detector.dart';
import 'package:guitar_zero/core/music/pitch_math.dart';
import 'package:guitar_zero/core/tuner/pitch_tuner_engine.dart';
import 'package:guitar_zero/core/tuner/tuner_config.dart';
import 'package:guitar_zero/core/tuner/tuner_reading.dart';

import '../../support/fakes.dart';
import '../../support/synthetic_signals.dart';

class _DoublingFilter implements PitchFilter {
  int resets = 0;

  @override
  PitchEstimate? process(PitchEstimate? estimate, Duration timestamp) =>
      estimate?.copyWith(frequencyHz: estimate.frequencyHz * 2);

  @override
  void reset() => resets++;
}

AudioFrame _silentFrame(int ms) => AudioFrame(
  samples: Float32List(1024),
  sampleRate: 48000,
  timestamp: Duration(milliseconds: ms),
);

void main() {
  late FakeAudioInput input;

  setUp(() => input = FakeAudioInput());

  test('sem filtros de pitch: frame → detector → corda → leitura', () async {
    final engine = PitchTunerEngine(
      audioInput: input,
      detector: ScriptedPitchDetector([
        PitchEstimate(frequencyHz: frequencyFromMidi(45.02), confidence: 0.9),
        PitchEstimate(frequencyHz: frequencyFromMidi(45.2), confidence: 0.9),
        null,
      ]),
      pitchFilter: const PitchFilterChain([]),
    );
    final readings = <TunerReading?>[];
    engine.readings.listen(readings.add);

    await engine.start();
    expect(input.running, isTrue);
    input
      ..emit(_silentFrame(0))
      ..emit(_silentFrame(40))
      ..emit(_silentFrame(80));
    await pumpEventQueue();

    expect(readings, hasLength(3));
    expect(readings[0]!.string.note.toString(), 'A2');
    expect(readings[0]!.cents, closeTo(2, 1e-6));
    expect(readings[0]!.isInTune, isTrue);
    expect(readings[1]!.cents, closeTo(20, 1e-6));
    expect(readings[1]!.isInTune, isFalse);
    // Silêncio: a última leitura é mantida (hold).
    expect(readings[2]!.isHeld, isTrue);
    expect(readings[2]!.cents, closeTo(20, 1e-6));
    await engine.dispose();
  });

  test('aplica o filtro de pitch injetado e o reinicia ao começar', () async {
    final filter = _DoublingFilter();
    final detector = ScriptedPitchDetector([
      const PitchEstimate(frequencyHz: 55, confidence: 1),
    ]);
    final engine = PitchTunerEngine(
      audioInput: input,
      detector: detector,
      pitchFilter: filter,
    );
    final readings = <TunerReading?>[];
    engine.readings.listen(readings.add);
    await engine.start();
    input.emit(_silentFrame(0));
    await pumpEventQueue();
    expect(filter.resets, 1);
    expect(detector.resets, 1);
    expect(readings.single!.frequency, 110);
    expect(readings.single!.string.note.toString(), 'A2');
    await engine.dispose();
  });

  test('propaga falha de permissão do microfone', () async {
    input.failOnStart = const AudioInputException(
      AudioInputFailure.permissionDenied,
    );
    final engine = PitchTunerEngine(
      audioInput: input,
      detector: ScriptedPitchDetector([]),
    );
    await expectLater(engine.start(), throwsA(isA<AudioInputException>()));
    await engine.dispose();
  });

  test('pipeline completo com YIN real: A2 −10 cents, depois ruído', () async {
    const config = TunerConfig();
    final engine = PitchTunerEngine(
      audioInput: input,
      detector: YinPitchDetector(),
    );
    final readings = <TunerReading?>[];
    engine.readings.listen(readings.add);
    await engine.start();

    // Sinal contínuo; frames de 4096 com hop de 40 ms (1920 amostras).
    const sampleRate = 48000;
    const hop = 1920;
    final f = frequencyFromMidi(45 - 0.1);
    final tone = SyntheticSignals.tone(
      frequencyHz: f,
      sampleRate: sampleRate,
      length: 4096 + hop * 9,
      harmonics: const [1, 0.6, 0.4, 0.25],
    );
    for (var i = 0; i < 10; i++) {
      input.emit(
        SyntheticSignals.frame(tone, sampleRate, offset: i * hop, length: 4096),
      );
    }
    // Depois, 1 s de ruído (25 frames).
    for (var i = 0; i < 25; i++) {
      input.emit(
        SyntheticSignals.frame(
          SyntheticSignals.whiteNoise(length: 4096, seed: i + 1),
          sampleRate,
          timestamp: Duration(milliseconds: 400 + i * 40),
        ),
      );
    }
    await pumpEventQueue();

    expect(readings, hasLength(35));
    // Aquisição: as primeiras (stabilityWindow − 1) saídas são nulas.
    final firstReading = readings.indexWhere((r) => r != null);
    expect(firstReading, config.stabilityWindow - 1);
    for (final r in readings.sublist(firstReading, 10)) {
      expect(r!.string.note.toString(), 'A2');
      expect(r.cents, closeTo(-10, 0.05));
      expect(r.isHeld, isFalse);
    }
    // Ruído: hold de 700 ms (frames até 360 + 700 ms), depois nada.
    final afterTone = readings.sublist(10);
    final held = afterTone.takeWhile((r) => r != null).toList();
    expect(held, everyElement(isA<TunerReading>()));
    expect(held.every((r) => r!.isHeld), isTrue);
    expect(held.length, 17); // 400..1040 ms: ≤ 700 ms após 360 ms
    expect(afterTone.skip(held.length), everyElement(isNull));
    await engine.dispose();
  });
}
