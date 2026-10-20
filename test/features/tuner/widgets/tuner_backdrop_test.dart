import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guitar_zero/features/tuner/widgets/tuner_backdrop.dart';

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
  });
  tearDown(() {
    binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
  });

  testWidgets('anima o fundo e cancela os frames ao sair', (tester) async {
    await tester.pumpWidget(_host());
    var repaints = 0;
    final painter = _painter(tester);
    void onRepaint() => repaints++;
    painter.addListener(onRepaint);
    addTearDown(() => painter.removeListener(onRepaint));

    await tester.pump(const Duration(seconds: 6));
    expect(repaints, greaterThan(0));
    expect(tester.binding.hasScheduledFrame, isTrue);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    expect(tester.binding.hasScheduledFrame, isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets('redução de movimento mantém o fundo estático', (tester) async {
    await tester.pumpWidget(_host(reduceMotion: true));
    var repaints = 0;
    final painter = _painter(tester);
    void onRepaint() => repaints++;
    painter.addListener(onRepaint);
    addTearDown(() => painter.removeListener(onRepaint));

    await tester.pump(const Duration(seconds: 6));
    expect(repaints, 0);
    expect(tester.binding.hasScheduledFrame, isFalse);

    await tester.pumpWidget(_host());
    await tester.pump(const Duration(seconds: 6));
    expect(repaints, greaterThan(0));

    await tester.pumpWidget(_host(reduceMotion: true));
    final stoppedAt = repaints;
    await tester.pump(const Duration(seconds: 6));
    expect(repaints, stoppedAt);
    expect(tester.binding.hasScheduledFrame, isFalse);
  });

  testWidgets('TickerMode pausa e retoma a animação', (tester) async {
    await tester.pumpWidget(_host());
    var repaints = 0;
    final painter = _painter(tester);
    void onRepaint() => repaints++;
    painter.addListener(onRepaint);
    addTearDown(() => painter.removeListener(onRepaint));

    await tester.pump(const Duration(seconds: 3));
    expect(repaints, greaterThan(0));

    await tester.pumpWidget(_host(tickerEnabled: false));
    final stoppedAt = repaints;
    await tester.pump(const Duration(seconds: 6));
    expect(repaints, stoppedAt);
    expect(tester.binding.hasScheduledFrame, isFalse);

    await tester.pumpWidget(_host());
    await tester.pump(const Duration(seconds: 3));
    expect(repaints, greaterThan(stoppedAt));
  });

  testWidgets('segundo plano pausa o fundo e a volta retoma', (tester) async {
    await tester.pumpWidget(_host());
    var repaints = 0;
    final painter = _painter(tester);
    void onRepaint() => repaints++;
    painter.addListener(onRepaint);
    addTearDown(() => painter.removeListener(onRepaint));

    await tester.pump(const Duration(seconds: 3));
    expect(repaints, greaterThan(0));

    binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();
    final stoppedAt = repaints;
    await tester.pump(const Duration(seconds: 6));
    expect(repaints, stoppedAt);

    binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    await tester.pump(const Duration(seconds: 3));
    expect(repaints, greaterThan(stoppedAt));
  });
}

Widget _host({bool reduceMotion = false, bool tickerEnabled = true}) {
  return MediaQuery(
    data: MediaQueryData(disableAnimations: reduceMotion),
    child: Directionality(
      textDirection: TextDirection.ltr,
      child: TickerMode(enabled: tickerEnabled, child: const TunerBackdrop()),
    ),
  );
}

CustomPainter _painter(WidgetTester tester) => tester
    .widget<CustomPaint>(
      find.descendant(
        of: find.byType(TunerBackdrop),
        matching: find.byType(CustomPaint),
      ),
    )
    .painter!;
