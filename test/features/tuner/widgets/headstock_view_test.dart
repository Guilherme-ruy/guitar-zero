import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guitar_zero/app/theme.dart';
import 'package:guitar_zero/core/music/tuning.dart';
import 'package:guitar_zero/features/preferences/tuner_preferences.dart';
import 'package:guitar_zero/features/tuner/widgets/headstock/headstock_view.dart';
import 'package:guitar_zero/features/tuner/widgets/string_button.dart';

void main() {
  for (final style in InstrumentStyle.values) {
    for (final height in [120.0, 180.0, 400.0]) {
      testWidgets('${style.name}: botões dentro do instrumento em '
          '320×${height.toInt()}', (tester) async {
        const boundsKey = Key('headstock-bounds');
        await tester.pumpWidget(
          MaterialApp(
            theme: buildGzTheme(),
            home: Scaffold(
              body: Center(
                child: SizedBox(
                  key: boundsKey,
                  width: 320,
                  height: height,
                  child: HeadstockView(
                    style: style,
                    strings: Tuning.standard.strings,
                    activeString: null,
                    selectedString: null,
                    activeColor: GzColors.zero,
                    tunedStrings: const {},
                    naming: NoteNaming.letters,
                    onSelect: (_) {},
                  ),
                ),
              ),
            ),
          ),
        );

        expect(tester.takeException(), isNull);
        final bounds = tester.getRect(find.byKey(boundsKey));
        final buttons = find.byType(StringButton);
        expect(buttons, findsNWidgets(6));
        for (var i = 0; i < 6; i++) {
          final rect = tester.getRect(buttons.at(i));
          expect(
            rect.top,
            greaterThanOrEqualTo(bounds.top - 0.001),
            reason: 'a elevação cortou o topo do botão ${i + 1}',
          );
          expect(
            rect.bottom,
            lessThanOrEqualTo(bounds.bottom + 0.001),
            reason: 'botão ${i + 1} ultrapassa a base do componente',
          );
          expect(rect.left, greaterThanOrEqualTo(bounds.left - 0.001));
          expect(rect.right, lessThanOrEqualTo(bounds.right + 0.001));
        }
      });
    }
  }
}
