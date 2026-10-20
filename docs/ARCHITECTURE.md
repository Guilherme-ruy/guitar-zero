# Arquitetura

## Camadas

```
UI (widgets)                      lib/features/tuner/widgets, tuner_screen.dart
   ↓ lê estado
TunerController (ChangeNotifier)  lib/features/tuner/tuner_controller.dart
   ↓ depende só da interface; recebe TunerReading
TunerEngine (interface)           lib/core/tuner/tuner_engine.dart
   ↓ implementação PitchTunerEngine compõe:
AudioInput (interface)            lib/core/audio/          frames + timestamp
  MicrophoneAudioInput              PcmRecorder → PcmFramer (frames sobrepostos)
  RecordPcmRecorder               lib/platform/            plugin `record` (único import de plugin)
FrameProcessor                    lib/core/tuner/          onde o DSP roda:
  IsolateFrameProcessor             isolate dedicado (app), com backpressure
  InlineFrameProcessor              mesmo isolate (testes)
PitchDetector                     lib/core/dsp/
  HarmonicPitchDetector             YIN (semente) + HarmonicAnalyzer (FFT,
                                    oitava, refinamento, harmonicidade)
TunerPipeline                     lib/core/tuner/          síncrono, sem áudio:
  PitchFilter (cadeia)            lib/core/dsp/filters/    gates, saltos ×2/×3, estabilidade, One Euro
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
| `lib/features/preferences/` | Preferências visuais (instrumento, visual, nomes) e o contrato de armazenamento |
| `lib/platform/` | Adaptadores de plugins (`record`, `shared_preferences`) |
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
   `TunerEngine.diagnostics` emite, por frame, a estimativa bruta, o tempo de
   processamento e os frames descartados — usado só pelo painel de
   diagnóstico oculto, para calibração em aparelho.
7. `TunerController` mantém o estado de apresentação (status, leitura, corda
   ativa, cordas já afinadas) e notifica a UI.
8. Os widgets apenas interpolam visualmente entre leituras.

A estabilidade do ponteiro é responsabilidade do `TunerPipeline`. A animação
da UI é só interpolação curta entre leituras já estáveis. A UI não conhece
YIN, filtros, octave guard nem histereses.

## Modo manual

`TunerController.selectString` / `setAutoMode` → `TunerEngine.setTargetString`
→ `FrameProcessor` (mensagem para o isolate) → `TunerPipeline.setTargetString`.
No manual, o `StringTracker` é ignorado e os cents são medidos contra a corda
escolhida, dobrados por oitava em (−600, 600]: uma corda muito desafinada
(ex.: −300 c) continua associada a ela, e um erro de oitava do detector não
importa. Trocar o alvo descarta histereses, hold e resultados em trânsito do
isolate.

## Visual do instrumento

Imagens WebP em `assets/instruments/` (1x/2x/3x, CC0, geradas para o
projeto). `HeadstockLayout` guarda as coordenadas normalizadas (0–1 sobre a
imagem inteira) das chaves e dos botões, copiadas dos JSONs que acompanham
as imagens; um teste garante que continuam iguais. `HeadstockView` encaixa a
imagem (contain, ancorada embaixo, margem lateral de 32 dp para os botões
poderem sair do retângulo) e posiciona botões e conectores no mesmo
retângulo. Guitarra com imagem abaixo de 500 dp usa a coluna compacta de
botões. A imagem não muda com a corda ativa: só os botões. Botões de
30–48 dp, limitados pela distância ao vizinho; layout testado em 360×640,
375×667, 390×844 e 412×915 sem estouro nem sobreposição.

No Android, a Activity usa `FLAG_KEEP_SCREEN_ON`; o sistema volta a permitir
o desligamento automático da tela quando o app deixa de estar visível.

## Instrução e resultado na tela

O pipeline mantém a leitura por 700 ms (`SilenceHold`). Na UI, o
`TunerController` segura o último resultado ao vivo por mais 5 s
(`resultLinger`), atenuado: a pausa entre girar a tarraxa e tocar de novo
não apaga o resultado nem troca o texto. Textos:

| Situação | Texto |
| --- | --- |
| abrindo o microfone | Preparando o microfone… |
| sem permissão / falha | Permita o acesso ao microfone… / Microfone indisponível (+ Tentar novamente) |
| tocando ou até 5 s depois | Baixa — suba a afinação · Alta — desça a afinação · Afinada |
| manual, sem som | Toque a corda Mi (6ª) |
| automático, nada tocado ainda | Toque uma corda para começar |
| automático, último resultado afinado | Toque a próxima corda |
| automático, último resultado fora | Ajuste e toque a corda de novo |
| todas as cordas já afinadas | Todas as cordas afinadas |
| app em segundo plano | Afinador pausado |

## Pontos de extensão

- **Áudio nativo**: trocar o plugin por platform channel (Android
  `AudioRecord`, iOS `AVAudioEngine`) é implementar outro `PcmRecorder`.
  Framer, engine e UI não mudam.
- **Engine nativo inteiro**: se o DSP em Dart não for suficiente, outra
  implementação de `TunerEngine` pode delegar tudo ao nativo e emitir
  `TunerReading`. Controller e UI não mudam.
- **Isolate**: `PitchDetector` e `TunerPipeline` são síncronos e sem I/O; o
  `IsolateFrameProcessor` os executa num isolate dedicado. No máximo um frame
  em processamento e um pendente (o mais recente substitui o anterior);
  resultados anteriores a um reset/stop são descartados por um contador de
  geração; uma exceção no detector vira "silêncio" em vez de travar o worker.
- **Novas afinações / instrumentos**: `Tuning` é dado; `StringMatcher` é genérico.

## Ciclo de vida e privacidade

- Falhas da captura **durante o uso** (microfone tomado por outro app,
  interrupção, stream encerrado) chegam como erro `AudioInputException` no
  stream de leituras; o controller para o engine e mostra "Microfone
  indisponível" com a opção de tentar de novo.

- `TunerScreen` inicia a escuta ao abrir e para quando o app sai de primeiro
  plano (`paused`/`hidden`/`detached`). O microfone nunca fica ativo em
  segundo plano.
- Frames existem apenas em memória. Nenhuma implementação de `AudioInput` pode
  gravar em disco ou usar rede.
- O build Android de release não declara a permissão `INTERNET`.

## Estado atual

`main.dart` usa o microfone real: `MicrophoneAudioInput(RecordPcmRecorder)` +
`IsolateFrameProcessor` (`HarmonicPitchDetector` + `TunerPipeline`). Com
`--dart-define=GUITAR_ZERO_DEMO=true`, usa o `SimulatedTunerEngine`. A
captura ainda não foi validada em aparelho. `PitchTunerEngine` já está
implementado e testado com fakes.
