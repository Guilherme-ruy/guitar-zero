# Guitar Zero

Afinador para **guitarra e violão de 6 cordas**: simples, rápido, bonito e
100% offline.

Quanto mais perto da nota certa, mais o indicador converge para o **zero**.

## Objetivo

A primeira versão é só um afinador, muito bem feito:

- afinação Standard: E2 82.41 · A2 110.00 · D3 146.83 · G3 196.00 ·
  B3 246.94 · E4 329.63 Hz;
- identificação automática da corda (**AUTO**) ou escolha manual tocando na
  corda; só o switch volta ao automático;
- headstock de **violão** (3+3) ou **guitarra** (6 em linha) em imagem
  própria, ou visual **minimalista**; só os botões das notas indicam a corda;
- nomes das notas em letras (E A D), solfejo (Mi Lá Ré) ou ambos;
- medidor de abaixo/acima e feedback visual quando afinada (o número em
  cents fica só no painel de diagnóstico);
- instrução que não pisca: o último resultado fica na tela por 5 s depois
  que o som acaba, e então diz o próximo passo.

Fora de escopo nesta versão: login, backend, banco de dados, analytics,
anúncios, metrônomo, acordes, afinações alternativas, recursos sociais.

## Privacidade

- O microfone é usado **apenas** para detectar a frequência das cordas.
- Todo o processamento acontece no aparelho, em memória.
- Nenhum áudio é gravado, armazenado ou enviado para a internet.
- O build Android de release não declara a permissão `INTERNET`.
- O microfone é liberado quando o app vai para segundo plano.

## Stack

- Flutter 3.47.5 (stable) · Dart 3.13
- Plataforma inicial: Android. iOS preparado (pasta `ios/` e
  `NSMicrophoneUsageDescription`), ainda não validado.
