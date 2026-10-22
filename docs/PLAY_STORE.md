# Publicação no Google Play

## O que está preparado

O CI comum continua entregando `guitar-zero-apk` para testes em aparelho.
O workflow manual **Play Store AAB** gera um AAB de release assinado com sua
chave de upload, para envio manual ao Play Console. Não publica automaticamente.
Somente a `main` pode executar o job de assinatura. O workflow já está
disponível na aba Actions.

O pacote permanece `io.github.guilhermeruy.guitar_zero`. Confirmar esse nome
antes do primeiro envio: depois, ele identifica permanentemente o app.
Compile/target SDK usam pelo menos API 36. Flutter continua em 3.47.5.

## Chave e secrets

Use uma chave de upload dedicada ao Guitar Zero. Uma chave de debug não serve
para publicação. Não compartilhe senhas pelo chat e não commite a chave.
Faça backup seguro do keystore e de suas senhas fora do repositório.

Se ainda não houver chave, use o `keytool` de um JDK, com senha solicitada
interativamente (fora dos argumentos do comando):

```powershell
keytool -genkeypair -v -keystore guitar-zero-upload.jks -storetype JKS -keyalg RSA -keysize 2048 -validity 10000 -alias upload
```

O comando não precisa de Flutter. Guarde o arquivo em um diretório privado,
não na pasta do site. Se escolher senhas diferentes para arquivo e chave,
cadastre os valores correspondentes abaixo.

Em **Settings → Secrets and variables → Actions → New repository secret**,
cadastre:

| Secret | Conteúdo |
| --- | --- |
| `ANDROID_KEYSTORE_BASE64` | Keystore completo convertido em Base64, em uma linha |
| `ANDROID_STORE_PASSWORD` | Senha do keystore |
| `ANDROID_KEY_ALIAS` | Alias da chave, por exemplo `upload` |
| `ANDROID_KEY_PASSWORD` | Senha da chave/alias |

Para copiar a codificação diretamente ao clipboard no PowerShell:

```powershell
[Convert]::ToBase64String([IO.File]::ReadAllBytes((Resolve-Path '.\guitar-zero-upload.jks').Path)) | Set-Clipboard
```

Cole no campo do secret e limpe o clipboard depois. Base64 não é criptografia;
o armazenamento deve ser o secret do GitHub, não um arquivo do repo.
O workflow valida campos e Base64 antes de preparar o ambiente, restaura o
arquivo em `RUNNER_TEMP`, usa senhas apenas como variáveis de ambiente e
remove o arquivo no final. Secrets nunca entram em artifacts.

## Gerar e baixar

1. Abra **Actions → Play Store AAB → Run workflow** e selecione `main`.
2. Informe `build_name`, por exemplo `1.0.0`, e `build_number`, por exemplo `1`.
   Cada novo envio ao Play Console precisa de um número maior que todos os
   envios anteriores daquele app, inclusive testes. O workflow valida o
   formato/faixa; não consulta a maior versão já enviada à loja.
3. Espere o job terminar. Ele roda formatação, análise, testes e geração do AAB.
4. Baixe `guitar-zero-play-VERSAO-NUMERO`; contém `app-release.aab` e SHA-256.
5. No Play Console, configure Play App Signing e envie o AAB primeiro ao
   teste interno. Depois siga o teste fechado/produção exigido pela conta.

O Gradle bloqueia `bundleRelease` sem assinatura de upload, mesmo fora do
workflow. O fallback de debug existe somente para manter o APK de teste.
Sem os quatro secrets, o workflow informa quais configurações estão faltando.

## Verificações de publicação

- Identidade, versionCode, target API ≥ 36 e build não debuggable.
- Permissão RECORD_AUDIO presente e INTERNET ausente no manifesto final.
- AAB válido pelo bundletool 1.18.3, baixado da distribuição oficial e com
  SHA-256 fixado no workflow.
- Assinatura JAR válida, certificado igual ao keystore de upload e sem
  identidade `Android Debug`.
- Alinhamento LOAD de 16 KB nas bibliotecas ELF64. RELRO precisa terminar
  alinhado ou ocupar seu próprio LOAD sem sobrepor outros dados graváveis ao
  arredondar a proteção para 16 KB. A configuração ZIP também deve solicitar
  alinhamento de 16 KB quando as bibliotecas nativas são descomprimidas.
  Essas checagens não substituem teste em dispositivo/emulador de 16 KB nem
  a validação final do Play Console.

## Ainda necessário antes de publicar

- Conferir os quatro secrets de assinatura e manter um backup privado da
  chave de upload e de suas senhas. O primeiro build AAB real depende deles.
- Site e política hospedados com HTTPS em `https://guitarzero.com.br` e
  `https://guitarzero.com.br/privacidade.html`.
- Conferir no aparelho o link **Política de privacidade**, no painel de ajustes.
  Ele abre o navegador externo; o afinador não carrega conteúdo remoto nem
  precisa de permissão `INTERNET` para isso. Ao sair para o navegador, a escuta
  segue o tratamento existente de pausa/retomada do app. Se o sistema não
  conseguir abrir o navegador, o usuário pode copiar o link.
- Ficha da loja: descrições, ícone, screenshots reais, feature graphic,
  classificação indicativa, público-alvo e declarações de conteúdo.
- Segurança dos dados: confirmar que a versão/SDKs enviados continuam sem
  coleta ou compartilhamento; processamento só no dispositivo não é coleta
  no formulário. Preferências locais e microfone são explicados na política.
- Confirmar cadastro/verificação da conta e exigência de teste fechado.
- Validar microfone, pausa/retomada, telas pequenas, afinação real e instalação
  do pacote distribuído pela Play Store em teste interno.

Documentação oficial: [Flutter Android](https://docs.flutter.dev/deployment/android),
[Play App Signing](https://developer.android.com/studio/publish/app-signing),
[target API](https://support.google.com/googleplay/android-developer/answer/11926878),
[16 KB](https://developer.android.com/guide/practices/page-sizes),
[secrets do GitHub](https://docs.github.com/en/actions/how-tos/write-workflows/choose-what-workflows-do/use-secrets),
[privacidade](https://support.google.com/googleplay/android-developer/answer/10144311),
[Segurança dos dados](https://support.google.com/googleplay/android-developer/answer/10787469).
