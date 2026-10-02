# Site estático do Guitar Zero

O código fica em `site/`, no mesmo repositório do app. São duas páginas:
`index.html` (três seções) e `privacidade.html`. HTML, CSS e JavaScript local,
sem PHP, framework, build, fontes externas, cookies, analytics ou CDNs.

## Enviar para a Hostinger

1. Faça backup dos arquivos existentes na pasta do domínio.
2. Extraia o ZIP do site e envie **seu conteúdo** para `public_html`, ou para a
   pasta pública vinculada ao domínio. `index.html`, `privacidade.html`,
   `styles.css`, `motion.js` e `assets/` precisam ficar no mesmo nível.
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

`motion.js` aproxima o indicador de −32 cents até zero conforme a rolagem,
com uma leve rotação da imagem e mudança de laranja para verde. É uma
demonstração visual, sem microfone, som, gravação ou requisição de rede.
Usa rolagem nativa, listener passivo e `requestAnimationFrame`, sem GSAP.

A animação só fixa a hero quando ela cabe na altura da tela. Com movimento
reduzido, economia de dados ou JavaScript desativado, exibe uma hero estática
afinada, sem espaço extra. O conteúdo e os links continuam funcionando.

Para visualizar localmente: `python -m http.server 8080 --directory site`
a partir da raiz do repositório; abra `http://localhost:8080`.

## Arte e edição

- `assets/headstock-600.webp` e `headstock-960.webp`: nova arte original das
  tarraxas, gerada com a ferramenta integrada do Codex. Prompt e processo em
  `assets/HERO_GENERATION.md`. Transparência nativa, WebP de qualidade 82.
- As duas ilustrações menores reaproveitam as imagens aprovadas do app.
  Favicon também deriva da logo aprovada. Licença CC0 em `assets/LICENSE.txt`.
- A marca do site é SVG inline + tipografia de sistema; não muda o ícone do app.
- Edite os textos nos HTML e as cores/medidas em `styles.css`.
- Para lançar, troque “Em breve no Android” pelo link real da Play Store.

A política descreve o app atual: áudio em memória, sem upload, preferências
locais e sem permissão INTERNET no release. O backup do Android pode incluir
preferências; o site pode gerar logs técnicos no provedor de hospedagem.
