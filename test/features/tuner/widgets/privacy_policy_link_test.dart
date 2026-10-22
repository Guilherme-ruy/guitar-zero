import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guitar_zero/app/app.dart';
import 'package:guitar_zero/features/tuner/widgets/privacy_policy_link.dart';

import '../../../support/fakes.dart';

void main() {
  const launcher = MethodChannel('plugins.flutter.io/url_launcher');
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  final launches = <MethodCall>[];

  setUp(() {
    launches.clear();
    binding.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
  });
  tearDown(() {
    binding.platformDispatcher.clearAccessibilityFeaturesTestValue();
    binding.defaultBinaryMessenger.setMockMethodCallHandler(launcher, null);
    binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      null,
    );
  });

  testWidgets('política nos ajustes abre a URL no navegador externo', (
    tester,
  ) async {
    binding.defaultBinaryMessenger.setMockMethodCallHandler(launcher, (
      call,
    ) async {
      launches.add(call);
      return true;
    });
    await tester.pumpWidget(GuitarZeroApp(engine: FakeTunerEngine()));
    await tester.pump();
    expect(launches, isEmpty);

    await tester.tap(find.text('VIOLÃO · STANDARD'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Política de privacidade'));
    await tester.tap(find.text('Política de privacidade'));
    await tester.pumpAndSettle();

    expect(launches, hasLength(1));
    expect(launches.single.method, 'launch');
    expect(
      launches.single.arguments,
      containsPair('url', PrivacyPolicyLink.policyUrl),
    );
    expect(launches.single.arguments, containsPair('useWebView', false));
    expect(launches.single.arguments, containsPair('useSafariVC', false));
    expect(find.text('Não foi possível abrir o navegador.'), findsNothing);
  });

  testWidgets('sem navegador permite copiar o link da política', (
    tester,
  ) async {
    binding.defaultBinaryMessenger.setMockMethodCallHandler(
      launcher,
      (_) async => false,
    );
    String? clipboard;
    binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          clipboard =
              (call.arguments as Map<Object?, Object?>)['text'] as String;
        }
        return null;
      },
    );
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: PrivacyPolicyLink())),
    );
    await tester.tap(find.text('Política de privacidade'));
    await tester.pumpAndSettle();
    expect(find.text('Não foi possível abrir o navegador.'), findsOneWidget);
    await tester.tap(find.text('Copiar link'));
    await tester.pumpAndSettle();
    expect(clipboard, PrivacyPolicyLink.policyUrl);
    expect(tester.takeException(), isNull);
  });

  testWidgets('erro do sistema ao abrir o navegador não fecha o app', (
    tester,
  ) async {
    binding.defaultBinaryMessenger.setMockMethodCallHandler(launcher, (
      _,
    ) async {
      throw PlatformException(code: 'ACTIVITY_NOT_FOUND');
    });
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: PrivacyPolicyLink())),
    );
    await tester.tap(find.text('Política de privacidade'));
    await tester.pumpAndSettle();
    expect(find.text('Copiar link'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
