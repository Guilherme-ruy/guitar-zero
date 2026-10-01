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

## Referências

- PitchKit (Apache 2.0) e fgnass/tuner (MIT): consultados apenas os READMEs
  nesta fase — o acesso ao código-fonte via GitHub estava bloqueado no
  ambiente cloud. Nenhum código foi copiado. Ver `THIRD_PARTY_NOTICES.md`.
- de Cheveigné & Kawahara, *YIN*, JASA 2002.
- Casiez, Roussel & Vogel, *1€ Filter*, CHI 2012.
