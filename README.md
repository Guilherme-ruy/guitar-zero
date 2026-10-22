<div align="center">
  <img src="assets/branding/guitar_zero_play_store_512.png" alt="Ícone do Guitar Zero" width="104" height="104">
  <h1>Guitar Zero</h1>
  <p><strong>Afine no zero.</strong></p>
  <p>Afinador para guitarra e violão de seis cordas.<br>Rápido, offline e sem anúncios.</p>
  <a href="https://github.com/Guilherme-ruy/guitar-zero/actions/workflows/ci.yml"><img src="https://github.com/Guilherme-ruy/guitar-zero/actions/workflows/ci.yml/badge.svg?branch=main" alt="Status do CI"></a>
  <p>Flutter · Android testado · iOS ainda não testado · Código MIT</p>
  <p><a href="#sobre">Sobre</a> · <a href="#recursos">Recursos</a> · <a href="#como-executar">Como executar</a> · <a href="#documentação">Documentação</a></p>
</div>

## Sobre

O **Guitar Zero** é um projeto pessoal com uma proposta simples: abrir o app,
afinar o instrumento e voltar a tocar.

A inspiração vem da praticidade de afinadores como o **GuitarTuna**. O Guitar Zero
é um projeto independente, com implementação e identidade próprias, focado em
uma experiência direta, sem cadastro e sem anúncios. Conforme a corda se
aproxima da nota correta, o indicador chega ao **zero**.

O app atende guitarras e violões de seis cordas em **afinação padrão**,
da mais grave para a mais aguda: **E · A · D · G · B · E**.

## Recursos

| Recurso | Como funciona |
| --- | --- |
| Automático ou manual | Detecta a corda tocada ou permite escolher uma nota na tela. |
| Visual do instrumento | Escolha entre violão, guitarra ou uma interface minimalista. |
| Nomes das notas | Letras, solfejo ou os dois: **E**, **Mi** ou **E / Mi**. |
| Afinação visual | Mostra se a nota está baixa, alta ou afinada. |
| Preferências salvas | Mantém suas escolhas de exibição no aparelho. |
| Tela acesa no Android | Permite afinar sem tocar na tela para evitar o bloqueio automático. |

O fundo do app tem luz ambiente e movimento suave, com respeito à preferência
de redução de animações do sistema.

## Plataformas e disponibilidade

| Plataforma | Situação |
| --- | --- |
| **Android** | **Testado em aparelho real.** Build e testes automatizados também disponíveis no CI. |
| **iOS** | Estrutura inicial e permissão de microfone preparadas. **Ainda não testado.** |
| Google Play e App Store | Publicação pendente. |
| Site de apresentação | Implementado, com animação e prévia interativa. Ainda não publicado. |

## Privacidade no app

- O microfone serve apenas para identificar a frequência e a nota das cordas.
- O áudio é processado no aparelho, em memória: não é gravado nem enviado.
- O app funciona sem internet, login, anúncios ou Analytics.
- O microfone é liberado quando o app vai para segundo plano.
- O build Android de release não declara a permissão `INTERNET`.

As preferências visuais ficam salvas localmente. A [política de privacidade](site/privacidade.html)
detalha o funcionamento do app e as práticas do site.

## Como executar

Pré-requisitos: **Flutter 3.47.5 stable**, Android SDK e um aparelho ou emulador
configurado. O app precisa de permissão de microfone para afinar ao vivo.

```bash
flutter pub get
flutter run
```

Para testar no Android sem instalar Flutter, baixe o artefato **`guitar-zero-apk`**
em uma execução do [CI](https://github.com/Guilherme-ruy/guitar-zero/actions/workflows/ci.yml)
que tenha concluído o build do app. Esse APK usa assinatura de depuração e é
destinado a testes.

<details>
<summary>Modo demo e verificações locais</summary>

O modo demo usa leituras simuladas e exibe a identificação **DEMO** na tela.

```bash
flutter run --dart-define=GUITAR_ZERO_DEMO=true
flutter analyze --fatal-infos
flutter test
dart format --output=none --set-exit-if-changed lib test tool
```

Os testes do consentimento do site usam Node.js e não acessam o Google:

```bash
node --test site/tests/analytics.test.cjs
```

</details>

## Por dentro do projeto

O app é feito em **Flutter e Dart**, com captura de áudio pelo pacote `record`
e preferências locais com `shared_preferences`. O processamento de áudio roda
em um isolate, separado da interface.

A detecção combina **YIN**, análise harmônica por **FFT** e filtros temporais
para estabilizar a leitura e reduzir trocas indevidas de corda e oitava.

```text
Microfone → Detecção da nota → Estabilização → Identificação da corda → Interface
```

O pipeline tem testes com sinais sintéticos e gravações reais do **NSynth**.
Os resultados e as limitações estão na [estratégia de DSP](docs/DSP_STRATEGY.md).
As ferramentas de avaliação ficam em [tool/](tool/).

<details>
<summary>Organização do código e CI</summary>

```text
lib/
├── core/
│   ├── audio/        Contratos de captura
│   ├── dsp/          Detecção, análise espectral e filtros
│   ├── music/        Notas, afinação e identificação da corda
│   └── tuner/        Orquestração do processamento
├── features/tuner/  Controller e interface do afinador
├── platform/        Integrações com o aparelho
└── main.dart        Montagem do aplicativo
```

O [GitHub Actions](.github/workflows/ci.yml) verifica formatação, análise,
testes e build Android quando há alterações do app. Mudanças apenas em `site/`
pulam os jobs de Flutter e APK. O workflow manual de AAB prepara o bundle
assinado para envio ao Play Console, conforme o [guia de publicação](docs/PLAY_STORE.md).

</details>

## Site

O [site de apresentação](site/README.md) fica neste repositório e usa HTML, CSS e
JavaScript, sem backend ou etapa de build. A guitarra acompanha a rolagem com
uma sequência de imagens WebP do vídeo gerado no Google Flow, já aprovado
e integrado. Há também uma prévia interativa dos visuais e modos do afinador.

O Google Analytics foi integrado **somente ao site**, com consentimento opcional
e possibilidade de mudar a escolha no rodapé. A coleta real será validada após
a publicação. O app continua offline e sem Analytics.

## Documentação

- [Arquitetura e organização das camadas](docs/ARCHITECTURE.md)
- [Processamento de áudio, avaliações e limitações](docs/DSP_STRATEGY.md)
- [Preparação para publicar no Google Play](docs/PLAY_STORE.md)
- [Site, mídias e integração do Analytics](site/README.md)
- [Créditos e recursos de terceiros](THIRD_PARTY_NOTICES.md)

## Feedback e contribuições

Sugestões e relatos de problemas são bem-vindos nas
[issues](https://github.com/Guilherme-ruy/guitar-zero/issues). Em testes com o
app, informe o modelo do aparelho, a versão do Android, a corda tocada e o
comportamento observado. Um toque longo em **GUITAR ZERO** abre o painel de
diagnóstico para ajudar na investigação.

## Licença e identidade

O código original e a documentação geral seguem a [licença MIT](LICENSE).
O nome e a identidade Guitar Zero têm uma [política própria](TRADEMARKS.md).
As artes, os frames do vídeo, as dependências e os dados de teste mantêm os
termos indicados nos [créditos e licenças de terceiros](THIRD_PARTY_NOTICES.md).

---

Desenvolvido por **Guilherme Ruy** · [LinkedIn](https://www.linkedin.com/in/guiruy/)
