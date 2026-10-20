# Site estático do Guitar Zero

O código fica em `site/`, no mesmo repositório do app. São duas páginas:
`index.html` (três seções) e `privacidade.html`. HTML, CSS e JavaScript local,
sem PHP, framework, build, fontes externas, cookies, analytics ou CDNs.

## Estado do site

**Em desenvolvimento; não publicado.** A sequência atual é provisória.
O vídeo final ainda será gerado no Gemini e precisa de revisão da anatomia,
da continuidade das seis tarraxas e de aprovação antes de substituir os
frames. A existência destes arquivos e sua integração à main não significam
que o site ou o vídeo foram aprovados para publicação.

## Enviar para a Hostinger

1. Faça backup dos arquivos existentes na pasta do domínio.
2. Extraia o ZIP do site e envie **seu conteúdo** para `public_html`, ou para a
   pasta pública vinculada ao domínio. `index.html`, `privacidade.html`,
   `styles.css`, `motion.js`, `assets/` e `vendor/` precisam ficar no mesmo nível.
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
sequência de 70 imagens WebP conforme a rolagem. O medidor acompanha o giro,
de −32 cents até zero, com mudança de laranja para verde. É uma demonstração
visual, sem acesso ao microfone ou reprodução de áudio.

As bibliotecas foram obtidas da distribuição npm no jsDelivr e copiadas para
`vendor/`, com versão fixa e cabeçalhos originais preservados. O navegador
carrega tudo da própria hospedagem, sem chamadas à CDN. Licença e origem em
`vendor/README.md` e checksums em `vendor/sources.json`.

O canvas usa a sequência de 480 px no celular (468 KB) ou de 864 px em telas
maiores (1,06 MB). São no máximo três requisições simultâneas, com prioridade
para o frame atual e os vizinhos. A memória de frames decodificados é limitada
a oito imagens no celular e doze em telas maiores; bitmaps antigos são
liberados. Frames carregados podem ser reutilizados pelo cache HTTP.

A animação inicia automaticamente em todas as versões, inclusive quando o
sistema informa movimento reduzido, conforme a escolha do proprietário.
A hero fica fixa quando cabe na altura da tela. Em janelas mais curtas,
continua animando no fluxo normal, sem fixar nem bloquear a rolagem.
JavaScript desativado ou recursos indisponíveis mantêm o pôster estático;
o conteúdo e os links continuam funcionando. Sirva por HTTP/HTTPS; o canvas
usa fetch para arquivos locais, então abrir o HTML por `file://` mantém o pôster.

Para visualizar localmente: `python -m http.server 8080 --directory site`
a partir da raiz do repositório; abra `http://localhost:8080`.

## Arte e edição

- `assets/hero-sequence/`: frames derivados do vídeo gerado no Gemini e enviado
  pelo proprietário. Medidas e conversão no README/manifest dessa pasta;
  pôster estático de boa qualidade. O vídeo MP4 original e seu áudio não entram
  no site. O fundo claro é integrado à página pelo CSS, sem alterar os pixels.
  A imagem ultrapassa seu espaço no layout, atrás dos textos e do medidor.
  Uma máscara suave nas bordas disfarça os cortes que já existem no vídeo;
  não recria partes do instrumento ausentes no original.
- As duas ilustrações menores reaproveitam as imagens aprovadas do app.
  Favicon também deriva da logo aprovada. A dedicação CC0 em
  `assets/LICENSE.txt` cobre essas ilustrações; os derivados do vídeo e o GSAP
  têm suas próprias notas de origem/condições.
- A marca do site é SVG inline + tipografia de sistema; não muda o ícone do app.
- Edite os textos nos HTML e as cores/medidas em `styles.css`.
- As duas lojas aparecem como botões desativados com “Em breve”. No lançamento,
  substitua o botão da loja publicada por um link para a ficha real. Os ícones
  são símbolos locais simplificados; não são selos oficiais de download.

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
