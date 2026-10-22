# Guitar Zero — ícone menta

Vista traseira da cabeça de guitarra, com seis tarraxas em linha, madeira
clara, prata e assinatura Guitar Zero. A versão com fundo menta e luz creme
foi aprovada pelo proprietário em 22/10/2026 e usada na ficha da Play Store.

| Arquivo | Uso | Especificação |
| --- | --- | --- |
| `guitar_zero_play_store_512.png` | Play Store e README | 512 × 512, PNG RGBA, arquivo aprovado na loja |
| `guitar_zero_ios_1024.png` | Fonte dos ícones nativos Android e iOS | 1024 × 1024, PNG RGB, sem transparência |

A imagem de 512 px é a mesma enviada à Play Store. A de 1024 px foi
exportada do mestre aprovado de 1254 px. Ambas mantêm a composição diagonal,
as seis tarraxas e o braço saindo pela borda inferior direita. Não há cordas
sobre o verso da cabeça. Os arquivos são quadrados, sem máscara incorporada.
A assinatura é decorativa e perde legibilidade nos menores tamanhos.

## Integração no aplicativo

- **Android:** `android/app/src/main/res/mipmap-*` contém os ícones tradicionais
  de 48, 72, 96, 144 e 192 px. Os adaptativos têm camadas de 108 dp nas cinco
  densidades: a arte ocupa os 72 dp centrais e os pixels das bordas são
  prolongados nos 18 dp externos para os efeitos do launcher. O fundo de
  segurança é menta (`#BCE9BE`), configurado em `ic_launcher_background.xml`.
  O manifesto já referencia `@mipmap/ic_launcher`.
- **iOS:** os 15 PNGs de `ios/Runner/Assets.xcassets/AppIcon.appiconset/`
  foram exportados nos tamanhos declarados pelo catálogo existente, em RGB
  sem transparência. **O app iOS ainda não foi testado.**

Os recortes circular e arredondado do Android foram conferidos visualmente.
A extremidade do braço pode ser recortada pela máscara do aparelho; as seis
tarraxas e a assinatura permanecem visíveis na prévia estática.
O sistema pode alterar cores quando o usuário habilita ícones temáticos.
A instalação de uma nova versão do app é necessária para atualizar seu ícone;
alterar apenas a ficha da loja não muda o aplicativo instalado.

Estes arquivos não são assets Flutter de runtime. Os recursos nativos são
incluídos pelos respectivos builds, sem declaração adicional no `pubspec.yaml`.

Referências oficiais: [Android adaptativo](https://developer.android.com/develop/ui/compose/system/icon_design_adaptive),
[Google Play](https://developer.android.com/distribute/google-play/resources/icon-design-specifications)
e [Xcode](https://developer.apple.com/documentation/xcode/configuring-your-app-icon).

## Origem e licença

Arte gerada com ImageGen integrada, originalmente a partir da foto de vista
traseira fornecida pelo proprietário e de um conceito anterior como referência
de estilo. A edição menta substitui o fundo preto, preservando a vista traseira,
as seis tarraxas e a assinatura. Prompts em [generation-prompts.md](generation-prompts.md).
A foto e os conceitos descartados não são distribuídos. O mestre de 1254 px
permanece nos arquivos locais de preparação da loja, fora do repositório.

Pillow foi usado para redimensionar, converter, exportar e preparar a margem
externa do ícone adaptativo. A guitarra não foi redesenhada nesse processo.

A ilustração e esta documentação mantêm a dedicação **CC0-1.0**, permitindo
uso comercial, modificação e redistribuição; veja [LICENSE.txt](LICENSE.txt).
Ela não concede direitos de marca. A [política de identidade](../../TRADEMARKS.md)
trata do uso do nome e da logo para identificar a origem de um produto e não
revoga as permissões CC0. Direitos sobre a saída seguem os
[termos da OpenAI](https://openai.com/policies/row-terms-of-use/), na extensão
permitida por lei. Não há garantia de exclusividade.
