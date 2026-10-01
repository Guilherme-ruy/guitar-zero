# Estratégia de DSP

> Status: **aprovada com ajustes**. Fases 1 (YIN), 2 (filtros temporais) e 3
> (análise espectral) implementadas e validadas com sinais sintéticos — ver
> [Fases](#fases) e as seções de resultados de cada fase.

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

## Captura (fase 4)

Implementada em `MicrophoneAudioInput` + `RecordPcmRecorder`
(`lib/platform/`). Decisões:

| Decisão | Escolha | Motivo |
| --- | --- | --- |
| Mecanismo | plugin `record` 7.1.1 (BSD-3) atrás de `PcmRecorder` | Android + iOS, stream PCM, AGC/NS/AEC desligáveis, fonte de áudio configurável; ~1.1 M downloads/mês, 160/160 pontos no pub.dev. Trocar por código nativo = outra implementação de `PcmRecorder`. |
| Formato | PCM16 mono | Sem compressão; nada vai para arquivo. |
| Taxa | 44.1 kHz | Única taxa garantida em todo Android. |
| Fonte Android | `VOICE_RECOGNITION` | O Android CDD exige AGC e redução de ruído desligados e resposta ~plana nessa fonte. `UNPROCESSED` é opcional por aparelho. |
| AGC / NS / AEC | desligados | Sinal cru para o DSP. |
| Frame / hop | 4096 amostras (93 ms) / 40 ms (1764 amostras) | Meta de latência; 8192 fica como alternativa medida. |
| Timestamps | contagem de amostras (`PcmFramer`) | Monotônico e exato, imune a atrasos na entrega dos blocos. |
| Onde roda o DSP | isolate dedicado (`IsolateFrameProcessor`) | 3–9 ms/frame no servidor, mais em celular; fora da thread da UI. Backpressure descarta frames pendentes antigos. |

Latência estimada até a primeira leitura (44.1 kHz, 4096, janela de
estabilidade 3, hop 40 ms): 93 ms (encher o frame) + 80 ms (gate) ≈
**175 ms**, mais o buffer do sistema de áudio e o processamento
(≈ 5–20 ms) — acima da meta de 150 ms, a medir em aparelho.

Não validado ainda: comportamento real do `VOICE_RECOGNITION` em aparelhos,
tamanho dos blocos entregues pelo plugin, latência do sistema, consumo de
bateria, interrupções (ligações) — o stream é pausado pelo plugin e o app não
mostra aviso.

## Pipeline

Cada etapa é um `PitchDetector` ou `PitchFilter` independente e testável.

1. **Remoção de DC** (detector).
2. **RMS / noise gate** (detector): abaixo de `minRms`, sem estimativa.
3. **YIN** (detector): diferença → CMNDF → primeiro mínimo abaixo do limiar
   → interpolação parabólica → `f = sr/τ`, `confidence = 1 − d'(τ)`.
4. **Restrição de faixa** (detector): lag limitado a `[sr/fmax, sr/fmin]`;
   mínimo encostado na borda da faixa não é aceito.
4b. **Análise espectral** (`HarmonicAnalyzer`, fase 3): correção de oitava
   (para baixo e para cima), refinamento harmônico e harmonicidade.
5. **Gate de confiança** (`ConfidenceGate`): `periodicity < minConfidence` → sem pitch.
6. **Gate de faixa** (`RangeGate`).
7. **Proteção temporal contra saltos harmônicos ×2/×3** (`HarmonicJumpGuard`,
   com detecção de ataque — fase 4); verificação espectral
   de sub-harmônico fica para a fase com FFT.
8. **Stability gate** (`StabilityGate`): N estimativas dentro de K cents.
9. **One Euro em cents** (`PitchSmoother`), com reset em nova nota.
10. **Histerese de corda** (`StringTracker`) e **de afinado**
    (`InTuneHysteresis`).
11. **Hold no silêncio** (`SilenceHold`).

Etapas 5–11 ficam no `TunerPipeline` (fase 2). Detalhes em
[Resultados da fase 2](#resultados-da-fase-2--pipeline-temporal).

Etapas ainda não implementadas, só se as medições reais mostrarem
necessidade: diferença de fase, A-weighting, high-pass de 2ª ordem, mediana,
gate de harmonicidade.

## Fases

1. **YIN em Dart puro + testes sintéticos** — concluída.
2. **Filtros temporais e histereses** — concluída.
3. **Análise espectral**: FFT, correção de oitava, refinamento harmônico,
   harmonicidade — concluída.
4. **Captura real** (`record`), DSP em isolate, build Android no CI e
   **avaliação com gravações reais** (NSynth) — concluída; captura **sem
   validação em aparelho**.
5. Validação em aparelho e calibração com captura ao vivo.

## Resultados da fase 1 — YIN

Implementação: `lib/core/dsp/yin_pitch_detector.dart` (própria, a partir do
paper; fgnass/tuner e PitchKit foram referências técnicas e de parâmetros —
nenhum código copiado). Testes: `test/core/dsp/`. Relatório reproduzível:
`dart run tool/yin_report.dart`. Benchmark: `tool/dsp_benchmark.dart`.

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

### Erros de oitava do YIN isolado (corrigidos na fase 3)

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

Os testes de caracterização (hoje em `test/core/dsp/octave_error_test.dart`)
continuam afirmando esse erro do YIN **isolado** e, desde a fase 3, exigem
que o `HarmonicPitchDetector` o corrija.

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
  → HarmonicJumpGuard   (fase 4; antes OctaveJumpGuard) ×2/×3 da referência
                        sem ataque → dobra de volta;
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

> Fase 4: generalizada para ×2 **e ×3**, com detecção de ataque
> (`HarmonicJumpGuard`); ver [Avaliação com gravações reais](#avaliação-com-gravações-reais-fase-4).

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

## Resultados da fase 3 — análise espectral

Código: `lib/core/dsp/spectral/` (`fft.dart`, `spectrum.dart`,
`harmonic_analyzer.dart`) e `lib/core/dsp/harmonic_pitch_detector.dart`.
Testes: `test/core/dsp/spectral/`, `test/core/dsp/harmonic_pitch_detector_test.dart`,
`test/core/dsp/octave_error_test.dart`. Relatório:
`dart run tool/spectral_report.dart`. Benchmark: `tool/dsp_benchmark.dart`.

### Arquitetura

```
AudioFrame
  → YinPitchDetector            (inalterado; semente: período + periodicidade)
  → HarmonicAnalyzer            (FFT do mesmo frame + semente)
       1. correção para baixo (semente = H2?)   → f/2
       2. correção para cima (semente = sub-harmônico?) → 2f
       3. harmonicidade da fundamental escolhida
       4. refinamento por média ponderada de f_h / h
  → HarmonicPitchDetector       (compõe; aplica a faixa 60–450 Hz)
  → PitchEstimate { frequencyHz, periodicity, harmonicity, rms }
  → TunerPipeline (fase 2, sem alterações)
```

- `PitchEstimate.confidence` foi renomeado para **`periodicity`** (o que o YIN
  mede) e ganhou **`harmonicity`** (espectral, opcional). Os nomes deixam
  explícito que periodicidade alta não garante a oitava.
- O YIN continua utilizável e testável sozinho. O analisador não tem estado
  entre frames.
- O pipeline temporal não foi alterado. `harmonicity` ainda não é usada como
  gate (sem threshold definido).

### FFT

Radix-2 complexa iterativa (Cooley–Tukey), própria, ~80 linhas, com tabelas
de twiddles e bit-reversal por tamanho e sem alocação por frame. Validada
contra DFT direta (N = 2…512), impulso, cosseno e Parseval (N = 4096).
Nenhuma dependência: para N = 4096/8192 uma biblioteca não traria ganho
relevante (a FFT custa ~0.1–0.3 ms; o YIN, 3–8 ms) e acrescentaria uma
dependência para manter.

Janela **Hann periódica**, DC removido antes. Tamanho da FFT = maior
potência de 2 que cabe no frame (frames de 4096/8192 usam o frame inteiro).
Interpolação de pico pelo estimador de razão de amplitudes para Hann
(Grandke, 1983) — exato para senoide isolada; erro < 0.005 bin nos testes.

### Correção de oitava

**Para baixo** (YIN ≈ 2 × fundamental). Aceita f/2 somente se:

1. há **pico em f/2** — local máximo ≥ 12× a mediana da vizinhança
   (proeminência), ≥ −40 dB do maior pico e a ≤ 40 cents de f/2 após
   interpolação; **e**
2. os **harmônicos ímpares de f/2** (f/2, 1.5f, 2.5f…), que não existiriam se
   f fosse a fundamental, somam ≥ **0.3%** (−25 dB) da energia em todas as
   posições harmônicas de f/2;
3. f/2 ≥ 60 Hz e f/2 resolvido pela FFT (≥ 3 bins).

Exigir o pico **em f/2** (e não só em 1.5f) evita falsos positivos por
ressonância simpática: na afinação Standard, outras cordas produzem
componentes em 1.5·f (quintas/quartas: E2·3 ≈ B3, A2·3 ≈ E4, A2·2 ≈ 1.5·D3),
mas nenhuma corda produz energia uma oitava abaixo da corda tocada. Com
afinações alternativas (ex.: Drop D, com D2 e D3) isso deixa de valer.

**Para cima** (YIN reportou sub-harmônico): se a semente não tem pico em f
nem em nenhum harmônico ímpar de f, mas tem em 2f, a fundamental é 2f. Se 2f
estiver fora da faixa, a estimativa é descartada.

### Resultados nos casos de H2 dominante

| Caso (todas as configs: 44.1/48 kHz × 4096/8192) | YIN isolado | Com análise espectral |
| --- | --- | --- |
| `[.1 1 .1 .3]` — E2, A2, D3, G3 | oitava acima | **corretos** |
| `[.25 1 0 .2]`, `[.1 1 0 .5]` — E2…G3 | oitava acima | **corretos** |
| `[.05 1 .05 .3]` | oitava acima | corretos, exceto E2 @ 44.1 kHz/4096 |
| `[.02 1 .02 .3]` (ímpares a −34 dB) | oitava acima | **ainda errado** (evidência < 0.3%) |
| B3, E4 em todos os perfis | corretos | corretos |
| E2 sem H3, varredura da fundamental | erra com a1 ≤ 0.28 | corrige até a1 = 0.06; erra com a1 ≤ 0.05 |
| E2 com H3 = 0.1/0.2 | erra com a1 ≤ 0.26/0.20 | 4096: corrige até a1 = 0.02 (48 kHz) / 0.03 (44.1 kHz); 8192: todos |

**Falsos positivos**: 0 de 432 notas corretas (6 perfis × 6 cordas × ±25
cents × 4 configurações) mudaram de oitava; D3 com A2 e E2 vibrando por
simpatia não é corrigido. Com ruído (pico 0.05/0.1/0.2, 20 sementes): 80/80
casos de H2 dominante corrigidos e 0/80 notas normais trocadas, em 4096 e
8192.

**Caso 500 Hz → 250 Hz**: resolvido. O espectro de 250 Hz não tem pico em
250 nem em 750 Hz, só em 500 Hz → correção para cima → 500 Hz fora da faixa
→ descartado. Idem 660 → 330 e 900 → 450 Hz.

**Oitava errada desde a primeira detecção** (limitação da fase 2): coberta
na origem. No teste de ponta a ponta (E2 `[.1 1 .1 .3]`, engine + pipeline),
o YIN isolado exibe 164.8 Hz; com `HarmonicPitchDetector`, E2 desde a
primeira leitura.

### Refinamento harmônico

Para a fundamental escolhida, localiza o pico de cada harmônico (h ≤ 12, até
5 kHz), interpola (Grandke) e faz a média de `f_h / h` ponderada pela
amplitude. É usado por padrão (`useSpectralRefinement: true`), com proteção:
se divergir > 40 cents da fundamental escolhida, volta à semente.

Erro máximo (6 cordas × ±25 cents; ruído com 10 sementes):

| Sinal | Config | YIN | Refinado |
| --- | --- | --- | --- |
| limpo (violão típico) | 4096 | 0.003–0.004 c | 0.04–0.06 c |
| limpo | 8192 | 0.003–0.004 c | 0.002–0.004 c |
| ruído pico 0.1 | 4096 | 3.8–4.2 c | **0.8–1.0 c** |
| ruído pico 0.1 | 8192 | 2.3–2.6 c | **0.2–0.3 c** |
| ruído pico 0.2 | 4096 | 8.4–11.0 c | **1.6–1.9 c** |
| ruído pico 0.2 | 8192 | 6.3–6.5 c | **0.5–0.6 c** |

Com **inarmonicidade** (parciais esticados, `f_h = h·f0·√(1+B·h²)`), ambos
ficam sustenidos em relação à fundamental, o refinado menos:

| B | YIN | Refinado |
| --- | --- | --- |
| 1e-4 | +2.7 c | +1.6 c |
| 3e-4 | +7.9 c | +4.8 c |
| 1e-3 | +24 c | +12.7 c |

Em sinal limpo de 4096 o refinamento é pior que o YIN, mas ambos são
desprezíveis (< 0.06 cent). Com ruído ele é 4–10× melhor e com
inarmonicidade fica mais perto da fundamental, por isso é o padrão.
Valores típicos de B para cordas de violão/guitarra precisam ser medidos
com gravações; um ajuste conjunto de f0 e B fica como evolução possível.

**A-weighting não foi implementada.** No fgnass/tuner ela reduz o peso de
rumble grave na média. Aqui os harmônicos só entram se forem picos
proeminentes na posição exata, e o rumble abaixo de 60 Hz não cai nessas
posições; sem áudio real não há evidência de benefício.

### Diferença de fase (não implementada nesta fase)

O fgnass/tuner estima a frequência instantânea pela diferença de fase entre
**duas FFTs dentro do mesmo frame**, deslocadas por um hop. Isso não exige
estado entre frames, mas exige que FFT + hop caibam no frame: com frames de
4096 a FFT cairia para 2048 (23 Hz/bin a 48 kHz), e os harmônicos do E2
(82 Hz = 3.5 bins) se sobreporiam no lóbulo principal da Hann (±2 bins),
piorando justamente a corda mais difícil. A variante **entre frames**
(mesma FFT em frames consecutivos) mantém a resolução, mas exige estado no
analisador e um hop exato e conhecido entre frames — informação que só
existirá com a captura real (fase 4). Como o refinamento estático já fica
abaixo de 1 cent com ruído moderado, a diferença de fase fica documentada
como melhoria possível para a fase de captura, se as medições reais
mostrarem necessidade.

### Harmonicidade

`harmonicity = energia explicada × completude da série`:

- **energia explicada**: energia nas bandas (±2 bins) dos picos válidos em
  h·f0 ÷ energia total entre f0/2 e 5 kHz;
- **completude**: harmônicos encontrados ÷ ordem do maior harmônico
  significativo (≥ −30 dB do mais forte). Penaliza "séries" esparsas
  (h = 5, 7, 11, 18 de um f0 grave demais); não penaliza a falta de
  harmônicos acima do último presente (senoide pura = 1).

Uma primeira versão por bandas fixas sem completude dava até 1.00 para
parciais inarmônicos quando o YIN escolhia um f0 muito grave (qualquer
conjunto de parciais parece harmônico de um f0 baixo o bastante); por isso a
completude.

| Sinal (48 kHz, 6 cordas) | 4096 | 8192 |
| --- | --- | --- |
| Senoide pura, corda rica, fundamental fraca, H2 dominante | 1.00 | 1.00 |
| Fundamental ausente `[0 1 .7 .5]` | 0.75 | 0.75 |
| Corda + ruído pico 0.1 / 0.2 | 1.00 / 0.99 | 1.00 / 0.99 |
| Ruído branco (100 sementes, mediana / máx) | 0.00 / 0.01 | 0.00 / 0.01 |
| Parciais inarmônicos (f, 1.37f, 2.21f, 3.53f) | 0.07 (0.04–0.22) | 0.07 (0.04–0.22) |
| Mistura: corda + corda a um trítono | 0.11 (0.00–0.29) | 0.23 (0.00–0.57) |
| Glissando harmônico 150 / 600 c/s | 1.00 / 1.00 | 1.00 / 0.99 |
| Glissando harmônico 2000 c/s | 0.99 | 0.86 (0.69–0.98) |

### Fala e sinais não tonais

- **Ruído**: separado com folga (≤ 0.01 vs ≥ 0.75 de qualquer tom
  harmônico). O gate de periodicidade já rejeitava ruído; a harmonicidade é
  uma segunda evidência independente.
- **Combinações não harmônicas** (parciais inarmônicos, duas cordas sem
  relação harmônica): claramente mais baixas (≤ 0.57) que cordas (≥ 0.75).
  Nesses sinais o YIN também costuma ter periodicidade baixa (0.4–0.8),
  exceto quando a mistura é quase periódica (trítono ≈ 7:5 → 0.95).
- **Glissandos harmônicos**: **não são separados**. Um glissando de um som
  harmônico é harmônico em cada frame (1.00 até 600 c/s); só a 2000 c/s com
  janela de 8192 a métrica cai (0.86). Fala sonora também é harmônica.
- **Conclusão**: a harmonicidade ajuda contra ruído e misturas, mas **não**
  resolve a limitação de fala com glissandos lentos vista na fase 2. Os
  sinais sintéticos não permitem concluir nada sobre fala real (formantes,
  jitter/shimmer, ruído de respiração). Nenhum gate de harmonicidade foi
  ativado; a decisão depende de gravações reais.

### 4096 vs 8192

- Correção de oitava: 8192 corrige casos um pouco mais extremos (E2 com H3
  presente: todos os casos; 4096 ainda falha com fundamental ≤ 0.01–0.02).
- Refinamento com ruído: 8192 é ~3× mais preciso (0.5 vs 1.9 cents com ruído
  pico 0.2).
- Harmonicidade: igual nos casos limpos; 8192 discrimina melhor misturas e
  glissandos rápidos.
- Latência: inalterada pela análise espectral (mesmo frame), continua
  85 ms (4096) vs 171 ms (8192) a 48 kHz.

### Custo por frame

AOT, Xeon 2.1 GHz (VM compartilhada), 3 execuções:

| Config | YIN | Análise espectral | Total | % de um hop de 40 ms |
| --- | --- | --- | --- | --- |
| 44.1 kHz / 4096 | 2.9–3.5 ms | 0.15–0.19 ms | 3.2–3.7 ms | 8–9% |
| 44.1 kHz / 8192 | 6.9–7.2 ms | 0.30–0.36 ms | 7.2–9.4 ms | 18–24% |
| 48 kHz / 4096 | 3.2–4.0 ms | 0.14–0.18 ms | 3.0–4.6 ms | 8–12% |
| 48 kHz / 8192 | 7.6–7.7 ms | 0.31–0.39 ms | 6.9–8.9 ms | 17–22% |

A análise espectral acrescenta ~5% ao custo do YIN. O YIN domina; a decisão
sobre isolate não muda: 4096 é claramente viável; 8192 é viável a cada
40 ms, mas ocupa metade de um quadro de 60 fps no servidor e mais num
celular — rodar fora do isolate da UI continua recomendado na fase de
captura, a confirmar por medição em aparelho.

### Impacto na latência

Nenhum atraso adicional de aquisição: a análise usa o mesmo frame do YIN e
não guarda histórico. Só soma o custo de CPU acima (~0.2–0.4 ms).

### Limitações desta fase

- Sinais sintéticos apenas.
- Evidência de oitava insuficiente quando os harmônicos ímpares estão abaixo
  de −25 dB (ex.: `[.02 1 .02 .3]`); o erro do YIN permanece nesses casos.
- A regra "pico em f/2 obrigatório" assume afinação Standard (nenhuma corda
  uma oitava abaixo de outra); afinações como Drop D exigirão revisão.
- Inarmonicidade real enviesa a frequência para cima (YIN e refinado); a
  magnitude depende de B das cordas reais.
- Harmonicidade não distingue glissandos harmônicos (fala sonora) de
  cordas; nenhum threshold escolhido.
- Diferença de fase e A-weighting não implementadas.
- `HarmonicPitchDetector` ainda não está ligado ao app (`main.dart` usa o
  engine simulado até existir captura real).

## Avaliação com gravações reais (fase 4)

Sem acesso a aparelho, o DSP foi avaliado com **214 notas reais de
guitarra/violão** do NSynth (`nsynth-test`, CC BY 4.0): 7 instrumentos (5
acústicos, 2 elétricos), MIDI 38–66, 44 delas nas alturas das cordas
soltas. Reamostradas para 44.1 kHz e processadas na configuração do app
(frames de 4096, hop de 40 ms, `HarmonicPitchDetector` + `TunerPipeline`).
Ferramenta: `tool/real_audio_eval.dart`. Seis notas viraram teste de
regressão no CI (`test/core/real_audio_test.dart`, `test/fixtures/nsynth/`).

Ressalvas: a nota nominal do NSynth não é verdade absoluta de afinação (as
amostras têm desvios de até ±15 cents, e um instrumento, acoustic_030,
desvia mais de 50 cents em vários arquivos); 16 kHz de origem limita os
harmônicos a 8 kHz; amostras de biblioteca ≠ microfone de celular.

### O que o áudio real revelou (e o que foi feito)

| Achado | Causa | Correção |
| --- | --- | --- |
| Correção espectral **aumentou** os erros de oitava por frame (76 vs 35 do YIN) | regra "para cima" disparava em notas reais cujo H1 não virava pico (ex.: C3 → C4) | só considerar correção para cima quando 2f > 450 Hz — o único caso em que o YIN reporta sub-harmônico |
| E2 exibindo **B3** no fim da nota | após ~3 s a fundamental morre antes do H3: YIN e espectro pegam ×3 (12ª) | `OctaveJumpGuard` → **`HarmonicJumpGuard`**: dobra saltos ×2 **e ×3** quando não há ataque (RMS < +3 dB sobre o mínimo dos últimos 250 ms) |
| Leitura variando 8–14 c na sustentação em 2 instrumentos | **inarmonicidade real** (medido B até 3.5e-4): o pitch composto (YIN, média f_h/h) muda conforme os agudos decaem; YIN lia **+21.6 c** acima da fundamental no pior violão | refinamento passa a **ajustar f0 e B juntos** (mínimos quadrados ponderados em `(f_h/h)² = f0²(1+B·h²)`), estimando a fundamental (parcial 1) |
| Notas curtas sem leitura | staccato de ~250 ms < 3 estimativas concordantes | nenhuma (comportamento correto) |
| Aquisição de 0.6–0.9 s no violão mais inarmônico | periodicidade 0.6–0.89 e harmonicidade 0.5–0.7 no ataque, pitch saltando +40 → −6 c | nenhuma: o sinal é de fato instável; afrouxar o gate mostraria os saltos |

Por que ×3 importa na afinação Standard: E2→B3 e A2→E4 são intervalos ×3
(1900 cents). Só o ataque distingue "toquei a corda B3" de "o detector
pegou o H3 do E2"; com ataque o salto é aceito na hora.

### Resultados

| Métrica (214 notas) | Antes das correções | Depois |
| --- | --- | --- |
| Frames com oitava errada — YIN isolado | 35 (0.23%) | 35 (0.23%) |
| Frames com oitava errada — detector harmônico | 76 (0.49%) | 35 (0.23%) — caudas ×3, absorvidas pelo pipeline |
| Notas que **exibiram** oitava/corda errada | 5 | **0** |
| 1ª leitura (p50 / p90 / máx) | 173 / 253 / 1053 ms | igual |
| Notas sem nenhuma leitura | 2 (staccatos) | 2 |

Cordas soltas (44 notas), leitura exibida entre 0.3 e 2.5 s:

| | Média f_h/h (antes) | Ajuste f0 + B (depois) |
| --- | --- | --- |
| p2p p50 / p90 / máx | 0.51 / 8.31 / 13.93 c | **0.26 / 4.98 / 7.91 c** |
| desvio-padrão p50 / máx | 0.14 / 4.27 c | **0.09 / 2.14 c** |

Inarmonicidade medida (notas graves, ajuste em janelas de 16384):

| Instrumento | B (mediana) | YIN − fundamental ajustada |
| --- | --- | --- |
| acoustic_015 | 3.5e-4 | **+21.6 c** |
| acoustic_014 | 5.4e-5 | +3.5 c |
| electronic_028 | 3.2e-5 | +0.4 c |
| acoustic_021 | 1.5e-5 | +0.5 c |
| acoustic_010, electronic_022 | ~0 | ~0 c |

Sintéticos com B conhecido: o ajuste erra < 0.05 c para B até 1e-3 (YIN:
+2.7 / +7.9 / +24 c para B = 1e-4 / 3e-4 / 1e-3). Custo: com ruído forte o
ajuste tem mais variância que a média simples (pior caso 3.2 c vs 1.9 c em
48 kHz/4096, ruído pico 0.2), ainda bem melhor que o YIN (8.4 c).

**Decisão de produto embutida**: o afinador mostra a frequência da
**fundamental** (parcial 1), como afinadores convencionais, e não o pitch
composto. Em cordas muito inarmônicas isso difere do YIN em até ~20 c.

### Limitações que continuam

- Captura ao vivo não validada (latência real, `VOICE_RECOGNITION` em
  aparelhos, ruído de ambiente, microfone de celular).
- Fala: sem dados reais; glissandos harmônicos lentos passam pelo gate.
- `HarmonicJumpGuard` depende de RMS: uma corda tocada muito fraca enquanto
  outra ainda soa alto pode não gerar "ataque"; nesse caso a nota nova só
  aparece após 600 ms.

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
