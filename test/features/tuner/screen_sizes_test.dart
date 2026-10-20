import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guitar_zero/app/app.dart';
import 'package:guitar_zero/core/music/tuning.dart';
import 'package:guitar_zero/core/tuner/tuner_reading.dart';
import 'package:guitar_zero/features/preferences/preferences_store.dart';
import 'package:guitar_zero/features/preferences/tuner_preferences.dart';
import 'package:guitar_zero/features/tuner/widgets/string_button.dart';

import '../../support/fakes.dart';

// Layout em tamanhos de tela comuns: qualquer estouro (overflow) falha o
// teste. Os botões das cordas não podem se sobrepor.
void main() {
  const sizes = [
    Size(360, 640),
    Size(375, 667),
    Size(390, 844),
    Size(412, 915),
  ];

  for (final size in sizes) {
    for (final instrument in InstrumentStyle.values) {
      for (final show in [true, false]) {
        testWidgets('${size.width.toInt()}×${size.height.toInt()} '
            '${instrument.name} ${show ? 'com instrumento' : 'minimalista'}', (
          tester,
        ) async {
          tester.view.physicalSize = size * 2;
          tester.view.devicePixelRatio = 2;
          // Valores físicos: 24 dp para as barras superior e inferior.
          tester.view.padding = const FakeViewPadding(top: 48, bottom: 48);
          tester.view.viewPadding = const FakeViewPadding(top: 48, bottom: 48);
          addTearDown(tester.view.reset);
          final prefs = TunerPreferences(InMemoryPreferencesStore())
            ..instrument = instrument
            ..showInstrument = show;
          final engine = FakeTunerEngine();
          await tester.pumpWidget(
            GuitarZeroApp(engine: engine, preferences: prefs),
          );
          engine.emit(
            TunerReading(
              frequency: 108,
              confidence: 1,
              string: Tuning.standard.strings[1],
              cents: -30,
              isInTune: false,
            ),
          );
          await tester.pump(const Duration(seconds: 1));

          expect(tester.takeException(), isNull);
          final buttons = find.byType(StringButton);
          expect(buttons, findsNWidgets(6));
          final rects = [
            for (var i = 0; i < 6; i++) tester.getRect(buttons.at(i)),
          ];
          final usableArea = Rect.fromLTRB(0, 24, size.width, size.height - 24);
          for (var i = 0; i < rects.length; i++) {
            expect(
              usableArea.contains(rects[i].topLeft) &&
                  usableArea.contains(rects[i].bottomRight),
              isTrue,
              reason: 'corda ${i + 1} fora da área útil: ${rects[i]}',
            );
            for (var j = i + 1; j < rects.length; j++) {
              expect(
                rects[i].overlaps(rects[j]),
                isFalse,
                reason: 'botões ${i + 1} e ${j + 1} sobrepostos',
              );
            }
          }
        });
      }
    }
  }
}
