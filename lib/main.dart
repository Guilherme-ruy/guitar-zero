import 'package:flutter/material.dart';

import 'app/app.dart';
import 'core/audio/microphone_audio_input.dart';
import 'core/tuner/frame_processor.dart';
import 'core/tuner/pitch_tuner_engine.dart';
import 'core/tuner/simulated_tuner_engine.dart';
import 'core/tuner/tuner_engine.dart';
import 'features/preferences/preferences_store.dart';
import 'features/preferences/tuner_preferences.dart';
import 'platform/record_pcm_recorder.dart';
import 'platform/shared_preferences_store.dart';

/// Modo demonstração (leituras simuladas, sem microfone):
/// `flutter run --dart-define=GUITAR_ZERO_DEMO=true`.
const bool kDemoMode = bool.fromEnvironment('GUITAR_ZERO_DEMO');

/// Composition root: o único lugar que escolhe implementações concretas.
/// Todos os componentes usam o `TunerConfig` padrão.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final preferences = TunerPreferences(await _openPreferences());
  runApp(
    kDemoMode
        ? GuitarZeroApp(
            engine: SimulatedTunerEngine(),
            preferences: preferences,
            isDemo: true,
          )
        : GuitarZeroApp(
            engine: createMicrophoneEngine(),
            preferences: preferences,
          ),
  );
}

/// Preferências locais; se o armazenamento falhar, o app segue com os
/// padrões em memória.
Future<PreferencesStore> _openPreferences() async {
  try {
    return await SharedPreferencesStore.open();
  } catch (_) {
    return InMemoryPreferencesStore();
  }
}

TunerEngine createMicrophoneEngine() => PitchTunerEngine.withProcessor(
  audioInput: MicrophoneAudioInput(recorder: RecordPcmRecorder()),
  // YIN + análise harmônica + pipeline temporal fora do isolate da UI.
  processor: IsolateFrameProcessor(),
);
