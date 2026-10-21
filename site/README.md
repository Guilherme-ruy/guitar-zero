# Site estático do Guitar Zero

O código fica em `site/`, no mesmo repositório do app. São duas páginas:
`index.html` (três seções) e `privacidade.html`. HTML, CSS e JavaScript local,
sem PHP, framework, build, fontes externas, cookies, analytics ou CDNs.

## Estado do site

**Em desenvolvimento; não publicado.** A sequência da hero usa o vídeo
gerado no Google Flow, revisado e aprovado pelo proprietário para integração
em 20 de outubro de 2026. O trecho mostra a cabeça da guitarra da frente para
as costas, em uma meia-volta de 180°. Essa aprovação não é uma publicação do
site nem libera os botões das lojas.

## Enviar para a Hostinger

1. Faça backup dos arquivos existentes na pasta do domínio.
2. Extraia o ZIP do site e envie **seu conteúdo** para `public_html`, ou para a
   pasta pública vinculada ao domínio. `index.html`, `privacidade.html`,
   `styles.css`, `motion.js`, `how.js`, `assets/` e `vendor/`
   precisam ficar no mesmo nível.
3. Mantenha HTTPS ativo. Acesse o site e teste o link de privacidade.

Funciona também em subpastas; todos os caminhos são relativos. Não exige
Node, Flutter ou banco de dados no servidor. Se a hospedagem tiver um
`index.php` antigo, verifique qual arquivo é servido como início.
Os Markdown e a licença são documentação, sem necessidade de servir no site.
Não envie o repositório inteiro, arquivos do app, keystores ou secrets.

A política pública termina em `/privacidade.html`, sem login. Antes de
cadastrá-la no Play Console, confira o nome do responsável e as práticas
de logs da hospedagem. O app também deve oferecer acesso à política.

## Hero e movimento

`motion.js` usa GSAP + ScrollTrigger 3.15.0 para avançar e retornar uma
sequência de 70 imagens WebP conforme a rolagem nativa, com amortecimento
suave. A hero segue no fluxo normal, sem fixação nem altura artificial para
segurar a página. O medidor decorativo, maior e atrás da guitarra, varia mesmo
com a página parada, em uma oscilação senoidal lenta. Número e agulha seguem
o mesmo valor contínuo, amortecido em 160 ms e limitado a 20 unidades por
segundo; não há espera fixa entre números durante a rolagem. Duas camadas
de inteiros adjacentes fazem uma transição discreta de opacidade e posição.
O desvio permanece negativo durante o ajuste; o zero aparece somente ao
concluir o trajeto e aproximar a agulha do centro. A régua fica acima dos números,
com uma agulha e um segmento até o centro, sem uma segunda transição CSS que
atrase o movimento. A saída aguarda a leitura assentar em zero, mantém o zero
visível por 180 ms e suaviza a opacidade até o ponto indicado pela rolagem.
Assim uma descida rápida não encerra o movimento antes do centro.
Essa demonstração tem movimento próprio,
sem associar o ângulo da guitarra a uma afinação real. Não utiliza o microfone
nem reproduz áudio. A atualização acompanha requestAnimationFrame e pausa
quando a hero sai da tela ou a aba fica oculta.

O título é “Afine no zero.”, com sans de sistema e “zero” em serif itálica,
mais um traço SVG local. O fundo combina creme, sálvia e areia em gradientes
com movimento lento, sem novas imagens ou fontes externas.
O apoio é “Afinação simples, sem distrações.”, seguido de
“Rápido · Sem anúncios · Offline”. O cabeçalho mantém a marca centralizada e
os links GitHub/LinkedIn; a política de privacidade fica no rodapé. Os botões de loja têm
símbolos monocromáticos, borda sutil e indicação “Em breve”.

As bibliotecas foram obtidas da distribuição npm no jsDelivr e copiadas para
`vendor/`, com versão fixa e cabeçalhos originais preservados. O navegador
carrega tudo da própria hospedagem, sem chamadas à CDN. Licença e origem em
`vendor/README.md` e checksums em `vendor/sources.json`.

O canvas escolhe a sequência de 960, 1440 ou 1920 px pela largura real exibida
e pela densidade da tela, limitada a 2. Usa a menor variante suficiente, até
a resolução nativa do vídeo. Cada variante tem 70 quadros: 1,95 / 3,59 / 5,32 MB,
respectivamente. Depois de exibir o primeiro quadro, o navegador carrega os
70 arquivos comprimidos da variante escolhida e mantém seus Blobs em memória;
as outras duas resoluções não são carregadas. O pôster inicial tem 1440 px e
73.140 bytes.

