import 'dart:io';
import 'dart:typed_data';

/// Lê o chunk `data` de um WAV PCM16 (bytes little-endian).
Uint8List readWavPcm16(File file) {
  final bytes = file.readAsBytesSync();
  final data = ByteData.sublistView(bytes);
  var offset = 12;
  while (offset + 8 <= bytes.length) {
    final id = String.fromCharCodes(bytes.sublist(offset, offset + 4));
    final size = data.getUint32(offset + 4, Endian.little);
    if (id == 'data') {
      return Uint8List.sublistView(bytes, offset + 8, offset + 8 + size);
    }
    offset += 8 + size + (size.isOdd ? 1 : 0);
  }
  throw FormatException('sem chunk data: ${file.path}');
}
