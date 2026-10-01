import 'dart:typed_data';

import 'package:record/record.dart';

import '../core/audio/microphone_audio_input.dart';

/// [PcmRecorder] implementado com o plugin `record` (BSD-3-Clause).
///
/// Configuração escolhida para afinação:
/// - PCM16 mono, sem compressão (o áudio nunca vai para arquivo);
/// - AGC, supressão de ruído e cancelamento de eco **desligados**;
/// - Android: fonte `VOICE_RECOGNITION`, que o Android CDD exige com AGC e
///   redução de ruído desligados e resposta aproximadamente plana — mais
///   portátil que `UNPROCESSED`, cujo suporte é opcional por aparelho.
class RecordPcmRecorder implements PcmRecorder {
  RecordPcmRecorder() : _recorder = AudioRecorder();

  final AudioRecorder _recorder;

  @override
  Future<bool> requestPermission() => _recorder.hasPermission();

  @override
  Future<Stream<Uint8List>> startPcm16Stream(int sampleRate) =>
      _recorder.startStream(
        RecordConfig(
          encoder: AudioEncoder.pcm16bits,
          sampleRate: sampleRate,
          numChannels: 1,
          androidConfig: const AndroidRecordConfig(
            audioSource: AndroidAudioSource.voiceRecognition,
            manageBluetooth: false,
          ),
        ),
      );

  @override
  Future<void> stop() async {
    await _recorder.stop();
  }

  @override
  Future<void> dispose() => _recorder.dispose();
}