O cache de bitmaps decodificados tem orçamento de 32 MiB: até oito imagens
no celular ou doze em telas maiores na variante 960; sete em 1440 e quatro
em 1920. Os Blobs comprimidos, o canvas e as decodificações em andamento usam
memória adicional. A rede permite três requisições simultâneas, independentemente
da decodificação: até três bitmaps em 960/1440 e dois em 1920. O quadro atual
e os vizinhos na direção da rolagem têm prioridade. Enquanto o destino exato
não fica pronto, o canvas exibe o vizinho disponível mais próximo. Bitmaps
antigos são liberados; arquivos carregados também podem ser reutilizados pelo
cache HTTP.

Os WebP da versão 4 já incluem transparência pré-calculada por
`tools/prepare_hero_alpha.py`. O processamento acrescenta um canal ALPH sem
perdas e preserva byte a byte o bloco VP8/RGB da conversão original. Somente
o branco conectado às bordas fica transparente; madeira e reflexos internos
dos cromados continuam opacos. Não há recorte de pixels durante a navegação.
A composição normal mantém números e régua atrás da guitarra. O medidor só
aparece quando o primeiro quadro está pronto.

A animação inicia automaticamente em todas as versões, inclusive quando o
sistema informa movimento reduzido, conforme a escolha do proprietário.
Nessa preferência, os movimentos ambientes do fundo e as oscilações paradas
do medidor ficam estáticos; a convergência e o giro por rolagem continuam.
Nenhuma versão da
hero fixa a seção ou bloqueia a rolagem.
JavaScript desativado ou recursos necessários indisponíveis
mantêm o pôster estático e o medidor oculto;
o conteúdo e os links continuam funcionando. Sirva por HTTP/HTTPS; o canvas
usa fetch para arquivos locais, então abrir o HTML por `file://` mantém o pôster.

Para visualizar localmente: `python -m http.server 8080 --directory site`
a partir da raiz do repositório; abra `http://localhost:8080`.

## Instrumentos e modos de afinação

A segunda seção usa o título “Afine rápido. Mais música.”, com o segundo
trecho em serif itálica. Mantém o fundo escuro, com luzes suaves em movimento,
e os cartões de violão e guitarra feitos com as ilustrações do app. Os cartões
trocam o design da prévia, sem alterar a corda selecionada ou o modo de afinação.
O violão mostra três notas de cada lado; a guitarra, seis à esquerda. As posições
das notas e suas ligações às tarraxas vêm do layout do app, com a mesma proporção
de imagem e adaptação da guitarra para telas menores.

`how.js` controla uma prévia visual do afinador, sem capturar áudio ou acessar
o microfone. O automático demonstra as seis cordas
a cada 4,8 segundos; o manual mantém a corda escolhida. Tocar em qualquer
nota entra no manual, e o botão Auto volta à identificação automática,
como no app. Os dois E são diferenciados pela 6ª/1ª corda e pelos rótulos
acessíveis E2/E4. A agulha mostra “Afinando” na aproximação e “Afinada” no centro.

O ciclo pausa fora da prévia, em aba oculta, com foco ou ponteiro sobre ela
e em movimento reduzido. Os controles continuam operáveis por teclado;
preferência de movimento reduzido também desativa as luzes ambientes.
Auto e Manual ficam em um seletor discreto no topo da prévia; a escolha do
visual é o destaque da seção. Não há parágrafos explicando cada modo.
O texto “Escolha o visual.” e os cartões são centralizados em relação ao painel;
os rótulos visuais “Prévia do app” e instrumento/afinação foram retirados.

## Simplicidade e links do projeto

“Sem cadastro. Sem complicação.” explica três benefícios em linguagem simples:
o app não grava nem salva o áudio, o afinador funciona sem internet e não pede
login, e-mail ou dados pessoais. A seção mantém o creme/sálvia e a combinação
de sans com serif itálica, com uma lista curta no lugar do aparelho decorativo.
O link “Veja o projeto no GitHub” leva ao repositório público
`https://github.com/Guilherme-ruy/guitar-zero`, acompanhado de “Código open source
sob a licença MIT.”. A indicação se refere ao código; artes, marcas e bibliotecas
mantêm as condições descritas nas respectivas licenças.