- Dependências de runtime (BSD-3-Clause), isoladas em `lib/platform/`:
  [`record`](https://pub.dev/packages/record) para ler o microfone e
  [`shared_preferences`](https://pub.dev/packages/shared_preferences) para
  guardar as preferências visuais no aparelho. Estado com `ChangeNotifier`
  nativo.

## Arquitetura

```
UI → TunerController → TunerEngine → AudioInput → PitchDetector → PitchFilter → StringMatcher
```

- `lib/core/music/` — notas, cents, afinações, corda mais provável (Dart puro)
- `lib/core/audio/` — contrato de captura do microfone
- `lib/core/dsp/` — contratos de detecção de pitch e filtros
- `lib/core/tuner/` — engine que orquestra o pipeline
- `lib/features/tuner/` — controller e widgets da tela
- `lib/main.dart` — composition root

Detalhes em [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md).

## Como o processamento vai funcionar

Captura PCM mono → remoção de DC + RMS gate → **YIN** → **análise harmônica
(FFT: correção de oitava, refinamento, harmonicidade)** → gate de confiança →
faixa → proteção temporal de oitava → stability gate → **One Euro** em cents →
corda com histerese → afinado com histerese → hold de silêncio → UI.

Estratégia, fases e resultados medidos em
[docs/DSP_STRATEGY.md](docs/DSP_STRATEGY.md).

Ferramentas (fora do CI):

```bash
dart run tool/yin_report.dart      # caracterização com sinais sintéticos
dart run tool/dsp_benchmark.dart   # custo por frame (YIN, espectral, total)
dart run tool/spectral_report.dart # oitava, refinamento, harmonicidade
dart run tool/real_audio_eval.dart <dir_wav_44k> <selected.json>  # áudio real (NSynth)
dart run tool/real_scenarios.dart  # troca de corda com sobreposição, ruído
dart run tool/temporal_report.dart # pipeline temporal: janela 3 vs 5, beta
```

## Situação atual

| Item | Estado |
| --- | --- |
| Estrutura do projeto, lint, CI | ✅ |
| Teoria musical (notas, cents, Standard, corda mais próxima) | ✅ implementado e testado |
| Contratos `AudioInput`, `PitchDetector`, `PitchFilter`, `TunerEngine` | ✅ |
| `PitchTunerEngine` (orquestração do pipeline) | ✅ testado com fakes |
| Tela do afinador | ✅ microfone real; AUTO/manual; violão, guitarra ou minimalista; letras/solfejo; ajustes salvos; painel de diagnóstico oculto |
| Captura de microfone (`record`, PCM16, sem AGC/NS/AEC) + DSP em isolate | ✅ implementado e testado com fakes; ⚠️ **não validado em aparelho** |
| Detector YIN em Dart puro (`YinPitchDetector`) | ✅ testado com sinais sintéticos |
| Pipeline temporal (gates, octave guard, stability gate, One Euro, histereses, hold) | ✅ testado com sequências sintéticas |
| Análise espectral (FFT própria, correção de oitava, refinamento, harmonicidade) | ✅ testada com sinais sintéticos |
| Build Android (APK release) no CI | ✅ |
| Avaliação com 214 notas reais (NSynth) + 6 em teste de regressão no CI | ✅ 0 notas exibindo corda/oitava errada |
| Troca de corda com a anterior soando, ruído (gravações reais misturadas) | ✅ testado; ⚠️ duas cordas em volume parecido ainda atrasam a troca |
| Execução em aparelho Android / iOS | ⏳ não validado |

## Como executar

Pré-requisitos: Flutter 3.47.5 stable e Android SDK.

```bash
flutter pub get
flutter run                                     # microfone real
flutter run --dart-define=GUITAR_ZERO_DEMO=true # leituras simuladas (selo DEMO)
flutter analyze
flutter test
```

**Sem Flutter instalado**: pushes com mudanças fora de `site/` geram no GitHub Actions o artefato
`guitar-zero-apk` (APK release, assinado com a chave de debug — só para
teste). Baixe em *Actions → CI → execução → Artifacts* e instale no Android
(permitindo "fontes desconhecidas").

## Teste em aparelho

A captura ao vivo ainda não foi validada em celular. Roteiro curto:

1. Instale o APK do artefato `guitar-zero-apk` e permita o microfone.
2. Toque longo em **GUITAR ZERO** abre o painel de diagnóstico: tempo de
   DSP por frame, frames descartados, frequência bruta, periodicidade,
   harmonicidade e nível RMS.
3. Toque cada corda solta algumas vezes (com e sem abafar) e gire a tarraxa
   devagar e rápido.
4. Observe: tempo até a nota aparecer, corda identificada, tremor do
   ponteiro, se a leitura muda de corda/oitava no fim da nota, e o
   comportamento com fala ou ruído por perto.
5. Reporte com prints do painel (principalmente "DSP … ms" e
   "descartados") e o modelo do aparelho.

## CI

Publicação na Play Store: o workflow manual **Play Store AAB** entrega o bundle
assinado após configurar os secrets de upload. Guia em
[docs/PLAY_STORE.md](docs/PLAY_STORE.md). O site estático (início e política de
privacidade) está em [site/](site/README.md), sem build ou backend.

[`.github/workflows/ci.yml`](.github/workflows/ci.yml) roda em todo push (qualquer
branch) e em pull requests para a `main`:

Uma verificação leve compara os arquivos alterados. Quando todos estão em
`site/`, os jobs de Flutter e APK são pulados; o site não está declarado nos
assets do Flutter e não entra no APK/AAB. Alterações mistas, novas branches
e execuções manuais continuam validando e compilando o app. Pull requests
comparam o conjunto de alterações desde a base, incluindo mudanças do app
feitas em commits anteriores do mesmo PR.

1. `flutter pub get`
2. `dart format --set-exit-if-changed`
3. `flutter analyze --fatal-infos`
4. `flutter test`
5. `flutter build apk --release` + verificação de que o APK não declara
   `INTERNET` + upload do APK como artefato.

## Open source

Nenhum código de terceiros copiado. Dependências, referências técnicas e
política de reutilização: [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md).

O GuitarTuna é usado apenas como referência de experiência de usuário; nenhum
código, asset ou elemento visual dele é utilizado.
