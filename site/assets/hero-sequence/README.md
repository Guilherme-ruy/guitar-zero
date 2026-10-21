# Sequência da hero

Sequência revisada e aprovada pelo proprietário para integração ao site em
20 de outubro de 2026. O site permanece em desenvolvimento e não publicado.

Derivada de `Guitar_Zero_headstock_rotation_1080p.mp4`, gerado no Google Flow
com Veo 3.1 Quality, usando as referências frontal e de costas do Guitar Zero.
O arquivo de 1920 × 1080 tem 8 segundos, 24 fps e 192 quadros. Mostra uma
meia-volta de 180°, da frente para as costas; não é um ciclo de 360°.
O MP4 original permanece local, ignorado pelo Git. O áudio não entra no site.
O SHA-256 da fonte está no manifest, sem caminhos pessoais.

Conversão com FFmpeg/libwebp: recorte de 1,00 s até o fim em 8,00 s, retirando
a pausa frontal inicial; 70 frames a 10 fps, redimensionados com Lanczos.
A proporção 16:9 e o enquadramento do vídeo são preservados. O processamento
com `site/tools/prepare_hero_alpha.py` acrescenta transparência sem perdas,
preservando byte a byte o bloco VP8/RGB dos WebP da conversão. O avanço e o
retorno são controlados pela rolagem, sem reprodução do MP4 nem recorte de pixels
no navegador.

- `960/`: WebP qualidade 88 com alpha, 960 × 540, total 1.948.004 bytes.
- `1440/`: WebP qualidade 88 com alpha, 1440 × 810, total 3.591.872 bytes.
- `1920/`: WebP qualidade 88 com alpha, 1920 × 1080, total 5.315.232 bytes.
- `poster.webp`: cópia do primeiro frame de 1440 px, 73.140 bytes, para
  carregamento inicial e ausência de JavaScript, sem troca de pose ao iniciar.
- `manifest.json`: versão 4, medidas, dados da conversão e do alpha;
  somente documentação.

Cada variante mantém 70 frames. O runtime escolhe a menor resolução suficiente
para a largura exibida multiplicada pela densidade da tela (limitada a 2),
até o limite de 1920 px da fonte. Depois do primeiro quadro, carrega os 70 Blobs
comprimidos da variante escolhida, com três requisições simultâneas e prioridade
para o destino atual e vizinhos. A decodificação é independente da rede, com
até três imagens em 960/1440 e duas em 1920. O canvas pode exibir o vizinho pronto
mais próximo enquanto o destino exato carrega.

O cache tem orçamento de 32 MiB para bitmaps: oito no celular ou doze em telas
maiores na variante 960; sete em 1440 e quatro em 1920. Os Blobs comprimidos,
o canvas e as decodificações em andamento usam memória adicional. As URLs da
sequência e do pôster usam `v=4` para não reutilizar os assets anteriores no cache
HTTP. A hero com rolagem livre mantém `motion.js?v=8` e usa `styles.css?v=13`;
as regras e a animação da hero estão preservadas. O instrumento
permanece opaco à frente do medidor, com alpha já preparado nos arquivos.

## Reproduzir a conversão

Com Python e os pacotes Pillow e NumPy instalados, além de FFmpeg/ffprobe no
PATH, execute na raiz do repositório:

```sh
python site/tools/convert_hero_video.py --source Guitar_Zero_headstock_rotation_1080p.mp4 --output .local/flow-site-v4
```

O destino deve ser uma pasta nova. Confira o manifest e os 70 arquivos de
cada variante antes de copiar `960/`, `1440/`, `1920/`, `poster.webp` e `manifest.json`
para esta pasta. A ferramenta não sobrescreve um destino existente.

As seis tarraxas mantêm a fileira e a ordem durante o giro. A fonte gerada
ainda apresenta oscilação de reflexos cromados perto de 6 s e pequenas
ondulações nas cordas em perfil; esses detalhes não foram redesenhados.

O alpha pré-calculado torna transparente somente o branco conectado às bordas,
com quatro vizinhos e critério de canal mínimo 240 e diferença máxima entre
canais 14. A ferramenta acrescenta um bloco ALPH sem perdas, sem recodificar
o VP8/RGB original; madeira e reflexos internos continuam opacos. O pôster tem
o mesmo alpha e a composição permanece normal, sem misturar o medidor com a
guitarra. Uma máscara CSS suaviza o corte esquerdo do braço, fora do medidor. Alguns
enquadramentos do vídeo já cortam o instrumento; nenhuma parte ausente foi
reconstruída na conversão.

## Direitos e reutilização

Estes derivados não recebem a MIT do código nem a CC0 das outras ilustrações.
O proprietário autorizou a conversão e o uso no próprio site Guitar Zero.
Este documento não concede uma licença geral de reutilização em outros
projetos. Para usos que dependam de autorização, contate o responsável pelo
repositório. Permanecem os direitos e condições aplicáveis ao vídeo de origem,
os termos do serviço de geração e os direitos que terceiros possam deter.
Nenhuma exclusividade sobre a saída gerada por IA é garantida.
