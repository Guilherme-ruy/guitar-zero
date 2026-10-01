import 'dart:async';
import 'dart:typed_data';

import 'audio_frame.dart';
import 'audio_input.dart';
import 'pcm_framer.dart';

/// Parâmetros da captura.
class AudioCaptureConfig {
  const AudioCaptureConfig({
    this.sampleRate = 44100,
    this.frameSize = 4096,
    this.hop = const Duration(milliseconds: 40),
  });

  /// 44.1 kHz é a única taxa garantida em todos os aparelhos Android.
  final int sampleRate;

  /// Janela de análise entregue ao detector (4096 @ 44.1 kHz ≈ 93 ms).
  final int frameSize;

  /// Intervalo entre frames consecutivos (frames se sobrepõem).
  final Duration hop;

  int get hopSize => (sampleRate * hop.inMicroseconds / 1e6).round();
}

/// Fronteira mínima com o gravador da plataforma. Permite testar
/// [MicrophoneAudioInput] sem dispositivo e trocar o plugin por código
/// nativo no futuro sem tocar no resto do app.
abstract interface class PcmRecorder {
  /// Pede a permissão (se ainda não concedida) e informa se ela existe.
  Future<bool> requestPermission();

  /// Inicia a captura mono PCM16 em [sampleRate], sem AGC, supressão de
  /// ruído nem cancelamento de eco.
  Future<Stream<Uint8List>> startPcm16Stream(int sampleRate);

  Future<void> stop();

  Future<void> dispose();
}

/// [AudioInput] que lê o microfone por um [PcmRecorder] e entrega frames
/// sobrepostos com timestamps exatos (ver [PcmFramer]).
///
/// Privacidade: as amostras só existem em memória, dentro dos frames; nada é
/// gravado em disco nem enviado pela rede.
class MicrophoneAudioInput implements AudioInput {
  MicrophoneAudioInput({
    required this._recorder,
    this.config = const AudioCaptureConfig(),
  }) : _framer = PcmFramer(
         sampleRate: config.sampleRate,
         frameSize: config.frameSize,
         hopSize: config.hopSize,
       );

  final AudioCaptureConfig config;
  final PcmRecorder _recorder;
  final PcmFramer _framer;
  final StreamController<AudioFrame> _frames =
      StreamController<AudioFrame>.broadcast();
  StreamSubscription<Uint8List>? _subscription;

  @override
  Stream<AudioFrame> get frames => _frames.stream;

  @override
  Future<void> start() async {
    if (_subscription != null) return;
    final bool granted;
    try {
      granted = await _recorder.requestPermission();
    } catch (e) {
      throw AudioInputException(AudioInputFailure.unavailable, '$e');
    }
    if (!granted) {
      throw const AudioInputException(AudioInputFailure.permissionDenied);
    }
    _framer.reset();
    try {
      final stream = await _recorder.startPcm16Stream(config.sampleRate);
      _subscription = stream.listen(
        (bytes) {
          for (final frame in _framer.addPcm16(bytes)) {
            _frames.add(frame);
          }
        },
        onError: (Object e) => _frames.addError(
          AudioInputException(AudioInputFailure.unavailable, '$e'),
        ),
      );
    } catch (e) {
      throw AudioInputException(AudioInputFailure.unavailable, '$e');
    }
  }

  @override
  Future<void> stop() async {
    await _subscription?.cancel();
    _subscription = null;
    await _recorder.stop();
    _framer.reset();
  }

  @override
  Future<void> dispose() async {
    await stop();
    await _recorder.dispose();
    await _frames.close();
  }
}
