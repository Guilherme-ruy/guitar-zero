import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guitar_zero/app/app.dart';
import 'package:guitar_zero/core/music/tuning.dart';
import 'package:guitar_zero/core/tuner/tuner_reading.dart';
import 'package:guitar_zero/features/preferences/preferences_store.dart';
import 'package:guitar_zero/features/preferences/tuner_preferences.dart';

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

          final rects = [
            for (final name in ['D', 'G', 'B'])
              tester.getRect(
                find
                    .ancestor(
                      of: find.text(name),
                      matching: find.byType(SizedBox),
                    )
                    .first,
              ),
          ];
          for (var i = 0; i < rects.length; i++) {
            for (var j = i + 1; j < rects.length; j++) {
              expect(
                rects[i].intersect(rects[j]).isEmpty ||
                    rects[i].intersect(rects[j]).width <= 0 ||
                    rects[i].intersect(rects[j]).height <= 0,
                isTrue,
                reason: 'botões sobrepostos',
              );
            }
          }
        });
      }
    }
  }
}
