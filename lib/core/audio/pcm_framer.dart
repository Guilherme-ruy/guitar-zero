import 'dart:typed_data';

import 'audio_frame.dart';

/// Converte blocos PCM16 (little-endian, mono) de tamanho arbitrário em
/// [AudioFrame]s de [frameSize] amostras, um a cada [hopSize] amostras
/// (frames sobrepostos quando hop < frameSize).
///
/// O timestamp de cada frame é o instante da sua **última** amostra,
/// calculado pela contagem de amostras desde o início — um relógio
/// monotônico e exato, imune a atrasos na entrega dos blocos.
class PcmFramer {
  PcmFramer({
    required this.sampleRate,
    required this.frameSize,
    required this.hopSize,
  }) : assert(frameSize > 0 && hopSize > 0 && hopSize <= frameSize),
       _buffer = Float32List(frameSize * 2);

  final int sampleRate;
  final int frameSize;
  final int hopSize;

  Float32List _buffer;
  int _length = 0;
  int _samplesConsumed = 0;
  int? _pendingLowByte;

  /// Adiciona [bytes] e devolve os frames completados (em ordem).
  List<AudioFrame> addPcm16(Uint8List bytes) {
    var i = 0;
    final pending = _pendingLowByte;
    if (pending != null && bytes.isNotEmpty) {
      _append(_toSample(pending, bytes[0]));
      _pendingLowByte = null;
      i = 1;
    }
    _ensureCapacity(_length + (bytes.length - i) ~/ 2);
    for (; i + 1 < bytes.length; i += 2) {
      _buffer[_length++] = _toSample(bytes[i], bytes[i + 1]);
    }
    if (i < bytes.length) _pendingLowByte = bytes[i];
    return _drainFrames();
  }

  /// Adiciona amostras já em ponto flutuante ([-1, 1]).
  List<AudioFrame> addSamples(Float32List samples) {
    _ensureCapacity(_length + samples.length);
    _buffer.setRange(_length, _length + samples.length, samples);
    _length += samples.length;
    return _drainFrames();
  }

  /// Descarta o áudio acumulado e reinicia o relógio.
  void reset() {
    _length = 0;
    _samplesConsumed = 0;
    _pendingLowByte = null;
  }

  static double _toSample(int low, int high) {
    var v = low | (high << 8);
    if (v >= 0x8000) v -= 0x10000;
    return v / 32768.0;
  }

  void _append(double sample) {
    _ensureCapacity(_length + 1);
    _buffer[_length++] = sample;
  }

  void _ensureCapacity(int needed) {
    if (needed <= _buffer.length) return;
    var capacity = _buffer.length;
    while (capacity < needed) {
      capacity *= 2;
    }
    final grown = Float32List(capacity)..setRange(0, _length, _buffer);
    _buffer = grown;
  }

  List<AudioFrame> _drainFrames() {
    final frames = <AudioFrame>[];
    var start = 0;
    while (_length - start >= frameSize) {
      final samples = Float32List.fromList(
        Float32List.sublistView(_buffer, start, start + frameSize),
      );
      final lastSampleIndex = _samplesConsumed + start + frameSize;
      frames.add(
        AudioFrame(
          samples: samples,
          sampleRate: sampleRate,
          timestamp: Duration(
            microseconds:
                lastSampleIndex * Duration.microsecondsPerSecond ~/ sampleRate,
          ),
        ),
      );
      start += hopSize;
    }
    if (start > 0) {
      _buffer.setRange(0, _length - start, _buffer, start);
      _length -= start;
      _samplesConsumed += start;
    }
    return frames;
  }
}
