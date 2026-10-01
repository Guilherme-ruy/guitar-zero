# Guitar Zero

Afinador para **guitarra e violão de 6 cordas**: simples, rápido, bonito e
100% offline.

Quanto mais perto da nota certa, mais o indicador converge para o **zero**.

## Objetivo

A primeira versão é só um afinador, muito bem feito:

- afinação Standard: E2 82.41 · A2 110.00 · D3 146.83 · G3 196.00 ·
  B3 246.94 · E4 329.63 Hz;
- identificação automática da corda;
- indicação de abaixo/acima em cents e feedback visual quando afinada.

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
- Sem dependências de runtime além do SDK Flutter. Estado com
  `ChangeNotifier` nativo.

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
dart run tool/temporal_report.dart # pipeline temporal: janela 3 vs 5, beta
```

## Situação atual

| Item | Estado |
| --- | --- |
| Estrutura do projeto, lint, CI | ✅ |
| Teoria musical (notas, cents, Standard, corda mais próxima) | ✅ implementado e testado |
| Contratos `AudioInput`, `PitchDetector`, `PitchFilter`, `TunerEngine` | ✅ |
| `PitchTunerEngine` (orquestração do pipeline) | ✅ testado com fakes |
| Tela do afinador (estrutural) | ✅ rodando com engine simulado (selo **DEMO**) |
| Captura de microfone real | ⏳ não implementado |
| Detector YIN em Dart puro (`YinPitchDetector`) | ✅ testado com sinais sintéticos |
| Pipeline temporal (gates, octave guard, stability gate, One Euro, histereses, hold) | ✅ testado com sequências sintéticas |
| Análise espectral (FFT própria, correção de oitava, refinamento, harmonicidade) | ✅ testada com sinais sintéticos |
| Execução em aparelho Android / iOS | ⏳ não validado |

## Como executar

Pré-requisitos: Flutter 3.47.5 stable e Android SDK.

```bash
flutter pub get
flutter run           # aparelho/emulador Android
flutter analyze
flutter test
```

Hoje o app mostra leituras **simuladas** (selo DEMO): ainda não usa o microfone.

## CI

[`.github/workflows/ci.yml`](.github/workflows/ci.yml) roda em todo push (qualquer
branch) e em pull requests para a `main`:

1. `flutter pub get`
2. `dart format --set-exit-if-changed`
3. `flutter analyze --fatal-infos`
4. `flutter test`

Build Android (APK) será adicionado depois.

## Open source

Nenhum código de terceiros incluído até agora. Referências técnicas e
política de reutilização: [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md).

O GuitarTuna é usado apenas como referência de experiência de usuário; nenhum
código, asset ou elemento visual dele é utilizado.
