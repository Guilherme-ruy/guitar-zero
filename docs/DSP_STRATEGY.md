# Estratégia de DSP — proposta para revisão

> Status: **proposta**. Nada aqui está implementado ainda. Revisar antes de
> iniciar a fase de DSP.

## Objetivo

Indicação suave e confiável: ao tocar uma corda, o ponteiro deve estabilizar
rápido (< ~150 ms), ficar parado numa nota sustentada e acompanhar o giro da
tarraxa sem atraso perceptível. Ruído, fala e erros de oitava não podem mover o
ponteiro.

## Faixa de interesse

Fundamentais da afinação Standard: 82.41 Hz (E2) a 329.63 Hz (E4). Faixa de
busca proposta: **70–420 Hz** (folga para cordas bem desafinadas e drop D).

## Captura (`AudioInput`)

- Mono, PCM float normalizado, 44.1 ou 48 kHz (o que o aparelho oferecer).
- Janela de análise de **2048 amostras** (~43 ms a 48 kHz) — cobre mais de 3
  períodos de E2 (12,1 ms) e respeita `W ≥ 2·τmax` do YIN
  (`τmax = 48000/70 ≈ 686`).
- Hop de **1024 amostras** (50% de overlap) → ~47 estimativas/s.
- Opções de implementação (decisão pendente):
  1. plugin `record` (stream PCM16, Android + iOS, mantido) — menor esforço;
  2. platform channel próprio (`AudioRecord` / `AVAudioEngine`) — controle
     total de buffer e latência, mais código nativo.
  Recomendação: começar por (1) atrás de `AudioInput`, medir, e migrar para
  (2) só se necessário. A permissão em runtime virá do próprio plugin ou de
  `permission_handler` — também a decidir.

## Pipeline proposto

Cada etapa é um `PitchDetector` ou `PitchFilter` independente e testável.

1. **Pré-processamento** (dentro do detector): remoção de DC e high-pass
   suave (~60 Hz) para tirar ruído de manuseio/vento.
2. **Noise gate por energia**: RMS em dBFS com histerese (abre em X, fecha em
   X−6 dB). Abaixo disso, `null` — evita processar silêncio.
3. **YIN** (de Cheveigné & Kawahara, 2002):
   diferença → CMNDF → primeiro mínimo abaixo do limiar absoluto
   (0.10–0.15) → interpolação parabólica → `f = sr/τ`.
   `confidence = 1 − d'(τ)`. Custo O(W·τmax) ≈ 1,4 M operações/frame;
   se pesado demais, calcular a função diferença via FFT e/ou rodar em isolate.
4. **Restrição de faixa**: descarta estimativas fora de 70–420 Hz.
5. **Stability gate**: só libera estimativas quando N consecutivas (ex.: 3)
   concordam dentro de ±K cents (ex.: 30). Rejeita fala e transientes do ataque.
6. **Proteção contra oitava**: o YIN com "primeiro mínimo" já reduz o problema;
   adicionalmente, se uma estimativa salta ~±1200 cents em relação ao valor
   estável com confiança menor, ela é descartada.
7. **Mediana curta** (3–5 amostras) para remover outliers isolados.
8. **One Euro Filter no domínio de cents**: parado quando o sinal está estável,
   responsivo quando o usuário gira a tarraxa. Parâmetros `minCutoff` e `beta`
   calibrados com gravações reais.
9. **Hold no silêncio** (~300 ms) para o ponteiro não sumir entre palhetadas.
10. **Histerese de corda**: a corda detectada só troca após M frames
    consecutivos favorecendo outra, evitando "piscar" entre cordas vizinhas.

Etapas avançadas, só se os testes mostrarem necessidade:

- refinamento harmônico via FFT (localizar a série harmônica a partir do YIN e
  refinar com interpolação sub-bin), como descrito no projeto fgnass/tuner;
- ponderação A dos harmônicos para ignorar rumble de baixa frequência.

## Tolerância de afinado

Inicial: ±5 cents (`TunerConfig.inTuneToleranceCents`). Calibrar com uso real;
considerar exigir permanência por ~200 ms dentro da tolerância antes da
animação de confirmação.

## Validação

- **Sinais sintéticos** (testes unitários): senoides puras em cada corda e com
  desvios conhecidos; ondas com harmônicos fortes; fundamental ausente (teste
  de oitava); ruído branco (deve retornar `null`); ataque + decaimento.
- **Gravações reais** curtas (fixtures WAV pequenas, gravadas para o projeto)
  de violão e guitarra, para medir erro em cents, tempo até estabilizar e
  taxa de erros de oitava.
- **Benchmark** de tempo por frame em Dart, para decidir sobre isolate/FFT.

## Aprendizados das referências

Código-fonte estudado (clonado via git, fora do repositório):

- fgnass/tuner @ `b59d8b9` (MIT) — `src/lib/pitch.ts`, `src/lib/oneEuro.ts`,
  `src/hooks/usePitch.ts`, `src/lib/notes.ts`, `src/hooks/useTuningSession.ts`.
