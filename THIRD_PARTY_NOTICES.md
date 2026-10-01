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

Projetos estudados como referência de técnica. Nenhum código deles está
incluído no repositório.

| Projeto | Licença | Uso |
| --- | --- | --- |
| [PitchKit](https://github.com/NicosNicolaou16/PitchKit) — Nicos Nicolaou | Apache 2.0 | Referência: YIN, high-pass/DC removal, energy gate, smoothing temporal |
| [tuner](https://github.com/fgnass/tuner) — Felix Gnass | MIT | Referência: YIN + refinamento harmônico via FFT, stability gate, One Euro Filter no domínio de cents |

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
