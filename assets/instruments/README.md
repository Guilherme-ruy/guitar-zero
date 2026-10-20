# Guitar Zero — headstocks estáticos, revisão 3

Violão 3+3 em nogueira mais larga; guitarra com 6 tarraxas à esquerda em maple
claro, proporções naturais e linha inclinada de tarraxas. Vista frontal,
cordas fixas na imagem: **somente os botões das notas mudam de cor**.

WebP com transparência e qualidade 90: base 288×360 px, `2.0x/` 576×720 px,
`3.0x/` 864×1080 px. PNGs mestres de 1122×1402 px são entregues separadamente;
não os inclua no APK. As variantes seguem a
[estrutura oficial do Flutter](https://docs.flutter.dev/ui/assets/assets-and-images).

## JSON e layout

`acoustic_headstock.json` e `electric_headstock.json` contêm seis centros de
chave e pino, pestana/slots, áreas livres e centros sugeridos dos botões.
Coordenadas 0–1 sobre **toda a imagem, incluindo transparência**; origem no
canto superior esquerdo. Calibradas visualmente nos mestres finais,
tolerância aproximada ±4 px. Slots da esquerda para a direita:
E2/A2/D3/G3/B3/E4. Violão: esquerda cima→baixo D3/A2/E2, direita G3/B3/E4;
guitarra: esquerda cima→baixo E4/B3/G3/D3/A2/E2.

Use `contain`, preserve a proporção e calcule o retângulo real após o fit:
`X = imageLeft + x * imageWidth`; `Y = imageTop + y * imageHeight`.
Compartilhe esse retângulo com todos os overlays; não use o Stack inteiro
se houver letterbox e não recorte as imagens. Ancore embaixo.

Não esprema o instrumento para criar espaço: deixe margem externa vazia no
Stack. Botões de 40–48 dp e área de toque de pelo menos 44 dp podem ultrapassar
o retângulo da imagem nas laterais; **não aplique clipping nessa borda**.
`button_safe_areas` identifica pixels livres dentro do canvas, não promete
que o círculo de toque inteiro caiba dentro dele.

Em 360×640 dp, reserve aproximadamente 320 dp para a região do instrumento.
Violão: `button_center`; guitarra: `compact_button_center`, seis botões em
coluna com pequenos conectores até as chaves, 0,14 da altura entre centros
(44,8 dp em 320 dp). Isso evita encolher as áreas de toque para acompanhar
uma mão real, cujas tarraxas são mais próximas. `button_center` da guitarra
é uma alternativa diagonal para canvas renderizado de pelo menos 500 dp.
Se a região tiver menos de 320 dp, ajuste o conteúdo superior ou use o visual
minimalista. A prévia local ilustra a opção compacta; não é um teste Flutter.

Assinatura manuscrita discreta “Guitar Zero” incorporada na madeira dos dois
instrumentos; `brand_wordmark` registra texto e área normalizada. Não desenhe
um segundo logo/anel por cima. Cordas graves do violão em metal mais neutro,
com dourado reduzido. O pino E4 da guitarra foi recalibrado após a edição.
Botões ativos
laranja `#FF8A3D` ou menta `#5BE5A9`; também diferencie seleção/afinação por
borda/estado e semântica acessível. Nenhum destaque individual nas cordas.

Na integração futura, declare apenas as imagens base e os dois JSONs no
`pubspec.yaml`; o Flutter inclui as variantes automaticamente.
Nenhum Dart, pubspec ou workflow foi modificado.

## Origem e licença

Gerado em 2026-10-02 pela ferramenta ImageGen integrada; prompts finais em
`generation-prompts.md`. As imagens-base foram geradas do zero, sem imagens de fabricantes ou
screenshots como entrada. Nesta revisão foram editadas pelo próprio ImageGen:
assinaturas nos dois instrumentos e redução do dourado no violão. A imagem
editada do violão foi referência de lettering para a edição da guitarra. Pesquisa visual e de proporções:
[Belforti](https://belforti.shop/products/kone-6-essential-cerussitgrau),
[Nuno Guitars](https://www.nunoguitars.com/products/dark-horse) e
[Gelvin Guitars](https://gelvinguitars.com/builds/designing-guitars-and-templates.html).
Referências não são copiadas nem redistribuídas no pacote. Materiais/luz
coerentes, assinatura própria Guitar Zero e nenhuma marca de terceiros; silhuetas geradas com orientação própria.
Pillow usado apenas para conversão e densidades, sem retoque/composição.

**CC0-1.0** para estes assets, JSONs e documentação, livre para uso comercial,
modificação e redistribuição, sem crédito obrigatório. Veja `LICENSE.txt`.
Os [termos da OpenAI](https://openai.com/policies/row-terms-of-use/) atribuem
ao usuário os direitos que a OpenAI tiver sobre a saída, na extensão permitida
por lei. Não há garantia de exclusividade; CC0 não transfere marcas de terceiros.

As assinaturas Guitar Zero identificam o projeto. O uso dessa identidade
segue a [política de nome e logo](../../TRADEMARKS.md), sem alterar a CC0
das ilustrações, dos JSONs e da documentação desta pasta.

Pacote visual aprovado pelo proprietário para publicação no repositório. Integração e
validação no app/aparelho permanecem pendentes.


