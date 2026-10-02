import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:guitar_zero/features/preferences/tuner_preferences.dart';
import 'package:guitar_zero/features/tuner/widgets/headstock/headstock_layout.dart';

// As coordenadas no código são cópia dos JSONs que acompanham as imagens.
void main() {
  const order = ['E2', 'A2', 'D3', 'G3', 'B3', 'E4'];

  for (final style in InstrumentStyle.values) {
    test('${style.name}: coordenadas iguais às do JSON', () {
      final layout = HeadstockLayout.of(style);
      final json = jsonDecode(
        File(layout.asset.replaceFirst('.webp', '.json')).readAsStringSync(),
      ) as Map<String, dynamic>;
      final strings = json['strings'] as Map<String, dynamic>;
      Offset at(String note, String key) {
        final p =
            (strings[note] as Map<String, dynamic>)[key]
                as Map<String, dynamic>;
        return Offset((p['x'] as num).toDouble(), (p['y'] as num).toDouble());
      }

      for (var i = 0; i < order.length; i++) {
        expect(layout.keys[i], at(order[i], 'tuning_key_center'));
        expect(layout.buttons[i], at(order[i], 'button_center'));
        expect(layout.compactButtons[i], at(order[i], 'compact_button_center'));
      }
      final image = json['image'] as Map<String, dynamic>;
      expect(
        (image['logical_width_dp'] as num) /
            (image['logical_height_dp'] as num),
        HeadstockLayout.aspectRatio,
      );
      expect(
        (json['layout_guidance']
            as Map<String, dynamic>)['regular_min_rendered_image_height_dp'],
        layout.regularMinHeight,
      );
      expect(File(layout.asset).existsSync(), isTrue);
    });
  }
}
