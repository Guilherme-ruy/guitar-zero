import 'dart:typed_data';

/// Um bloco de amostras PCM mono capturadas do microfone.
///
/// As amostras são normalizadas em ponto flutuante no intervalo [-1, 1].
/// Frames existem apenas em memória e são descartados após o processamento.
class AudioFrame {
  const AudioFrame({required this.samples, required this.sampleRate});

  final Float32List samples;

  /// Taxa de amostragem, em Hz (ex.: 44100, 48000).
  final int sampleRate;

  /// Duração do frame.
  Duration get duration => Duration(
    microseconds: samples.length * Duration.microsecondsPerSecond ~/ sampleRate,
  );
}
