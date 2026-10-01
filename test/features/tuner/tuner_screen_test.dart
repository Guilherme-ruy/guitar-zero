import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guitar_zero/app/app.dart';
import 'package:guitar_zero/core/audio/audio_input.dart';
import 'package:guitar_zero/core/music/tuning.dart';
import 'package:guitar_zero/core/tuner/simulated_tuner_engine.dart';
import 'package:guitar_zero/core/tuner/tuner_reading.dart';
import 'package:guitar_zero/features/preferences/preferences_store.dart';
import 'package:guitar_zero/features/preferences/tuner_preferences.dart';
import 'package:guitar_zero/features/tuner/widgets/headstock/headstock_view.dart';
import 'package:guitar_zero/features/tuner/widgets/string_board.dart';

import '../../support/fakes.dart';

void main() {
  testWidgets('estado inicial pede para tocar uma corda', (tester) async {
    final engine = FakeTunerEngine();
    await tester.pumpWidget(GuitarZeroApp(engine: engine));
    await tester.pump();

    expect(find.text('GUITAR ZERO'), findsOneWidget);
    expect(find.text('Toque qualquer corda'), findsOneWidget);
    expect(find.text('DEMO'), findsNothing);
    // As seis cordas da afinação Standard.
    expect(find.text('E'), findsNWidgets(2));
    for (final name in ['A', 'D', 'G', 'B']) {
      expect(find.text(name), findsOneWidget);
    }
  });

  testWidgets('exibe nota, frequência e direção da afinação', (tester) async {
    final engine = FakeTunerEngine();
    await tester.pumpWidget(GuitarZeroApp(engine: engine));
    await tester.pump();

    engine.emit(
      TunerReading(
        frequency: 107.5,
        confidence: 1,
        string: Tuning.standard.strings[1],
        cents: -40,
        isInTune: false,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('107.5 Hz'), findsOneWidget);
    expect(find.text('−40 cents'), findsOneWidget);
    expect(find.text('Baixa — suba a afinação'), findsOneWidget);

    engine.emit(
      TunerReading(
        frequency: 110,
        confidence: 1,
        string: Tuning.standard.strings[1],
        cents: 0.4,
        isInTune: true,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Afinada'), findsOneWidget);
  });

  testWidgets('modo demo roda com o engine simulado', (tester) async {
    final engine = SimulatedTunerEngine();
    await tester.pumpWidget(GuitarZeroApp(engine: engine, isDemo: true));
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('DEMO'), findsOneWidget);
    expect(find.textContaining('Hz'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });

  testWidgets('microfone negado: mensagem e "Tentar novamente"', (
    tester,
  ) async {
    final engine = FakeTunerEngine()
      ..failOnStart = const AudioInputException(
        AudioInputFailure.permissionDenied,
      );
    await tester.pumpWidget(GuitarZeroApp(engine: engine));
    await tester.pumpAndSettle();
    expect(
      find.text('Permita o acesso ao microfone para afinar'),
      findsOneWidget,
    );

    engine.failOnStart = null;
    await tester.tap(find.text('Tentar novamente'));
    await tester.pumpAndSettle();
    expect(find.text('Toque qualquer corda'), findsOneWidget);
  });

  testWidgets('leitura em hold mostra a nota, mas pede nova palhetada', (
    tester,
  ) async {
    final engine = FakeTunerEngine();
    await tester.pumpWidget(GuitarZeroApp(engine: engine));
    await tester.pump();
    engine.emit(
      TunerReading(
        frequency: 110,
        confidence: 1,
        string: Tuning.standard.strings[1],
        cents: 2,
        isInTune: true,
        isHeld: true,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('110.0 Hz'), findsOneWidget);
    expect(find.text('Toque qualquer corda'), findsOneWidget);
  });

  testWidgets('toque longo no logo abre e fecha o diagnóstico', (tester) async {
    await tester.pumpWidget(GuitarZeroApp(engine: FakeTunerEngine()));
    await tester.pump();
    expect(find.textContaining('diagnóstico'), findsNothing);
    await tester.longPress(find.text('GUITAR ZERO'));
    await tester.pump();
    expect(find.text('diagnóstico: aguardando áudio…'), findsOneWidget);
    await tester.longPress(find.text('GUITAR ZERO'));
    await tester.pump();
    expect(find.textContaining('diagnóstico'), findsNothing);
  });

  group('automático / manual', () {
    testWidgets('começa no automático; tocar numa corda entra no manual', (
      tester,
    ) async {
      final engine = FakeTunerEngine();
      await tester.pumpWidget(GuitarZeroApp(engine: engine));
      await tester.pump();
      expect(tester.widget<Switch>(find.byType(Switch)).value, isTrue);

      await tester.tap(find.text('D'));
      await tester.pump();
      expect(tester.widget<Switch>(find.byType(Switch)).value, isFalse);
      expect(engine.target, Tuning.standard.strings[2]);
      expect(find.text('Toque a corda D (4ª)'), findsOneWidget);
    });

    testWidgets('switch alterna e só ele volta ao automático', (tester) async {
      final engine = FakeTunerEngine();
      await tester.pumpWidget(GuitarZeroApp(engine: engine));
      await tester.pump();
      await tester.tap(find.byType(Switch));
      await tester.pump();
      expect(engine.target, Tuning.standard.strings.first);
      // Tocar em outra corda continua no manual.
      await tester.tap(find.text('G'));
      await tester.pump();
      expect(tester.widget<Switch>(find.byType(Switch)).value, isFalse);
      await tester.tap(find.byType(Switch));
      await tester.pump();
      expect(engine.target, isNull);
      expect(find.text('Toque qualquer corda'), findsOneWidget);
    });
  });

  group('ajustes', () {
    testWidgets('instrumento visível por padrão; minimalista pelos ajustes', (
      tester,
    ) async {
      final prefs = TunerPreferences(InMemoryPreferencesStore());
      await tester.pumpWidget(
        GuitarZeroApp(engine: FakeTunerEngine(), preferences: prefs),
      );
      await tester.pump();
      expect(find.byType(HeadstockView), findsOneWidget);

      await tester.tap(find.text('VIOLÃO · STANDARD'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Minimalista'));
      await tester.pumpAndSettle();
      expect(prefs.showInstrument, isFalse);
      await tester.tap(find.text('Guitarra'));
      await tester.pumpAndSettle();
      expect(prefs.instrument, InstrumentStyle.electric);

      Navigator.of(tester.element(find.text('Guitarra'))).pop();
      await tester.pumpAndSettle();
      expect(find.byType(StringBoard), findsOneWidget);
      expect(find.text('GUITARRA · STANDARD'), findsOneWidget);
    });

    testWidgets('nomes em solfejo', (tester) async {
      final prefs = TunerPreferences(InMemoryPreferencesStore())
        ..noteNaming = NoteNaming.solfege;
      await tester.pumpWidget(
        GuitarZeroApp(engine: FakeTunerEngine(), preferences: prefs),
      );
      await tester.pump();
      for (final name in ['Lá', 'Ré', 'Sol', 'Si']) {
        expect(find.text(name), findsOneWidget);
      }
      expect(find.text('Mi'), findsNWidgets(2));
      expect(find.text('A'), findsNothing);
    });
  });
}
