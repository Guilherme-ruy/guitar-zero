import '../music/tuning.dart';

/// Parâmetros do afinador independentes da plataforma e da UI.
///
/// Fonte única dos valores padrão do pipeline temporal. Todos são pontos de
/// partida (a maioria inspirada no fgnass/tuner) e devem ser calibrados com
/// áudio real. Ver `docs/DSP_STRATEGY.md`.
class TunerConfig {
  const TunerConfig({
    this.tuning = Tuning.standard,
    this.minConfidence = 0.9,
    this.minFrequencyHz = 60,
    this.maxFrequencyHz = 450,
    this.harmonicJumpToleranceCents = 50,
    this.harmonicJumpConfirmDuration = const Duration(milliseconds: 600),
    this.harmonicJumpMemory = const Duration(seconds: 2),
    this.onsetThresholdDb = 3,
    this.onsetWindow = const Duration(milliseconds: 250),
    this.stabilityWindow = 3,
    this.stabilityToleranceCents = 20,
    this.smoothingMinCutoffHz = 0.6,
    this.smoothingBeta = 0.06,
    this.smoothingDerivativeCutoffHz = 1.0,
    this.smoothingResetGap = const Duration(milliseconds: 300),
    this.newNoteThresholdCents = 250,
    this.stringSwitchMarginCents = 30,
    this.maxStringDeviationCents = 350,
    this.inTuneEnterCents = 3,
    this.inTuneLeaveCents = 6,
    this.silenceHold = const Duration(milliseconds: 700),
  }) : assert(inTuneLeaveCents >= inTuneEnterCents),
       assert(stabilityWindow >= 1);

  final Tuning tuning;

  // --- Gates -------------------------------------------------------------

  /// Estimativas com confiança abaixo disto são descartadas. 0.90 é ponto de
  /// partida; microfone, AGC e ruído podem baixar a confiança de notas reais.
  final double minConfidence;

  /// Faixa aceita de fundamentais, em Hz.
  final double minFrequencyHz;
  final double maxFrequencyHz;

  // --- Proteção temporal contra saltos harmônicos (×2, ×3) ----------------

  /// Distância máxima, em cents, de uma razão exata 2:1, 3:1 (ou inversas)
  /// em relação à referência para o salto ser tratado como erro do detector.
  final double harmonicJumpToleranceCents;

  /// Por quanto tempo um salto harmônico **sem ataque** precisa persistir
  /// para ser aceito como mudança real.
  final Duration harmonicJumpConfirmDuration;

  /// Por quanto tempo a referência sobrevive sem estimativas (silêncio).
  final Duration harmonicJumpMemory;

  /// Aumento de RMS (dB) sobre o mínimo recente que caracteriza um ataque
  /// (corda tocada de novo): salto harmônico com ataque é aceito na hora.
  final double onsetThresholdDb;

  /// Janela em que se procura o mínimo de RMS para detectar ataque.
  final Duration onsetWindow;

  // --- Stability gate ---------------------------------------------------

  /// Quantas estimativas consecutivas precisam concordar. Comparar 3 e 5.
  final int stabilityWindow;

  /// Dispersão máxima (máx − mín), em cents, dentro da janela.
  final double stabilityToleranceCents;

  // --- Smoothing (One Euro, em cents) -----------------------------------

  final double smoothingMinCutoffHz;
  final double smoothingBeta;
  final double smoothingDerivativeCutoffHz;

  /// Intervalo sem estimativas após o qual o smoothing recomeça do zero.
  final Duration smoothingResetGap;

  /// Saltos maiores que isto são tratados como nova nota: o smoothing é
  /// reiniciado para o ponteiro não deslizar até a nota nova.
  final double newNoteThresholdCents;

  // --- Corda e afinado --------------------------------------------------

  /// Vantagem, em cents, que outra corda precisa ter para assumir.
  final double stringSwitchMarginCents;

  /// Frequências mais distantes que isto de qualquer corda são descartadas.
  final double maxStringDeviationCents;

  /// Entra em "afinado" com |cents| ≤ isto…
  final double inTuneEnterCents;

  /// …e só sai com |cents| > isto.
  final double inTuneLeaveCents;

  // --- Silêncio ---------------------------------------------------------

  /// Por quanto tempo a última leitura continua visível após o sinal sumir.
  final Duration silenceHold;
}
