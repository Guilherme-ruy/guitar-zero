# Guitar Zero — logo aprovada

Vista traseira de cabeça de guitarra com seis tarraxas, madeira clara, prata
fosca e assinatura manuscrita Guitar Zero. Composição e arte aprovadas pelo
proprietário em 2026-10-02.

| Arquivo | Uso | Especificação |
| --- | --- | --- |
| guitar_zero_play_store_512.png | Ícone da ficha no Google Play Console | 512×512, PNG RGBA 32 bits, sRGB, alpha 255 |
| guitar_zero_ios_1024.png | Fonte para AppIcon no catálogo de assets do Xcode | 1024×1024, PNG RGB, sRGB, sem alpha |

Quadrados completos, sem cantos arredondados incorporados. O fundo escuro e
a composição diagonal da arte aprovada foram preservados, incluindo o braço
saindo pela borda inferior direita. As máscaras das plataformas recortam essa
extremidade; as seis tarraxas e a assinatura ficam no interior. A assinatura
é decorativa e não permanece legível nos menores tamanhos de ícone.

O PNG de 512 é o ícone **da loja**, não configura o launcher do APK.
Use o PNG de 1024 como fonte para gerar os mipmaps Android na integração.
Para ícones adaptativos, preparar foreground/background e validar as máscaras
é uma etapa separada. Não há camadas transparentes ou arquivo Icon Composer
neste pacote.

No iOS, importe o PNG de 1024 para AppIcon usando o catálogo do Xcode;
o ícone acompanha a build enviada ao App Store Connect. Nenhum catálogo,
Dart, pubspec, recurso nativo ou workflow foi alterado por este pacote.
Não declare estes arquivos como assets Flutter de runtime: isso evita
incluí-los no APK sem necessidade. Flutter não foi executado aqui.

Referências oficiais:
[Google Play](https://developer.android.com/distribute/google-play/resources/icon-design-specifications) e
[Xcode](https://developer.apple.com/documentation/xcode/configuring-your-app-icon).

## Origem e licença

Gerado com ImageGen integrada, inicialmente usando a foto de vista traseira
fornecida pelo proprietário como referência de anatomia/composição, e um
conceito anterior como referência de estilo. A edição final substituiu
menta/teal por madeira clara/prata e acrescentou a assinatura. A foto e os
conceitos descartados não são distribuídos. Prompt final em
generation-prompts.md. Pillow foi usado apenas para redimensionar, converter
e exportar os PNGs; não houve retoque nem alteração da composição aprovada.
O mestre aprovado é entregue separadamente no ZIP, fora dos assets do repo.

CC0-1.0 para a ilustração e documentação, permitindo uso comercial,
modificação e redistribuição; veja LICENSE.txt. A dedicação não concede
direitos de marca. Direitos sobre a saída seguem os
[termos da OpenAI](https://openai.com/policies/row-terms-of-use/), na extensão
permitida por lei. Não há garantia de exclusividade.

O uso do nome e da logo para identificar a origem de um produto é tratado
separadamente em [TRADEMARKS.md](../../TRADEMARKS.md). Essa política não
altera a CC0 da ilustração nem revoga permissões anteriormente concedidas.
