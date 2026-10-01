import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:guitar_zero/core/audio/pcm_framer.dart';

Uint8List pcm16(List<int> values) {
  final data = ByteData(values.length * 2);
  for (var i = 0; i < values.length; i++) {
    data.setInt16(i * 2, values[i], Endian.little);
  }
  return data.buffer.asUint8List();
}

void main() {
  test('converte PCM16 LE para [-1, 1]', () {
    final framer = PcmFramer(sampleRate: 4, frameSize: 4, hopSize: 4);
    final frames = framer.addPcm16(pcm16([0, 16384, -32768, 32767]));
    expect(frames.single.samples, [0, 0.5, -1, closeTo(1, 1e-4)]);
  });

  test('frames sobrepostos: tamanho fixo, um a cada hop', () {
    final framer = PcmFramer(sampleRate: 10, frameSize: 6, hopSize: 2);
    final frames = framer.addPcm16(pcm16(List.generate(12, (i) => i * 1000)));
    expect(frames, hasLength(4)); // inícios em 0, 2, 4, 6
    expect(frames[0].samples.first, 0);
    expect(frames[1].samples.first, closeTo(2000 / 32768, 1e-9));
    expect(frames[3].samples.last, closeTo(11000 / 32768, 1e-9));
    for (final f in frames) {
      expect(f.samples, hasLength(6));
    }
  });

  test('timestamp = instante da última amostra, pela contagem de amostras', () {
    final framer = PcmFramer(sampleRate: 1000, frameSize: 100, hopSize: 40);
    final frames = <Duration>[];
    // Entregues em blocos irregulares.
    for (final size in [37, 250, 3, 110]) {
      frames.addAll(
        framer.addPcm16(pcm16(List.filled(size, 0))).map((f) => f.timestamp),
      );
    }
    // 400 amostras: frames terminando em 100, 140, …, 380 ms.
    expect(frames, [
      for (var end = 100; end <= 400; end += 40) Duration(milliseconds: end),
    ]);
  });

  test('blocos com número ímpar de bytes', () {
    final framer = PcmFramer(sampleRate: 4, frameSize: 2, hopSize: 2);
    final bytes = pcm16([1000, -2000]);
    expect(framer.addPcm16(Uint8List.sublistView(bytes, 0, 3)), isEmpty);
    final frames = framer.addPcm16(Uint8List.sublistView(bytes, 3));
    expect(frames.single.samples, [
      closeTo(1000 / 32768, 1e-9),
      closeTo(-2000 / 32768, 1e-9),
    ]);
  });

  test('frames são cópias independentes do buffer interno', () {
    final framer = PcmFramer(sampleRate: 4, frameSize: 2, hopSize: 1);
    final first = framer.addPcm16(pcm16([100, 200])).single;
    framer.addPcm16(pcm16([300, 400, 500]));
    expect(first.samples[0], closeTo(100 / 32768, 1e-9));
  });

  test('reset descarta o acumulado e reinicia o relógio', () {
    final framer = PcmFramer(sampleRate: 1000, frameSize: 10, hopSize: 10)
      ..addPcm16(pcm16(List.filled(25, 1)))
      ..reset();
    final frame = framer.addPcm16(pcm16(List.filled(10, 0))).single;
    expect(frame.timestamp, const Duration(milliseconds: 10));
    expect(frame.samples, everyElement(0));
  });

  test('blocos grandes (mais que 2 frames de uma vez)', () {
    final framer = PcmFramer(sampleRate: 44100, frameSize: 4096, hopSize: 1764);
    final frames = framer.addPcm16(pcm16(List.filled(44100, 0)));
    // (44100 − 4096) / 1764 + 1 = 23 frames.
    expect(frames, hasLength(23));
  });
}
