import 'package:flutter_test/flutter_test.dart';
import 'package:guitar_zero/core/music/tuning.dart';
import 'package:guitar_zero/core/tuner/silence_hold.dart';
import 'package:guitar_zero/core/tuner/tuner_reading.dart';

TunerReading reading(double cents) => TunerReading(
  frequency: 110,
  confidence: 0.97,
  string: Tuning.standard.strings[1],
  cents: cents,
  isInTune: false,
);

Duration ms(int v) => Duration(milliseconds: v);

void main() {
  test('mantém a última leitura por 700 ms, depois nada', () {
    final hold = SilenceHold(holdDuration: ms(700))..process(reading(4), ms(0));
    final held = hold.process(null, ms(700));
    expect(held!.isHeld, isTrue);
    expect(held.cents, 4);
    expect(hold.process(null, ms(701)), isNull);
    expect(hold.process(null, ms(720)), isNull);
  });

  test('baseado em tempo, não em contagem de frames', () {
    final fast = SilenceHold(holdDuration: ms(700))..process(reading(1), ms(0));
    for (var t = 10; t <= 700; t += 10) {
      expect(fast.process(null, ms(t)), isNotNull);
    }
    final slow = SilenceHold(holdDuration: ms(700))..process(reading(1), ms(0));
    expect(slow.process(null, ms(500)), isNotNull);
    expect(slow.process(null, ms(1000)), isNull);
  });

  test('leitura nova durante o hold substitui e reinicia o prazo', () {
    final hold = SilenceHold(holdDuration: ms(700))..process(reading(4), ms(0));
    hold.process(null, ms(400));
    expect(hold.process(reading(2), ms(500))!.isHeld, isFalse);
    expect(hold.process(null, ms(1100))!.cents, 2);
    expect(hold.process(null, ms(1201)), isNull);
  });
}