- PitchKit @ `26a7909` (Apache 2.0, sem arquivo NOTICE) —
  `YinPitchDetector.kt`, `TunerEngine.kt`, `AudioCapture.kt`, `NoteMapper.kt`.

### fgnass/tuner (referência principal — pipeline mais maduro)

| Técnica | Parâmetros usados |
| --- | --- |
| Janela de captura | 8192 amostras (~186 ms a 44.1 kHz), detecção a cada 40 ms com overlap |
| Filtros de entrada | high-pass em `0.7 × fmin`, low-pass em 5 kHz (mantém harmônicos) |
| Captura | `echoCancellation`, `noiseSuppression` e `autoGainControl` **desligados** |
| Noise gate | RMS < 0.004 → sem pitch |
| YIN | janela de integração = metade do buffer, lag limitado a `[sr/fmax, sr/fmin]`, limiar 0.2; sem dip, aceita o mínimo global se < 0.6 |
| Gate de confiança | só aceita clarity ≥ **0.9** (descarta o ataque não periódico da palhetada) |
| Stability gate | últimas **5** detecções (~200 ms) dentro de **20 cents** |
| Oitava (espectral) | se há picos proeminentes em `f0/2` **e** `1.5·f0`, desce uma oitava (YIN travou no 2º harmônico — comum no E2 em microfone de celular) |
| Oitava (temporal) | "octave snap": salto de ~12 semitons (±1) em relação ao valor atual é dobrado de volta |
| Refinamento | série harmônica no FFT (Hann), interpolação parabólica sub-bin + frequência instantânea por diferença de fase, média ponderada (A-weighting × magnitude) de `f_h / h` |
| Smoothing | One Euro no domínio de cents, `minCutoff 0.6`, `beta 0.06`, `dt` real |
| Nova nota | salto > 250 cents → reinicia o filtro (snap, sem deslizar) |
| Hold | mantém a última leitura 700 ms após o sinal sumir |
| Corda (histerese) | troca de corda só se a rival for melhor por ≥ 30 cents |
| Afinado (histerese) | entra em ≤ 3 cents, sai em > 6 cents |

### PitchKit (referência secundária — mais simples)

- YIN clássico, limiar 0.15, sobre o buffer inteiro de 8192 (custo
  O(N²/4) ≈ 16 M operações/frame, sem limitar o lag à faixa do instrumento).
- Remoção de DC + high-pass de 1 polo com `α = 0.95`. A 44.1 kHz isso dá
  corte de ~350 Hz, **atenuando E2–E4** — armadilha a evitar.
- Gate RMS 0.01; suavização apenas por maioria do nome da nota (2 de 4
  frames), sem suavizar cents.
- Captura via `AudioRecord` (PCM16 mono, 44.1 kHz), leitura em thread de I/O,
  `CONFLATED` (processa só o frame mais recente sob carga). Comenta que
  `VOICE_RECOGNITION` tende a desligar AGC/supressão de ruído do sistema.

### O que muda na proposta

1. **Gate de confiança**: subir `TunerConfig.minConfidence` de 0.5 para ~0.9.
2. **Stability gate**: 5 detecções / 20 cents como ponto de partida.
3. **Histerese de corda** por margem em cents (30), não por contagem de frames.
4. **Afinado com histerese** (entra 3 / sai 6 cents) em vez de ±5 fixo.
5. **Sinal cru**: a implementação de `AudioInput` precisa desligar AGC, supressão
   de ruído e cancelamento de eco (no Android, fonte `UNPROCESSED` ou
   `VOICE_RECOGNITION`). Isso pesa na escolha entre plugin e código nativo.
6. **Janela**: 4096–8192 amostras com detecção a cada ~40 ms (overlap), em vez
   de 2048/1024. Lag do YIN sempre limitado à faixa do instrumento.
7. **High-pass** de segunda ordem perto de `0.7 × 70 Hz`, nunca o 1 polo α=0.95.
8. **Oitava**: começar com octave snap temporal + faixa restrita; adicionar a
   verificação de sub-harmônico (f0/2 e 1.5·f0) junto do refinamento FFT,
   pois ela depende do espectro.
9. **Mediana** deixa de ser necessária se o stability gate + One Euro bastarem
   — avaliar com gravações antes de adicionar.

### Licenças

Se algum trecho for portado de forma próxima (ex.: `refine()` do fgnass/tuner
ou o One Euro), o arquivo Dart receberá comentário de origem e o aviso MIT
será adicionado em `THIRD_PARTY_NOTICES.md`. Para PitchKit (Apache 2.0) vale o
mesmo, indicando as alterações. A preferência continua sendo implementar a
partir dos artigos, usando os projetos como referência de parâmetros.

## Referências

- de Cheveigné & Kawahara, *YIN*, JASA 2002.
- Casiez, Roussel & Vogel, *1€ Filter*, CHI 2012.
