# Arquitetura

## Camadas

```
UI (widgets)                      lib/features/tuner/widgets, tuner_screen.dart
   ↓ lê estado
TunerController (ChangeNotifier)  lib/features/tuner/tuner_controller.dart
   ↓ depende só da interface; recebe TunerReading
TunerEngine (interface)           lib/core/tuner/tuner_engine.dart
   ↓ implementação PitchTunerEngine compõe:
AudioInput (interface)            lib/core/audio/          captura PCM + timestamp
PitchDetector                     lib/core/dsp/
  HarmonicPitchDetector             YIN (semente) + HarmonicAnalyzer (FFT,
                                    oitava, refinamento, harmonicidade)
TunerPipeline                     lib/core/tuner/          síncrono, sem áudio:
  PitchFilter (cadeia)            lib/core/dsp/filters/    gates, oitava, estabilidade, One Euro
  StringTracker                   lib/core/music/          corda com histerese
  InTuneHysteresis, SilenceHold   lib/core/tuner/          afinado e hold
```

Regra de dependência: `core/` não importa Flutter (exceto `dart:` e
`package:flutter/foundation.dart` se um dia for necessário) e nunca importa
`features/` ou `app/`. A UI nunca importa `core/audio` nem `core/dsp`.

| Pasta | Responsabilidade |
| --- | --- |
| `lib/app/` | App raiz, tema e tokens visuais (`GzColors`, `GzDurations`) |
| `lib/core/music/` | Conhecimento musical puro: notas, cents, afinações, corda mais provável |
| `lib/core/audio/` | Contrato de captura do microfone (`AudioInput`, `AudioFrame`) |
| `lib/core/dsp/` | Contratos de detecção de pitch e filtros (`PitchDetector`, `PitchFilter`) |
| `lib/core/tuner/` | Engine que orquestra o pipeline e produz `TunerReading` |
| `lib/features/tuner/` | Controller e widgets da tela do afinador |
| `tool/` | Relatório de caracterização e benchmark do detector (fora do CI) |
| `lib/main.dart` | Composition root: único lugar que escolhe implementações concretas |

## Fluxo de dados

1. `AudioInput.frames` entrega blocos PCM mono `Float32List` em [-1, 1], com
   timestamp monotônico.
2. `PitchDetector.detect` estima
   `PitchEstimate(frequencyHz, periodicity, harmonicity, rms)` ou `null`.
   No `HarmonicPitchDetector`, o YIN dá a semente e o `HarmonicAnalyzer`
   (espectro do mesmo frame, sem estado) corrige a oitava e refina.
3. `TunerPipeline` aplica a cadeia de `PitchFilter` (gate de confiança, faixa,
   proteção temporal de oitava, stability gate, One Euro), a histerese de
   corda, a histerese de afinado e o hold de silêncio. Usa timestamps.
4. `TunerEngine.readings` emite `TunerReading` (ou `null` em silêncio).
7. `TunerController` mantém o estado de apresentação (status, leitura, corda
   ativa, cordas já afinadas) e notifica a UI.
8. Os widgets apenas interpolam visualmente entre leituras.

A estabilidade do ponteiro é responsabilidade do `TunerPipeline`. A animação
da UI é só interpolação curta entre leituras já estáveis. A UI não conhece
YIN, filtros, octave guard nem histereses.

## Pontos de extensão

- **Áudio nativo**: uma implementação de `AudioInput` via plugin ou platform
  channel (Android `AudioRecord`, iOS `AVAudioEngine`). Nada acima muda.
- **Engine nativo inteiro**: se o DSP em Dart não for suficiente, outra
  implementação de `TunerEngine` pode delegar tudo ao nativo e emitir
  `TunerReading`. Controller e UI não mudam.
- **Isolate**: `PitchDetector` é síncrono e sem I/O justamente para poder rodar
  em um isolate dentro do engine, se o custo de CPU exigir.
- **Novas afinações / instrumentos**: `Tuning` é dado; `StringMatcher` é genérico.

## Ciclo de vida e privacidade

- `TunerScreen` inicia a escuta ao abrir e para quando o app sai de primeiro
  plano (`paused`/`hidden`/`detached`). O microfone nunca fica ativo em
  segundo plano.
- Frames existem apenas em memória. Nenhuma implementação de `AudioInput` pode
  gravar em disco ou usar rede.
- O build Android de release não declara a permissão `INTERNET`.

## Estado atual

`main.dart` usa `SimulatedTunerEngine` (selo DEMO na tela) porque ainda não
existe `AudioInput` concreto. O `YinPitchDetector` (Dart puro) já existe e é
testado, inclusive dentro do `PitchTunerEngine`. `PitchTunerEngine` já está
implementado e testado com fakes.
