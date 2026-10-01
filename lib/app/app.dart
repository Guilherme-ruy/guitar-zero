import 'package:flutter/material.dart';

import '../core/tuner/tuner_engine.dart';
import '../features/preferences/preferences_store.dart';
import '../features/preferences/tuner_preferences.dart';
import '../features/tuner/tuner_screen.dart';
import 'theme.dart';

class GuitarZeroApp extends StatelessWidget {
  GuitarZeroApp({
    super.key,
    required this.engine,
    TunerPreferences? preferences,
    this.isDemo = false,
  }) : preferences =
           preferences ?? TunerPreferences(InMemoryPreferencesStore());

  final TunerEngine engine;

  /// Preferências visuais; por padrão em memória (testes).
  final TunerPreferences preferences;

  /// Indica que [engine] é simulado; a UI exibe um selo "DEMO".
  final bool isDemo;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Guitar Zero',
      debugShowCheckedModeBanner: false,
      theme: buildGzTheme(),
      home: TunerScreen(
        engine: engine,
        preferences: preferences,
        isDemo: isDemo,
      ),
    );
  }
}
