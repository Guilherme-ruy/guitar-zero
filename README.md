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

Captura PCM mono → noise gate → **YIN** → restrição de faixa → stability gate →
proteção contra oitava → mediana → **One Euro Filter** em cents → corda mais
provável com histerese → leitura para a UI.

A proposta completa, ainda em revisão, está em
[docs/DSP_STRATEGY.md](docs/DSP_STRATEGY.md).

## Situação atual

| Item | Estado |
| --- | --- |
| Estrutura do projeto, lint, CI | ✅ |
| Teoria musical (notas, cents, Standard, corda mais próxima) | ✅ implementado e testado |
| Contratos `AudioInput`, `PitchDetector`, `PitchFilter`, `TunerEngine` | ✅ |
| `PitchTunerEngine` (orquestração do pipeline) | ✅ testado com fakes |
| Tela do afinador (estrutural) | ✅ rodando com engine simulado (selo **DEMO**) |
| Captura de microfone real | ⏳ não implementado |
| Detecção de pitch (YIN) e filtros | ⏳ aguardando revisão da estratégia |
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

[`.github/workflows/ci.yml`](.github/workflows/ci.yml) roda em todo push na
`main` e em pull requests:

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
