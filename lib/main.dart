import 'package:flutter/material.dart';

import 'app/app.dart';
import 'core/tuner/simulated_tuner_engine.dart';

/// Composition root: o único lugar que escolhe implementações concretas.
///
/// Enquanto a captura de áudio e o DSP não existem, o app usa um engine
/// simulado. Quando estiverem prontos, aqui passará a ser criado um
/// `PitchTunerEngine` com `AudioInput` e `PitchDetector` reais.
void main() {
  runApp(GuitarZeroApp(engine: SimulatedTunerEngine(), isDemo: true));
}
