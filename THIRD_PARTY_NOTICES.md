# Third-party notices

Este arquivo registra todo código, asset ou dado de terceiros incluído no
Guitar Zero, com origem, licença e o que foi reutilizado ou adaptado.

## Código reutilizado ou adaptado

**Nenhum até o momento.** Todo o código deste repositório foi escrito para o
Guitar Zero.

Ao reutilizar ou adaptar código de terceiros:

1. adicione uma entrada abaixo com projeto, URL, commit, licença e arquivos
   afetados;
2. preserve os avisos de copyright e licença exigidos (ex.: Apache 2.0 exige
   manter o `NOTICE` do projeto de origem, se houver, e indicar alterações);
3. marque o trecho no próprio arquivo com um comentário de origem;
4. inclua o texto da licença em `third_party/licenses/` quando necessário.

## Referências técnicas (consultadas, não copiadas)

Projetos estudados como referência técnica e de parâmetros. Nenhum código
deles está incluído no repositório. O `YinPitchDetector`
(`lib/core/dsp/yin_pitch_detector.dart`) é implementação própria a partir do
paper do YIN; dos projetos vieram apenas ideias e valores iniciais (faixa de
busca, limiar, gate de RMS, gate de confiança 0.90).

O pipeline temporal (`lib/core/dsp/filters/`, `lib/core/music/string_tracker.dart`,
`lib/core/tuner/`) também é implementação própria: o One Euro Filter foi
escrito a partir do paper de Casiez et al.; stability gate, proteção temporal
de oitava, reset de nova nota, histereses e hold seguem ideias e valores
iniciais do fgnass/tuner (janela de estabilidade, 20 cents, minCutoff 0.6,
beta 0.06, 250 cents, 30 cents, 3/6 cents, 700 ms), sem cópia de código.

| Projeto | Licença | Uso |
| --- | --- | --- |
| [PitchKit](https://github.com/NicosNicolaou16/PitchKit) @ `26a7909` — Nicos Nicolaou | Apache 2.0 | Referência: YIN, high-pass/DC removal, energy gate, smoothing temporal |
| [tuner](https://github.com/fgnass/tuner) @ `b59d8b9` — Felix Gnass | MIT | Referência: YIN + refinamento harmônico via FFT, stability gate, One Euro Filter no domínio de cents |

Artigos de referência:

- A. de Cheveigné, H. Kawahara. *YIN, a fundamental frequency estimator for
  speech and music*. JASA, 2002. https://doi.org/10.1121/1.1458024
- G. Casiez, N. Roussel, D. Vogel. *1€ Filter*. CHI 2012.
  https://gery.casiez.net/1euro/

## Dependências de pacotes

Dependências de runtime: apenas o SDK Flutter (BSD-3-Clause).
Dependências de desenvolvimento: `flutter_lints` (BSD-3-Clause).

As licenças das dependências Flutter/Dart são exibidas automaticamente pelo
`LicenseRegistry` do Flutter e podem ser expostas em uma tela "Sobre" futura.
