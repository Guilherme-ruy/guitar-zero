import 'dart:ui';

import '../../../preferences/tuner_preferences.dart';

/// Imagem de headstock e posições das tarraxas/botões, em coordenadas
/// normalizadas (0–1) sobre a imagem inteira, origem no canto superior
/// esquerdo. Valores copiados de `assets/instruments/*_headstock.json`
/// (um teste garante que continuam iguais). Ordem das listas: 6ª → 1ª
/// corda (E2, A2, D3, G3, B3, E4).
class HeadstockLayout {
  const HeadstockLayout._({
    required this.asset,
    required this.keys,
    required this.buttons,
    required this.compactButtons,
    required this.regularMinHeight,
  });

  static HeadstockLayout of(InstrumentStyle style) => switch (style) {
    InstrumentStyle.acoustic => acoustic,
    InstrumentStyle.electric => electric,
  };

  /// Proporção largura/altura das imagens (288×360 lógicos).
  static const double aspectRatio = 288 / 360;

  final String asset;

  /// Centro do botão (chave) de cada tarraxa.
  final List<Offset> keys;

  /// Botões de nota quando a imagem tem ao menos [regularMinHeight] dp.
  final List<Offset> buttons;

  /// Botões em telas menores (guitarra: coluna com conectores, para os
  /// botões não ficarem pequenos demais ao acompanhar as tarraxas).
  final List<Offset> compactButtons;
  final double regularMinHeight;

  List<Offset> buttonsFor(double imageHeight) =>
      imageHeight >= regularMinHeight ? buttons : compactButtons;

  static const acoustic = HeadstockLayout._(
    asset: 'assets/instruments/acoustic_headstock.webp',
    keys: [
      Offset(0.188057, 0.519258),
      Offset(0.18984, 0.342368),
      Offset(0.192513, 0.166904),
      Offset(0.809269, 0.166904),
      Offset(0.802139, 0.342368),
      Offset(0.807487, 0.519258),
    ],
    buttons: [
      Offset(0.04, 0.519258),
      Offset(0.04, 0.342368),
      Offset(0.04, 0.166904),
      Offset(0.96, 0.166904),
      Offset(0.96, 0.342368),
      Offset(0.96, 0.519258),
    ],
    compactButtons: [
      Offset(0.04, 0.519258),
      Offset(0.04, 0.342368),
      Offset(0.04, 0.166904),
      Offset(0.96, 0.166904),
      Offset(0.96, 0.342368),
      Offset(0.96, 0.519258),
    ],
    regularMinHeight: 320,
  );

  static const electric = HeadstockLayout._(
    asset: 'assets/instruments/electric_headstock.webp',
    keys: [
      Offset(0.257576, 0.612696),
      Offset(0.296791, 0.510699),
      Offset(0.336898, 0.410128),
      Offset(0.37344, 0.308845),
      Offset(0.414439, 0.2097),
      Offset(0.456328, 0.107703),
    ],
    buttons: [
      Offset(0.087576, 0.612696),
      Offset(0.126791, 0.510699),
      Offset(0.166898, 0.410128),
      Offset(0.20344, 0.308845),
      Offset(0.244439, 0.2097),
      Offset(0.286328, 0.107703),
    ],
    compactButtons: [
      Offset(0.075, 0.8),
      Offset(0.075, 0.66),
      Offset(0.075, 0.52),
      Offset(0.075, 0.38),
      Offset(0.075, 0.24),
      Offset(0.075, 0.1),
    ],
    regularMinHeight: 500,
  );
}
