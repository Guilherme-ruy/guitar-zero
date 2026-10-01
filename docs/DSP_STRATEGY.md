# Estratégia de DSP

> Status: **aprovada com ajustes**. Fase 1 (YIN) e fase 2 (filtros temporais)
> implementadas e validadas com sinais sintéticos — ver [Fases](#fases),
> [Resultados da fase 1](#resultados-da-fase-1--yin) e
> [Resultados da fase 2](#resultados-da-fase-2--pipeline-temporal).

## Objetivo

Indicação suave e confiável: ao tocar uma corda, o ponteiro deve estabilizar
rápido (meta: < ~150 ms), ficar parado numa nota sustentada e acompanhar o
giro da tarraxa sem atraso perceptível. Ruído, fala e erros de oitava não
podem mover o ponteiro.

## Faixa de interesse

Fundamentais da afinação Standard: 82.41 Hz (E2) a 329.63 Hz (E4). Faixa de
busca padrão: **60–450 Hz** — margem para um E2 bem desafinado, drop D/C e
extensões futuras. Configurável (`YinConfig.minFrequencyHz/maxFrequencyHz`).

## Parâmetros configuráveis e o conflito de latência

Nenhum destes valores é definitivo; todos são parâmetros e serão comparados
com gravações reais.

| Parâmetro | Opções a comparar | Ponto inicial |
| --- | --- | --- |
| `frameSize` (janela de análise) | 4096 · 8192 | a decidir |
| hop (intervalo entre detecções) | ~20–40 ms | ~40 ms |
| stability gate (detecções concordantes) | 3 · 5 | a decidir |
| `minConfidence` | — | **0.90** (inspirado no fgnass/tuner) |
| limiar absoluto do YIN | 0.10–0.20 | 0.15 |

Duração da janela:

| frameSize | 44.1 kHz | 48 kHz |
| --- | --- | --- |
| 4096 | 93 ms | 85 ms |
| 8192 | 186 ms | 171 ms |

Tempo aproximado até a **primeira leitura estável** após a palhetada ≈
`janela + (N − 1) × hop` (sem contar o ataque, que a janela precisa
"atravessar", nem a latência do sistema de áudio):

| 48 kHz, hop 40 ms | gate 3 | gate 5 |
| --- | --- | --- |
| 4096 (85 ms) | ~165 ms | ~245 ms |
| 8192 (171 ms) | ~251 ms | ~331 ms |

**Conflito documentado**: a meta de < 150 ms é incompatível com 8192 + 5
detecções (o fgnass/tuner aceita ~330 ms nessa configuração). Mesmo 4096 + 3
fica perto do limite. Alternativas a avaliar depois: hop menor (~20 ms),
gate menor, ou exibir a leitura provisória antes do gate fechar. Não será
resolvido agora; a escolha virá de medições com áudio real.

`minConfidence = 0.90` é ponto de partida: microfones de celular diferentes,
AGC e ruído ambiente podem baixar a confiança de notas reais. O valor precisa
ser validado em aparelhos.

## Captura (`AudioInput`) — fase futura

- Mono, PCM float normalizado, 44.1 ou 48 kHz (o que o aparelho oferecer).
- Sinal cru: AGC, supressão de ruído e cancelamento de eco desligados.
- O detector aceita qualquer tamanho de frame ≥ `2 × (sr/fmin) + 1`
  (1601 amostras a 48 kHz com fmin = 60 Hz); o `AudioInput` entregará frames
  de `frameSize` com overlap.
- Opções de implementação (decisão pendente): plugin `record` atrás de
  `AudioInput`, ou platform channel próprio (`AudioRecord` / `AVAudioEngine`).

## Pipeline

Cada etapa é um `PitchDetector` ou `PitchFilter` independente e testável.

1. **Remoção de DC** (detector).
2. **RMS / noise gate** (detector): abaixo de `minRms`, sem estimativa.
3. **YIN** (detector): diferença → CMNDF → primeiro mínimo abaixo do limiar
   → interpolação parabólica → `f = sr/τ`, `confidence = 1 − d'(τ)`.
4. **Restrição de faixa** (detector): lag limitado a `[sr/fmax, sr/fmin]`;
   mínimo encostado na borda da faixa não é aceito.
5. **Gate de confiança** (`ConfidenceGate`): `confidence < minConfidence` → sem pitch.
6. **Gate de faixa** (`RangeGate`).
7. **Proteção temporal de oitava** (`OctaveJumpGuard`); verificação espectral
   de sub-harmônico fica para a fase com FFT.
8. **Stability gate** (`StabilityGate`): N estimativas dentro de K cents.
9. **One Euro em cents** (`PitchSmoother`), com reset em nova nota.
10. **Histerese de corda** (`StringTracker`) e **de afinado**
    (`InTuneHysteresis`).
11. **Hold no silêncio** (`SilenceHold`).

Etapas 5–11 ficam no `TunerPipeline` (fase 2). Detalhes em
[Resultados da fase 2](#resultados-da-fase-2--pipeline-temporal).

Etapas avançadas, só se os testes mostrarem necessidade: refinamento harmônico
via FFT, A-weighting, high-pass de 2ª ordem, mediana.

## Fases

1. **YIN em Dart puro + testes sintéticos** — concluída.
2. **Filtros temporais e histereses** (gates, octave guard temporal,
   stability gate, One Euro, nova nota, corda, afinado, hold) — concluída.
3. Captura real (`AudioInput`), isolate e gravações de referência.
4. Calibração dos parâmetros com áudio real.
5. Refinamento harmônico / correção espectral de oitava (FFT), se os erros
   em aparelho exigirem.

## Resultados da fase 1 — YIN

Implementação: `lib/core/dsp/yin_pitch_detector.dart` (própria, a partir do
paper; fgnass/tuner e PitchKit foram referências técnicas e de parâmetros —
nenhum código copiado). Testes: `test/core/dsp/`. Relatório reproduzível:
`dart run tool/yin_report.dart`. Benchmark: `tool/yin_benchmark.dart`.

Todos os números abaixo vêm de **sinais sintéticos perfeitamente harmônicos**.
Cordas reais têm inarmonicidade, decaimento desigual dos harmônicos e o
microfone do celular corta graves — os resultados reais serão piores.

### Configuração padrão

`YinConfig`: faixa 60–450 Hz, limiar 0.15, `minRms` 0.004 (após remoção de
DC). Frame mínimo: 1602 amostras a 48 kHz, 1472 a 44.1 kHz.

### Precisão

| Sinal | Erro máximo | Confiança |
| --- | --- | --- |
| Senoide pura, 6 cordas × ±25 cents, 44.1/48 kHz, 4096/8192 | ≤ 0.0014 cent | ≥ 0.9998 |
| Harmônicos (violão típico, rico, H2 > H1, H1 fraca com H3, sem H1 com H3) | ≤ 0.01 cent | ≈ 1.00 |
| DC offset −0.3 a +0.5, amplitudes 0.9 a 0.006 | idêntico ao sinal limpo | idêntica |
| Tom + ruído, pico 0.05 (~SNR 20 dB) | 0.47 cent | ≥ 0.995 |
| Tom + ruído, pico 0.1 (~SNR 18 dB) | 2.1 cents | ≥ 0.98 |
| Tom + ruído, pico 0.2 (~SNR 12 dB), 20 sementes | ~10 cents | ≥ 0.93 |
| Frame contendo o ataque da palhetada | até 4.1 cents (E2, 4096) | ≥ 0.97 |
| Frames ≥ 10 ms após o ataque | ≈ 0 cent | ≈ 1.00 |

**4096 vs 8192**: em sinal limpo ambos têm erro desprezível. Com ruído forte
(pico 0.2, pior de 20 sementes), 8192 tende a errar menos, mas não em todas
as cordas:

| Corda | E2 | A2 | D3 | G3 | B3 | E4 |
| --- | --- | --- | --- | --- | --- | --- |
| 4096 (cents) | 6.5 | 8.8 | 10.0 | 6.8 | 8.3 | 4.2 |
| 8192 (cents) | 6.7 | 4.9 | 5.8 | 5.1 | 4.0 | 2.9 |

No frame que contém o ataque, 8192 também erra menos (E2: 1.6 vs 4.1 cents),
porque o transiente ocupa uma fração menor da janela. O custo é o dobro de
janela (171 vs 85 ms a 48 kHz) e o dobro de CPU.

**44.1 vs 48 kHz**: sem diferença relevante de precisão; 48 kHz analisa ~9% mais
lags (801 vs 736) e custa ~10% mais.

### Silêncio e ruído

- Silêncio digital e sinais abaixo de `minRms` → sem estimativa.
- Ruído branco (100 sementes × 2 níveis × 4 configurações): confiança
  máxima **0.076**, nunca próxima de 0.90. A separação entre ruído (< 0.1) e
  tom (> 0.93 mesmo com SNR 12 dB) é ampla.

### Erros de oitava (limitação conhecida, ainda não corrigida)

- **Ocorre** quando o 2º harmônico domina e tanto a fundamental quanto o 3º
  harmônico são fracos: o primeiro vale da CMNDF abaixo do limiar aparece em
  T/2. Para o E2 com H2 = 1: erro com fundamental ≤ 0.28 (sem H3),
  ≤ 0.26 (H3 = 0.1), ≤ 0.20 (H3 = 0.2); com H3 ≥ 0.4, nunca.
- O resultado errado sai com **confiança 0.96–0.98**: o gate de confiança
  (0.90) **não** protege contra ele.
- Afeta E2, A2, D3 e G3. **B3 e E4 ficam imunes** porque o H2 deles (494 e
  659 Hz) está acima de 450 Hz, fora da faixa de lags.
- Fundamental ausente com H3 presente: correto (o período real continua T).
- Sinal só com harmônicos pares tem período T/2 de fato; "oitava acima" é a
  resposta matematicamente correta — nenhum detector de período resolve isso
  sem contexto (afinação alvo / histórico).
- Tons **acima de 450 Hz** viram o sub-harmônico dentro da faixa
  (500 Hz → 250 Hz, confiança 1.0). Irrelevante para cordas soltas, mas
  relevante se o usuário tocar notas presas agudas.

Testes de caracterização em
`test/core/dsp/yin_octave_characterization_test.dart` afirmam o comportamento
errado atual ("LIMITAÇÃO CONHECIDA"); a correção deve invertê-los. Candidatos:
octave snap temporal (fase 3) e verificação de sub-harmônico/refinamento
espectral (fase 5).

### Ajuste feito durante a fase

A primeira versão descia do primeiro ponto abaixo do limiar até o primeiro
mínimo local. Com ruído forte, ondulações dentro do vale interrompiam a
descida: E2 errava até **36 cents com confiança 0.91**. Passou-se a usar o
menor valor de toda a região contígua abaixo do limiar (ainda é o primeiro
vale, sem risco de oitava). Pior caso com ruído pico 0.2 caiu para ~10 cents.
Os critérios dos testes não foram alterados.

### Custo por frame

Xeon 2.1 GHz (ambiente cloud, VM compartilhada), um núcleo, AOT
(`dart compile exe`), faixa observada em 3 execuções:

| Configuração | Lags | Janela W | Média | p95 | % de um hop de 40 ms |
| --- | --- | --- | --- | --- | --- |
| 44.1 kHz / 4096 | 736 | 3360 | 3.1–4.7 ms | ~5 ms | 8–12% |
| 44.1 kHz / 8192 | 736 | 7456 | 6.6–9.5 ms | 10–12 ms | 17–24% |
| 48 kHz / 4096 | 801 | 3295 | 3.6–3.9 ms | 5–6 ms | ~9–10% |
| 48 kHz / 8192 | 801 | 7391 | 7.7–7.9 ms | ~12.5 ms | ~19–20% |

O custo é O(W·τmax): 8192 custa ~2× 4096. JIT (`dart run`) dá números
parecidos. Celulares intermediários podem ser 2–4× mais lentos.

**Isolate**: ainda não há motivo para implementá-lo — não existe captura real.
Mas há um motivo concreto para planejá-lo na fase 2: a 8192, ~8 ms por frame
já é quase metade do orçamento de um quadro de 60 fps (16.7 ms) no próprio Xeon; num
celular, rodar no isolate da UI causaria travadas. A decisão final deve vir de
medição em aparelho. Otimização via FFT da função diferença (O(N log N)) fica
para depois, só se necessário.

### Limitações desta fase

- Somente sinais sintéticos; nenhuma gravação real ou aparelho testado.
- Sem inarmonicidade, sem variação de pitch dentro do frame (vibrato,
  bend, tarraxa girando), sem resposta de frequência de microfone.
- Erros de oitava descritos acima não corrigidos.
- Benchmark num servidor x86, não em ARM.

## Resultados da fase 2 — pipeline temporal

Código: `lib/core/dsp/filters/` (filtros de pitch),
`lib/core/music/string_tracker.dart`, `lib/core/tuner/` (`TunerPipeline`,
`InTuneHysteresis`, `SilenceHold`). Testes: `test/core/dsp/filters/`,
`test/core/tuner/`, `test/core/music/string_tracker_test.dart`. Relatório:
`dart run tool/temporal_report.dart`.

### Desenho

```
PitchEstimate? + timestamp            (um por frame; null = sem pitch)
  → ConfidenceGate      confidence < 0.90 → null
  → RangeGate           fora de 60–450 Hz → null
  → OctaveJumpGuard     ±1 oitava (±50 c) da referência → dobra de volta;
                        aceita a nova oitava se persistir 600 ms
  → StabilityGate       últimas N dentro de 20 c, senão null; null esvazia
  → PitchSmoother       One Euro em cents (0.6 Hz, β 0.06, dt real);
                        reinicia em salto > 250 c ou lacuna > 300 ms
  → StringTracker       troca de corda só com 30 c de vantagem
  → InTuneHysteresis    entra ≤ 3 c, sai > 6 c; reinicia ao trocar corda
  → SilenceHold         mantém a última leitura 700 ms (isHeld = true)
TunerReading?                          (o que a UI recebe)
```

`TunerPipeline` é síncrono e não conhece áudio. `PitchTunerEngine` só faz
`AudioInput → YIN → TunerPipeline → stream`. A UI recebe apenas
`TunerReading` (corda, cents, afinado, isHeld) e não conhece YIN, filtros nem
histereses. Todos os parâmetros estão em `TunerConfig`. Os filtros usam os
timestamps dos frames (`AudioFrame.timestamp`), nunca contagem de frames.

Implementações próprias: One Euro a partir do paper (Casiez et al., 2012);
gate de estabilidade, octave snap, histereses e hold a partir das ideias e
valores iniciais do fgnass/tuner (nenhum código copiado).

### Stability gate: janela 3 vs 5 (hop 40 ms)

| Medida | Janela 3 | Janela 5 |
| --- | --- | --- |
| Aquisição (após a 1ª estimativa) | **80 ms** | 160 ms |
| Aquisição total ≈ janela de análise + aquisição (4096 @ 48 kHz = 85 ms) | ~165 ms | ~245 ms |
| Outlier único: tempo congelado (hold, nada errado na tela) | 120 ms | 200 ms |
| Tarraxa 20–100 c/s: leituras vivas | 100% | 100% |
| Tarraxa 200 c/s | 100% (16/16) | **19% (3/16)** — congela |
| Tarraxa 400 c/s | 2/9 | 2/9 |
| Frequências aleatórias (ruído), 2000 frames | 3 aceitos | 0 |
| Glissando tipo fala até 150 c/s | 99.9% aceito | 85.6% |
| Glissando até 300 c/s | 82.6% | 43.0% |
| Glissando até 600 c/s | 50.1% | 25.7% |

O gate mede só a dispersão na janela (máx − mín ≤ 20 c), então a velocidade
máxima que ele deixa passar é ~20 c / ((N−1)·40 ms): ~250 c/s com N = 3 e
~125 c/s com N = 5.

**Tradeoff**: N = 3 cumpre a meta de latência e acompanha giros rápidos, mas
rejeita fala bem menos. N = 5 rejeita melhor fala e ruído, mas passa de
150 ms e congela em giros rápidos. **Padrão provisório: 3** (pela meta de
latência), a ser revisto com áudio real — fala real também passa pelo gate
de confiança, que nestes testes foi contornado.

### Proteção temporal de oitava

- Com uma referência estabelecida, estimativas a ±1200 ± 50 cents são
  dobradas para a oitava da referência. Testado: E2→E3 por 200 ms e D3→D2 por
  200 ms (caminho inverso) não alteram a leitura; YIN alternando entre
  oitavas a cada frame nunca troca a oitava exibida.
- Se a outra oitava persistir por 600 ms contínuos (harmônico na casa 12,
  afinação alternativa), é aceita como real. Uma única estimativa na oitava
  da referência cancela a confirmação.
- Saltos de 2 oitavas (E2↔E4) e intervalos entre cordas (500/1000/1400/1900
  cents) nunca são dobrados.
- A referência expira após 2 s sem estimativas.
- **Limitações**: (1) a primeira detecção sem histórico (após silêncio > 2 s)
  não é corrigida — se o YIN começar na oitava errada, ela é exibida;
  (2) um erro de oitava que persista > 600 ms também é aceito. Ambos dependem
  da correção espectral (fase 5).

### One Euro (cents)

| Medida | Resultado |
| --- | --- |
| Nota estável | exata (0.00 c) |
| Jitter ±1 / ±3 / ±10 c | p2p da saída 1.0 / 3.5 / 14.0 c (entrada 2 / 6 / 20), viés < 0.05 c |
| Rampa 20 c/s | atraso médio 1.0 c |
| Rampa 100 c/s | atraso médio 1.9 c |
| Rampa 200 c/s | atraso médio 2.6 c |
| Salto > 250 c (nova nota) | primeira leitura já no valor real (sem deslizar) |

Efeito de beta (jitter ±3 c vs atraso no fim de uma rampa de 100 c/s):

| beta | p2p com jitter ±3 | atraso |
| --- | --- | --- |
| 0 | 2.3 c | 26.1 c |
| 0.02 | 3.0 c | 3.6 c |
| **0.06** (padrão) | 3.5 c | 1.7 c |
| 0.15 | 4.0 c | 0.8 c |

Com β = 0.06 o filtro privilegia responsividade: a atenuação de jitter é
modesta (~40%). Se o ponteiro tremer com áudio real, reduzir `minCutoff` ou
`beta` é o primeiro ajuste.

### Histereses e hold

- **Corda**: entre E2 e A2 (ponto médio +250 c), vindo de E2 só troca em
  ≥ +265 c; vindo de A2 só volta em ≤ +235 c. Oscilação entre 240 e 262 c
  não pisca. Após o hold expirar, a histerese é zerada.
- **Afinado**: entra com |c| ≤ 3 e sai com |c| > 6. Leituras oscilando entre
  2.8 e 3.4, ou entre +1 e +5.5, não piscam. Rampa de −40 a +10 c: exatamente
  2 transições (entra perto de −3, sai acima de +6). Com jitter de ±10 c em
  torno de 0 há trocas (o próprio sinal cruza ±6); isso só se resolve com
  smoothing mais forte.
- **Hold**: 700 ms medidos por timestamp. Leitura nova durante o hold
  substitui na hora (sem passar por "toque uma corda"). Durante uma troca de
  corda, a tela mantém a corda anterior até a nova ser adquirida.

### Limitações desta fase

- Tudo validado com sequências sintéticas de `PitchEstimate`, mais um teste
  de ponta a ponta com YIN e áudio sintético. Nenhum áudio real.
- Fala com glissandos lentos passa pelo stability gate.
- Erros de oitava sem histórico ou persistentes (ver acima).
- Durante o hold o engine emite a leitura com `isHeld = true`; a UI ainda
  não diferencia visualmente esse estado.
- Parâmetros (janela, β, minCutoff, tolerâncias) são provisórios.

## Tolerância de afinado

Implementada como histerese: entra com |cents| ≤ 3, sai com |cents| > 6
(`TunerConfig.inTuneEnterCents/inTuneLeaveCents`). Calibrar com uso real. Calibrar com uso real;
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
