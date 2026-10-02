# Site estático do Guitar Zero

Somente duas páginas: `index.html` (três seções) e `privacidade.html`.
HTML e CSS puros, imagens locais WebP/PNG, sem JavaScript, PHP, framework,
fontes externas, cookies, analytics ou chamadas a CDNs. Não exige build.

## Hospedagem

Envie **o conteúdo desta pasta** ao diretório público de qualquer hospedagem
estática e ative HTTPS. Os caminhos são relativos: funciona na raiz de um
domínio ou em uma subpasta, inclusive em hosts que não suportam reescrita de
URLs. A política pode ser cadastrada no Play Console usando a URL pública
final terminada em `/privacidade.html`, sem login ou bloqueio por região.
Não envie arquivos do app, keystores ou secrets para a hospedagem.

Para visualizar localmente, `python -m http.server 8080 --directory site`
a partir da raiz do repositório. Acesse `http://localhost:8080`.

## Conteúdo antes do lançamento

- A disponibilidade atual é **Android · em breve**. Depois da publicação,
  substitua esse texto por um link real da Play Store. Não há link de download
  ou depoimentos fictícios.
- E-mail público: `oruycontato@gmail.com`. Responsável identificado na política:
  Guilherme Ruy. Confira o nome com o cadastro e a ficha do Play Console.
- Antes de publicar a política, confira o provedor escolhido e suas práticas
  de logs; ajuste a seção de hospedagem caso use analytics, cookies ou CDNs.
  O texto distingue dados do app, mensagens voluntárias e logs da hospedagem.
- Política baseada na implementação atual: `record` em stream PCM/memória,
  sem upload de áudio; `shared_preferences` local; sem INTERNET no release.
  Preferências podem participar do backup do próprio Android.
- O app também precisa oferecer acesso à política. Nenhum Dart foi alterado
  nesta entrega; integração do link/texto no app é uma etapa antes da revisão.

## Imagens e peso

Imagens de guitarra/violão aprovadas, reaproveitadas de `assets/instruments/`
e recomprimidas em WebP (qualidade 84). Favicon derivado da logo aprovada.
Arte não foi redesenhada; Pillow fez apenas conversão/redimensionamento.
`srcset` adapta a imagem principal; imagens secundárias usam lazy loading.
Todo o pacote visual fica abaixo de 200 KiB. Licença das imagens em
`assets/LICENSE.txt` (CC0-1.0). As referências visuais enviadas pelo proprietário
serviram apenas de inspiração; não são incluídas no site.

Referência de privacidade: [política do Google Play](https://support.google.com/googleplay/android-developer/answer/10144311?hl=pt-BR).
