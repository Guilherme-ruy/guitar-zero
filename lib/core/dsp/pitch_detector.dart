import '../audio/audio_frame.dart';
import 'pitch_estimate.dart';

/// Estima a frequência fundamental de um [AudioFrame].
///
/// Implementações previstas: YIN (estratégia inicial), e possivelmente
/// variantes com FFT ou análise harmônica. Ver `docs/DSP_STRATEGY.md`.
///
/// Contrato:
/// - síncrono e sem I/O, para poder rodar em um isolate se necessário;
/// - retorna `null` quando não há pitch identificável (silêncio, ruído);
/// - pode manter estado interno entre frames; [reset] o descarta.
abstract interface class PitchDetector {
  PitchEstimate? detect(AudioFrame frame);

  void reset();
}
