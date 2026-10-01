import 'audio_frame.dart';

/// Fonte de áudio do microfone.
///
/// Esta é a fronteira com a plataforma: a implementação concreta (plugin
/// Flutter ou código nativo via platform channel) fica atrás desta interface,
/// de forma que engine e UI não dependam de Android ou iOS.
///
/// Requisitos de privacidade para qualquer implementação:
/// - o áudio é entregue somente em memória, via [frames];
/// - nada é gravado em disco nem enviado pela rede.
abstract interface class AudioInput {
  /// Frames PCM mono, normalizados em [-1, 1]. Stream broadcast.
  Stream<AudioFrame> get frames;

  /// Solicita permissão (se necessário) e inicia a captura.
  ///
  /// Lança [AudioInputException] se a captura não puder começar.
  Future<void> start();

  /// Interrompe a captura e libera o microfone.
  Future<void> stop();

  /// Libera definitivamente os recursos.
  Future<void> dispose();
}

/// Motivo de falha ao iniciar a captura.
enum AudioInputFailure {
  /// O usuário negou acesso ao microfone.
  permissionDenied,

  /// Não há microfone disponível ou ele está em uso por outro app.
  unavailable,
}

class AudioInputException implements Exception {
  const AudioInputException(this.failure, [this.message]);

  final AudioInputFailure failure;
  final String? message;

  @override
  String toString() =>
      'AudioInputException($failure${message == null ? '' : ': $message'})';
}
