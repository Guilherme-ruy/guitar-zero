import 'package:flutter_test/flutter_test.dart';
import 'package:guitar_zero/core/audio/audio_input.dart';
import 'package:guitar_zero/core/dsp/pitch_estimate.dart';
import 'package:guitar_zero/core/dsp/pitch_filter.dart';
import 'package:guitar_zero/core/music/pitch_math.dart';
import 'package:guitar_zero/core/tuner/pitch_tuner_engine.dart';
import 'package:guitar_zero/core/tuner/tuner_reading.dart';

import '../../support/fakes.dart';

class _OffsetFilter implements PitchFilter {
  int resets = 0;

  @override
  PitchEstimate? process(PitchEstimate? estimate) =>
      estimate?.copyWith(frequency: estimate.frequency * 2);

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
        PitchEstimate(frequency: frequencyFromMidi(45.03), confidence: 0.9),
        PitchEstimate(frequency: frequencyFromMidi(45.2), confidence: 0.9),
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
        const PitchEstimate(frequency: 110, confidence: 0.1),
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
      const PitchEstimate(frequency: 55, confidence: 1),
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
}
