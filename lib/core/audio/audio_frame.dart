import 'dart:typed_data';

/// Um bloco de amostras PCM mono capturadas do microfone.
///
/// As amostras são normalizadas em ponto flutuante no intervalo [-1, 1].
/// Frames existem apenas em memória e são descartados após o processamento.
class AudioFrame {
  const AudioFrame({
    required this.samples,
    required this.sampleRate,
    required this.timestamp,
  });

  final Float32List samples;

  /// Taxa de amostragem, em Hz (ex.: 44100, 48000).
  final int sampleRate;

  /// Instante da captura em um relógio monotônico (ex.: posição do stream
  /// desde o início da escuta). Os filtros temporais (smoothing, hold,
  /// proteção de oitava) usam este valor — não o relógio de parede nem a
  /// contagem de frames.
  final Duration timestamp;

  /// Duração do frame.
  Duration get duration => Duration(
    microseconds: samples.length * Duration.microsecondsPerSecond ~/ sampleRate,
  );
}
