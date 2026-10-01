import 'package:flutter/material.dart';

import 'app/app.dart';
import 'core/audio/microphone_audio_input.dart';
import 'core/tuner/frame_processor.dart';
import 'core/tuner/pitch_tuner_engine.dart';
import 'core/tuner/simulated_tuner_engine.dart';
import 'core/tuner/tuner_engine.dart';
import 'platform/record_pcm_recorder.dart';

/// Modo demonstração (leituras simuladas, sem microfone):
/// `flutter run --dart-define=GUITAR_ZERO_DEMO=true`.
const bool kDemoMode = bool.fromEnvironment('GUITAR_ZERO_DEMO');

/// Composition root: o único lugar que escolhe implementações concretas.
/// Todos os componentes usam o `TunerConfig` padrão.
void main() {
  runApp(
    kDemoMode
        ? GuitarZeroApp(engine: SimulatedTunerEngine(), isDemo: true)
        : GuitarZeroApp(engine: createMicrophoneEngine()),
  );
}

TunerEngine createMicrophoneEngine() => PitchTunerEngine.withProcessor(
  audioInput: MicrophoneAudioInput(recorder: RecordPcmRecorder()),
  // YIN + análise harmônica + pipeline temporal fora do isolate da UI.
  processor: IsolateFrameProcessor(),
);