Nas duas páginas, o cabeçalho mantém a marca central e os links GitHub/LinkedIn
com seus ícones SVG à esquerda dos nomes.
Em telas pequenas os links ficam abaixo da marca, sem sobreposição. O rodapé usa
o mesmo PNG e a mesma identidade da marca. GitHub e LinkedIn aparecem como ícones
com rótulos acessíveis e áreas de toque de 44px; LinkedIn é o contato com o criador
em `https://www.linkedin.com/in/guiruy/`. O link da política fica no rodapé e abre
em nova aba, preservando a página inicial. Os ícones SVG estão no próprio HTML,
sem imagens, fontes ou bibliotecas adicionais.
Os links externos e a política abrem em outra aba, com indicação acessível e isolamento da
página de origem. A política completa mantém seu conteúdo e os e-mails para
questões de privacidade; somente seu cabeçalho e rodapé foram padronizados.

## Arte e edição

- `assets/hero-sequence/`: frames derivados do vídeo aprovado do Google Flow,
  convertido a partir da versão em 1080p. Medidas e conversão no README/manifest
  dessa pasta; pôster frontal igual ao primeiro frame. O MP4 e seu áudio não entram
  no site. Os WebP v4 trazem o canal alpha pronto, mantendo o bloco VP8/RGB
  original e as cores do instrumento.
  A imagem ultrapassa seu espaço no layout, à frente do medidor decorativo.
  Uma máscara suave só na borda esquerda disfarça o corte do braço, fora do medidor;
  não recria partes do instrumento ausentes no original.
- `tools/convert_hero_video.py`: conversor opcional para reproduzir os assets
  com FFmpeg/ffprobe locais, Python, Pillow e NumPy. Não é executado pelo site
  e não cria dependência de Python na hospedagem. A conversão remove o primeiro segundo de pausa e
  amostra 70 quadros a 10 fps em três resoluções, WebP qualidade 88, e prepara
  o alpha com `tools/prepare_hero_alpha.py`. Essa ferramenta também pode derivar
  a versão 4 de uma sequência v3 existente, sem recodificar seu VP8/RGB.
  As URLs da sequência e do pôster usam `v=4`; HTML carrega `styles.css?v=13`,
  `motion.js?v=8` e `how.js?v=2`. O manifest registra `assetVersion: 4`.
- As duas ilustrações menores reaproveitam as imagens aprovadas do app.
  Favicon também deriva da logo aprovada. A dedicação CC0 em
  `assets/LICENSE.txt` cobre essas ilustrações; os derivados do vídeo e o GSAP
  têm suas próprias notas de origem/condições.
- A marca inicial é centralizada, com o PNG original de guitarrista
  `assets/guitarist-mark-v2.png` (1254 × 1254, 474.648 bytes, transparência real),
  gerado pela ferramenta integrada e aprovado pelo proprietário em 21 de outubro
  de 2026. A geração usou somente descrição textual; o PNG/SVG da Flaticon
  não foi fornecido ao modelo nem integrado ao site. O SVG manual anterior foi
  retirado. A tipografia continua de sistema; não muda o ícone do app.
  Os botões das lojas são
  centralizados e compactos, mantendo os símbolos e o acabamento aprovados.
- Edite os textos nos HTML e as cores/medidas em `styles.css`.
- As duas lojas aparecem como botões desativados com “Em breve”. No lançamento,
  substitua o botão da loja publicada por um link para a ficha real. Os ícones
  são símbolos locais monocromáticos; não são selos oficiais de download.

## Site e builds do app

Esta pasta não é um asset do Flutter e não entra no APK/AAB. O CI faz uma
verificação leve e pula testes Flutter/build APK quando todos os arquivos
alterados estão em `site/`. Alterações fora da pasta continuam disparando
os checks do app; em pull requests, vale o conjunto completo de mudanças do
PR. O workflow de AAB permanece manual. Não é preciso separar repositórios
para evitar recompilar o app ao editar somente o site.

A política descreve o app atual: áudio em memória, sem upload, preferências
locais e sem permissão INTERNET no release. O backup do Android pode incluir
preferências; o site pode gerar logs técnicos no provedor de hospedagem.

## Código, artes e identidade

O HTML, CSS e JavaScript originais do site seguem a [licença MIT](../LICENSE)
do projeto. GSAP e ScrollTrigger mantêm os termos próprios descritos em
[vendor/README.md](vendor/README.md); seus arquivos não são relicenciados.
As ilustrações identificadas em [assets/LICENSE.txt](assets/LICENSE.txt)
continuam CC0. Os frames do vídeo têm os termos separados de sua pasta e
não recebem automaticamente MIT ou CC0.

O nome, símbolo e favicon identificam o Guitar Zero. A
[política de identidade](../TRADEMARKS.md) trata dos direitos de marca,
sem revogar as licenças autorais das artes.
