import 'package:flutter_test/flutter_test.dart';
import 'package:guitar_zero/core/audio/audio_input.dart';
import 'package:guitar_zero/core/dsp/pitch_estimate.dart';
import 'package:guitar_zero/core/dsp/pitch_filter.dart';
import 'package:guitar_zero/core/dsp/yin_pitch_detector.dart';
import 'package:guitar_zero/core/music/pitch_math.dart';
import 'package:guitar_zero/core/tuner/pitch_tuner_engine.dart';
import 'package:guitar_zero/core/tuner/tuner_reading.dart';

import '../../support/fakes.dart';
import '../../support/synthetic_signals.dart';

class _OffsetFilter implements PitchFilter {
  int resets = 0;

  @override
  PitchEstimate? process(PitchEstimate? estimate) =>
      estimate?.copyWith(frequencyHz: estimate.frequencyHz * 2);

  @override
  void reset() => resets++;
}

void main() {
  late FakeAudioInput input;

  setUp(() => input = FakeAudioInput());

  test('pipeline: frame → detector → matcher → leitura', () async {
    final engine = PitchTunerEngine(
      audioInput: input,
      detector: ScriptedPitchDetector([
        PitchEstimate(frequencyHz: frequencyFromMidi(45.03), confidence: 0.9),
        PitchEstimate(frequencyHz: frequencyFromMidi(45.2), confidence: 0.9),
        null,
      ]),
    );
    final readings = <TunerReading?>[];
    engine.readings.listen(readings.add);

    await engine.start();
    expect(input.running, isTrue);
    input
      ..emit()
      ..emit()
      ..emit();
    await pumpEventQueue();

    expect(readings, hasLength(3));
    expect(readings[0]!.string.note.toString(), 'A2');
    expect(readings[0]!.cents, closeTo(3, 1e-6));
    expect(readings[0]!.isInTune, isTrue);
    expect(readings[1]!.cents, closeTo(20, 1e-6));
    expect(readings[1]!.isInTune, isFalse);
    expect(readings[2], isNull);
    await engine.dispose();
  });

  test('descarta estimativas com baixa confiança', () async {
    final engine = PitchTunerEngine(
      audioInput: input,
      detector: ScriptedPitchDetector([
        const PitchEstimate(frequencyHz: 110, confidence: 0.1),
      ]),
    );
    final readings = <TunerReading?>[];
    engine.readings.listen(readings.add);
    await engine.start();
    input.emit();
    await pumpEventQueue();
    expect(readings, [isNull]);
    await engine.dispose();
  });

  test('aplica filtros e os reinicia ao começar', () async {
    final filter = _OffsetFilter();
    final detector = ScriptedPitchDetector([
      const PitchEstimate(frequencyHz: 55, confidence: 1),
    ]);
    final engine = PitchTunerEngine(
      audioInput: input,
      detector: detector,
      filter: filter,
    );
    final readings = <TunerReading?>[];
    engine.readings.listen(readings.add);
    await engine.start();
    input.emit();
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

  test('pipeline real com YinPitchDetector: A2 −10 cents', () async {
    final engine = PitchTunerEngine(
      audioInput: input,
      detector: YinPitchDetector(),
    );
    final readings = <TunerReading?>[];
    engine.readings.listen(readings.add);
    await engine.start();

    final f = frequencyFromMidi(45 - 0.1);
    input
      ..emit(
        SyntheticSignals.frame(
          SyntheticSignals.tone(
            frequencyHz: f,
            sampleRate: 48000,
            length: 4096,
            harmonics: const [1, 0.6, 0.4, 0.25],
          ),
          48000,
        ),
      )
      ..emit(
        SyntheticSignals.frame(
          SyntheticSignals.whiteNoise(length: 4096, seed: 5),
          48000,
        ),
      );
    await pumpEventQueue();

    expect(readings, hasLength(2));
    expect(readings[0]!.string.note.toString(), 'A2');
    expect(readings[0]!.cents, closeTo(-10, 0.01));
    expect(readings[0]!.isInTune, isFalse);
    expect(readings[1], isNull, reason: 'ruído é barrado pelo minConfidence');
    await engine.dispose();
  });
}
