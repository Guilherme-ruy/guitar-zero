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
  final binding = TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    // Exercita a preferência real de acessibilidade: o fundo fica estático,
    // enquanto as transições finitas continuam cobertas por pumpAndSettle.
    binding.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
  });
  tearDown(binding.platformDispatcher.clearAccessibilityFeaturesTestValue);

  testWidgets('abre no afinador e inicia a escuta no primeiro frame', (
    tester,
  ) async {
    final engine = _StartCountingEngine();
    await tester.pumpWidget(GuitarZeroApp(engine: engine));

    expect(engine.starts, 1);
    expect(find.byType(HeadstockView), findsOneWidget);
    expect(find.text('GUITAR ZERO'), findsOneWidget);
    await tester.pump();

    expect(find.text('Toque uma corda para começar'), findsOneWidget);
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
    expect(find.textContaining('cents'), findsNothing);
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
    expect(find.text('Toque uma corda para começar'), findsOneWidget);
  });

  testWidgets('após o som, o veredito fica alguns segundos e depois orienta', (
    tester,
  ) async {
    final engine = FakeTunerEngine();
    await tester.pumpWidget(GuitarZeroApp(engine: engine));
    await tester.pump();
    final a2 = Tuning.standard.strings[1];
    TunerReading at(double cents, {bool held = false}) => TunerReading(
      frequency: 110,
      confidence: 1,
      string: a2,
      cents: cents,
      isInTune: cents.abs() < 3,
      isHeld: held,
    );

    engine.emit(at(-40));
    await tester.pump();
    engine.emit(at(-40, held: true));
    await tester.pump(const Duration(milliseconds: 500));
    engine.emit(null);
    await tester.pump(const Duration(seconds: 2));
    // Pausa curta: continua dizendo o que fazer, sem voltar ao início.
    expect(find.text('Baixa — suba a afinação'), findsOneWidget);
    expect(find.text('110.0 Hz'), findsOneWidget);

    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
    expect(find.text('Ajuste e toque a corda de novo'), findsOneWidget);
    expect(find.text('110.0 Hz'), findsNothing);

    engine.emit(at(0.5));
    await tester.pump();
    engine.emit(null);
    await tester.pump(const Duration(seconds: 6));
    await tester.pumpAndSettle();
    expect(find.text('Toque a próxima corda'), findsOneWidget);
  });

  testWidgets('todas as cordas afinadas', (tester) async {
    final engine = FakeTunerEngine();
    await tester.pumpWidget(GuitarZeroApp(engine: engine));
    await tester.pump();
    for (final s in Tuning.standard.strings) {
      engine.emit(
        TunerReading(
          frequency: s.targetFrequency,
          confidence: 1,
          string: s,
          cents: 0,
          isInTune: true,
        ),
      );
      await tester.pump();
    }
    engine.emit(null);
    await tester.pump(const Duration(seconds: 6));
    await tester.pumpAndSettle();
    expect(find.text('Todas as cordas afinadas'), findsOneWidget);
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
      expect(find.text('Toque uma corda para começar'), findsOneWidget);
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

class _StartCountingEngine extends FakeTunerEngine {
  int starts = 0;

  @override
  Future<void> start() {
    starts++;
    return super.start();
  }
}
