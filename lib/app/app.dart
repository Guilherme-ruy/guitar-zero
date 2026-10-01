import 'package:flutter/material.dart';

import '../core/tuner/tuner_engine.dart';
import '../features/tuner/tuner_screen.dart';
import 'theme.dart';

class GuitarZeroApp extends StatelessWidget {
  const GuitarZeroApp({super.key, required this.engine, this.isDemo = false});

  final TunerEngine engine;

  /// Indica que [engine] é simulado; a UI exibe um selo "DEMO".
  final bool isDemo;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Guitar Zero',
      debugShowCheckedModeBanner: false,
      theme: buildGzTheme(),
      home: TunerScreen(engine: engine, isDemo: isDemo),
    );
  }
}
