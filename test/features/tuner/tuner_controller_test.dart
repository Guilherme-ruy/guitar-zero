import 'package:flutter_test/flutter_test.dart';
import 'package:guitar_zero/core/audio/audio_input.dart';
import 'package:guitar_zero/core/music/tuning.dart';
import 'package:guitar_zero/core/tuner/tuner_reading.dart';
import 'package:guitar_zero/features/tuner/tuner_controller.dart';

import '../../support/fakes.dart';

TunerReading _reading(int stringIndex, double cents) => TunerReading(
  frequency: 100,
  confidence: 1,
  string: Tuning.standard.strings[stringIndex],
  cents: cents,
  isInTune: cents.abs() <= 5,
);

void main() {
  test('start → listening; leituras atualizam o estado', () async {
    final engine = FakeTunerEngine();
    final controller = TunerController(engine);
    await controller.start();
    expect(controller.status, TunerStatus.listening);

    engine.emit(_reading(1, -20));
    expect(controller.reading!.cents, -20);
    expect(controller.activeString, Tuning.standard.strings[1]);
    expect(controller.tunedStrings, isEmpty);

    engine.emit(_reading(1, 2));
    expect(controller.tunedStrings, {Tuning.standard.strings[1]});

    engine.emit(null);
    expect(controller.reading, isNull);
    expect(
      controller.activeString,
      Tuning.standard.strings[1],
      reason: 'a corda ativa permanece durante o silêncio',
    );
    controller.dispose();
  });

  test('permissão negada é refletida no status', () async {
    final engine = FakeTunerEngine()
      ..failOnStart = const AudioInputException(
        AudioInputFailure.permissionDenied,
      );
    final controller = TunerController(engine);
    await controller.start();
    expect(controller.status, TunerStatus.permissionDenied);
    controller.dispose();
  });
}
