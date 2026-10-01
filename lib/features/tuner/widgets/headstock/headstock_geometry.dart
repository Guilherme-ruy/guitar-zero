import 'dart:ui';

import '../../../preferences/tuner_preferences.dart';

/// Geometria do headstock em unidades de projeto (caixa 100 × 160, origem no
/// canto superior esquerdo). O desenho ([HeadstockPainter]) e os botões das
/// cordas usam as mesmas coordenadas, então tarraxas e botões nunca se
/// desalinham.
///
/// Listas indexadas pela corda, da mais grave (E2) para a mais aguda (E4).
class HeadstockGeometry {
  const HeadstockGeometry._({
    required this.outline,
    required this.nutY,
    required this.neckLeft,
    required this.neckRight,
    required this.nutSlotsX,
    required this.posts,
    required this.knobs,
    required this.buttons,
    required this.logo,
    required this.buttonSpacing,
  });

  static const Size designSize = Size(100, 160);

  /// Contorno do headstock.
  final Path outline;

  /// Altura do nut (pestana); o braço segue abaixo.
  final double nutY;
  final double neckLeft;
  final double neckRight;

  /// X de cada corda no nut.
  final List<double> nutSlotsX;

  /// Pino onde cada corda se prende.
  final List<Offset> posts;

  /// Centro da chave da tarraxa de cada corda (fora do headstock).
  final List<Offset> knobs;

  /// Centro do botão de cada corda.
  final List<Offset> buttons;

  /// Centro do anel da marca.
  final Offset logo;

  /// Menor distância vertical entre botões (limita o tamanho deles).
  final double buttonSpacing;

  static HeadstockGeometry of(InstrumentStyle style) => switch (style) {
    InstrumentStyle.acoustic => _acoustic,
    InstrumentStyle.electric => _electric,
  };

  /// Violão: 3 tarraxas de cada lado. Esquerda (de baixo para cima) E2, A2,
  /// D3; direita (de cima para baixo) G3, B3, E4.
  static final HeadstockGeometry _acoustic = () {
    const ys = [112.0, 82.0, 52.0];
    final outline = Path()
      ..moveTo(35, 140)
      ..cubicTo(29, 132, 26, 124, 26, 110)
      ..lineTo(25, 30)
      ..quadraticBezierTo(33, 8, 50, 17)
      ..quadraticBezierTo(67, 8, 75, 30)
      ..lineTo(74, 110)
      ..cubicTo(74, 124, 71, 132, 65, 140)
      ..close();
    return HeadstockGeometry._(
      outline: outline,
      nutY: 138,
      neckLeft: 35,
      neckRight: 65,
      nutSlotsX: [for (var i = 0; i < 6; i++) 38 + i * 4.8],
      posts: [
        for (final y in ys) Offset(37, y),
        for (final y in ys.reversed) Offset(63, y),
      ],
      knobs: [
        for (final y in ys) Offset(19, y),
        for (final y in ys.reversed) Offset(81, y),
      ],
      buttons: [
        for (final y in ys) Offset(8, y),
        for (final y in ys.reversed) Offset(92, y),
      ],
      logo: const Offset(50, 30),
      buttonSpacing: 30,
    );
  }();

  /// Guitarra: 6 tarraxas em linha do lado esquerdo; E2 junto ao nut, E4 na
  /// ponta.
  static final HeadstockGeometry _electric = () {
    final outline = Path()
      ..moveTo(39, 140)
      ..lineTo(61, 140)
      ..cubicTo(63, 128, 62, 120, 64, 106)
      ..cubicTo(68, 80, 75, 46, 67, 14)
      ..cubicTo(63, 1, 46, -4, 30, 0)
      ..cubicTo(20, 3, 16, 13, 20, 26)
      ..lineTo(32, 128)
      ..cubicTo(34, 134, 37, 136, 39, 140)
      ..close();
    // Espaçamento de 23 unidades: em telas baixas os 6 botões empilhados
    // ainda cabem sem se sobrepor.
    final posts = [
      for (var i = 0; i < 6; i++) Offset(41 - i * 2.0, 124 - i * 23.0),
    ];
    return HeadstockGeometry._(
      outline: outline,
      nutY: 138,
      neckLeft: 39,
      neckRight: 61,
      nutSlotsX: [for (var i = 0; i < 6; i++) 41 + i * 3.6],
      posts: posts,
      knobs: [for (final p in posts) Offset(17, p.dy)],
      buttons: [for (final p in posts) Offset(7, p.dy)],
      logo: const Offset(53, 32),
      buttonSpacing: 23,
    );
  }();
}
