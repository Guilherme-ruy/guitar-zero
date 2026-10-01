import '../music/guitar_string.dart';
import 'tuner_config.dart';
import 'tuner_diagnostics.dart';
import 'tuner_reading.dart';

/// Ponto de entrada do afinador para a camada de estado.
///
/// A UI e os controllers dependem apenas desta interface. A implementação
/// pode combinar captura de áudio e DSP em Dart ([PitchTunerEngine]), ser
/// simulada ([SimulatedTunerEngine]) ou, no futuro, delegar a um engine
/// nativo, sem mudanças na interface do aplicativo.
abstract interface class TunerEngine {
  TunerConfig get config;

  /// Leituras contínuas. `null` significa que nenhuma nota está sendo
  /// detectada no momento (silêncio, ruído ou baixa confiança). Falhas da
  /// captura durante o uso chegam como erro `AudioInputException`.
  Stream<TunerReading?> get readings;

  /// Medidas por frame para depuração/calibração (pode ser vazio).
  Stream<TunerDiagnostics> get diagnostics;

  /// Modo manual: mede tudo contra [string]. `null` = automático.
  void setTargetString(GuitarString? string);

  /// Inicia a escuta. Pode lançar `AudioInputException`.
  Future<void> start();

  Future<void> stop();

  Future<void> dispose();
}
