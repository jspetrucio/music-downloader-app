
---

# 🎵 **YouTube Music Downloader - Executive Summary**

## **Visão Geral**

Aplicativo iOS pessoal que permite baixar vídeos do YouTube, converter automaticamente em áudio de alta qualidade (MP3 ou M4A), e gerenciar uma biblioteca de músicas no dispositivo com interface inspirada no Spotify.

## ⚠️ **Aviso Legal**

**Este aplicativo é para uso pessoal e educacional exclusivamente.**

O usuário é totalmente responsável por:
- ✅ Garantir que possui direitos legais para baixar o conteúdo
- ✅ Cumprir os Termos de Serviço do YouTube
- ✅ Respeitar as leis de copyright de sua jurisdição
- ✅ NÃO redistribuir ou comercializar arquivos baixados

**IMPORTANTE**:
- Este app **NÃO será publicado na App Store**
- Instalação manual via Xcode (sideload)
- YouTube Terms of Service proíbem download de conteúdo
- Use apenas para backup de conteúdo que você já possui legalmente

---

## **Estrutura de Navegação**

### **3 Tabs Principais (Bottom Navigation)**

**Tab 1: Download** 🎵

- Tela principal para adicionar novas músicas

**Tab 2: Library** 📚

- Visualização de todas as músicas baixadas

**Tab 3: Playlists** 🎼

- Gerenciamento de playlists customizadas

---

## **Funcionalidades Detalhadas**

### **TAB 1: DOWNLOAD**

#### Interface:

- Campo de texto para colar URL do YouTube
- Botão "Download MP3" destacado
- Barra de progresso durante conversão/download
- Feedback visual de sucesso ou erro
- Lista de últimos downloads (histórico recente)

#### Comportamento:

1. Usuário cola URL do YouTube (vídeo ou playlist)
2. Sistema **valida e busca metadados** (título, duração, tamanho estimado)
3. Se for **playlist**: mostra seleção de tracks para escolher quais baixar
4. Se for **vídeo único**: mostra preview card com detalhes
5. **Escolha de formato**: MP3 ou M4A (usuário decide)
6. **Verificação de duplicata**: se URL já foi baixada, pergunta se quer baixar novamente
7. **Verificação de espaço**: confere se há espaço suficiente no dispositivo
8. Clica em "Baixar"
9. Sistema mostra progresso em tempo real + tamanho do arquivo
10. Música é salva localmente com:
    - Áudio em MP3 (320kbps) ou M4A (256kbps) - formato escolhido pelo usuário
    - Thumbnail do vídeo do YouTube (salva localmente em cache)
    - Nome original do vídeo (NÃO editável - mantém original)
    - Artista (extraído do YouTube - NÃO editável)
    - Duração
    - Tamanho do arquivo
    - Data de adição

#### Recursos Extras:

- **Download de playlists**: opção de selecionar tracks individuais de uma playlist
- **Histórico de downloads**: completo (acessível via botão)
- **Limite diário**: máximo 20 downloads/dia
  - Ao atingir 20, mostra warning: "Você atingiu o limite recomendado (20/dia). Continuar pode violar ToS do YouTube. Deseja prosseguir?"
  - Usuário pode aceitar riscos e continuar
- **Escolha de formato**: MP3 (universal) ou M4A (melhor qualidade/tamanho)
- **Indicador de tamanho**: sempre mostra tamanho do arquivo durante download

---

### **TAB 2: LIBRARY**

#### Interface (inspirada no Spotify da imagem):

- Barra de busca no topo
- Botão de alternância: **Lista** vs **Grid** (cards grandes)
- Menu de ordenação (ícone de filtro)
- Cards/itens de música com:
    - Thumbnail do YouTube
    - Nome da música (editável inline)
    - Duração
    - Ícone de favorito (estrela)
    - Menu de 3 pontos (opções)

#### Visualização Grid (padrão - como Spotify):

- 2 cards por linha
- Thumbnail grande (quadrada)
- Nome abaixo da thumbnail
- Visual espaçoso e limpo
- Scroll vertical infinito

#### Visualização Lista:

- 1 item por linha
- Thumbnail menor à esquerda
- Nome e duração à direita
- Mais compacta (mais músicas visíveis)

#### Ordenação (via menu):

1. **Alfabética** (A-Z)
2. **Data de adição** (mais recente primeiro)
3. **Custom (manual):**
    - Usuário toca em músicas para numerar ordem (1, 2, 3...)
    - Sistema mantém músicas numeradas no topo
    - Músicas não numeradas ficam por data abaixo

#### Ações por Música:

- **Tap simples** = Toca a música
- **Long press** = Menu de opções:
    - ⭐ Marcar/Desmarcar Favorito
    - 📤 Compartilhar (AirDrop, WhatsApp, etc)
    - 🗑️ Deletar (remove da Library E do dispositivo)
    - ℹ️ Ver informações (tamanho, formato, data de download)
- **Swipe to delete** = Deletar rapidamente

**NOTA**: Título e artista **NÃO são editáveis** - mantém metadados originais do YouTube

#### Funcionalidades Adicionais:

- **Busca**: barra de busca no topo, filtra por título/artista em tempo real
- **Filtros**:
  - Por favoritos
  - Por formato (MP3, M4A)
  - Por data de adição
  - Por mais tocadas
- **Empty state**: mensagem bonita quando não há músicas
- **Shuffle All**: botão para tocar todas em ordem aleatória
- **Play All**: botão para tocar todas em sequência

---

### **GERENCIAMENTO DE ARMAZENAMENTO** (NOVO - P0)

#### Dashboard de Espaço:

Barra fixa no topo da Library mostrando:
- **Espaço usado pela biblioteca**: ex: "Biblioteca: 2.3 GB (487 músicas)"
- **Espaço disponível no iPhone**: ex: "Disponível: 12.5 GB"
- **Indicador visual**: barra de progresso colorida
  - Verde: > 5GB livre
  - Amarelo: 1-5GB livre
  - Vermelho: < 1GB livre

#### Verificações Automáticas:

1. **Antes de cada download**:
   - Verifica se há espaço suficiente para o arquivo
   - Se < 500MB livres, mostra alerta: "Espaço insuficiente. Libere XX MB para continuar."
   - Botão "Gerenciar Espaço" → leva para tela de limpeza

2. **Warnings proativos**:
   - Quando espaço < 1GB: "Seu iPhone está com pouco espaço. Considere deletar músicas antigas."
   - Quando biblioteca > 5GB: "Sua biblioteca está grande. Ative auto-limpeza nas Configurações."

#### Auto-Limpeza (Configurável):

**Settings → Armazenamento**:
- ✅ Auto-limpeza ativada
- Deletar músicas não ouvidas em: [30 / 60 / **90** / 120 dias]
- Excluir favoritas da limpeza: [ON / OFF]
- Notificar antes de deletar: [ON / OFF]

**Processo**:
- Roda automaticamente 1x por semana
- Identifica tracks não ouvidas no período configurado
- Se "Notificar" = ON: mostra lista de músicas que serão deletadas (usuário pode revisar)
- Se "Notificar" = OFF: deleta silenciosamente

#### Ferramentas de Limpeza Manual:

**Library → Menu (⋮) → Gerenciar Espaço**:

- **Músicas nunca tocadas**: lista tracks com playCount = 0, opção de deletar em lote
- **Maiores arquivos**: ordena por tamanho, permite deletar seletivamente
- **Mais antigas**: ordena por data de adição, opção de manter apenas X mais recentes
- **Liberar cache**: deleta thumbnails em cache (recuperados no próximo acesso)

---

### **TAB 3: PLAYLISTS**

#### Interface:

- Lista de playlists criadas pelo usuário
- Botão "Nova Playlist" destacado
- Cada playlist mostra:
    - Nome customizado
    - Número de músicas
    - Thumbnail (mosaico das primeiras 4 músicas ou imagem custom)

#### Funcionalidades:

- Criar playlist (nome + adicionar músicas)
- Editar playlist (adicionar/remover músicas)
- Deletar playlist
- Tocar playlist completa
- Organizar ordem das músicas dentro da playlist

---

## **PLAYER DE MÚSICA**

### **Mini Player (sempre visível)**

Barra fixa acima do Tab Bar, presente em todas as telas quando algo está tocando:

- Thumbnail pequena da música atual
- Nome da música (scroll se muito longo)
- Botão Play/Pause
- Tap na barra = expande para Player completo

### **Player Completo (tela cheia)**

Tela modal que cobre tudo quando usuário toca no Mini Player:

#### Visual:

- Thumbnail grande e centralizada (do YouTube)
- Nome da música (NÃO editável - mostra original)
- Artista (extraído do YouTube)
- Duração atual / duração total
- Scrubber (barra de progresso clicável para pular na música)
- Controles principais:
    - ⏮️ Anterior
    - ⏯️ Play/Pause (botão grande)
    - ⏭️ Próxima
    - 🔀 Shuffle
    - 🔁 Repeat (off / repeat all / repeat one)
- Volume slider
- Botão ⭐ Favoritar
- **Indicador de formato**: pequeno badge mostrando "MP3" ou "M4A"
- **Tamanho do arquivo**: ex: "3.2 MB"
- Botão de fechar (volta para tela anterior)

#### Comportamentos:

- Swipe down = fecha e volta ao Mini Player
- Scrubber permite pular para qualquer ponto da música
- **Background playback**: música continua tocando com app fechado ou tela bloqueada
- **Lock screen controls**:
  - Mostra thumbnail, título, artista
  - Controles de play/pause, anterior, próxima
  - Funciona com AirPods, fones Bluetooth, CarPlay
- **Integração nativa iOS**:
  - MPNowPlayingInfoCenter (metadados no lock screen)
  - MPRemoteCommandCenter (controles de hardware)
  - Audio Session configurada para playback

---

## **RECURSOS GERAIS DO APP**

### **Tema Visual:**

- Dark theme (fundo escuro como Spotify)
- Opção de Light theme (automático ou manual)
- Cores accent customizáveis (verde Spotify-like como padrão)
- Animações suaves e responsivas
- Ícones modernos e claros

### **Confirmações e Segurança:**

- Confirmar antes de adicionar música à Library
- Confirmar antes de deletar música (alerta: "Isso removerá permanentemente do dispositivo")
- Feedback visual para todas as ações (toasts/alertas)

### **Tratamento de Erros e Retry:**

#### Validação de URL:
- URL inválida/não-YouTube → "URL inválida. Cole um link do YouTube."
- Vídeo privado/removido → "Vídeo não está disponível."
- Vídeo com restrição de região → "Vídeo bloqueado na sua região."

#### Falhas de Download:
- **Retry automático**: 3 tentativas com backoff exponencial (2s, 4s, 8s)
- Após 3 falhas → "Download falhou. Tentar novamente?"
  - Botão "Tentar novamente"
  - Botão "Cancelar"
- **Limpeza automática**: arquivos parciais/corrompidos são deletados
- **Progresso salvo**: se interrompido, próxima tentativa resume do ponto de parada (quando possível)

#### Problemas de Rede:
- Sem internet → "Sem conexão. Verifique sua internet e tente novamente."
- Internet lenta → "Download pode demorar. Deseja continuar?"
- Backend offline/hibernando → "Ativando servidor... (pode levar 30s)"
  - Mostra indicador de loading durante cold start

#### Problemas de Armazenamento:
- Espaço insuficiente → alerta **antes** de iniciar download
- Durante download, se espaço acabar → pausa e alerta "Espaço esgotado durante download"

#### Problemas com Backend:
- Timeout (>120s) → "Download demorou muito. Tente um vídeo mais curto."
- Erro 429 (rate limit) → "Muitas requisições. Aguarde 60 segundos."
- Erro 500 (servidor) → "Erro no servidor. Tente novamente em alguns minutos."

#### Arquivo Corrompido (após download):
- Validação de integridade ao salvar
- Se corrompido → deleta automaticamente e mostra "Arquivo corrompido. Tentar baixar novamente?"

### **Performance:**

- Músicas carregam instantaneamente (armazenadas localmente)
- Thumbnails em cache
- Busca em tempo real (sem lag)
- Scroll suave mesmo com muitas músicas

---

## **FLUXO COMPLETO DO USUÁRIO**

### Cenário 1: Primeiro uso

1. Abre app → Tab Download vazio com instrução
2. Cola URL do YouTube
3. Clica "Download MP3"
4. Vê progresso da conversão
5. Recebe confirmação "Adicionar à Library?"
6. Confirma
7. Música aparece na Library (Tab 2)
8. Tap na música = começa a tocar (Mini Player aparece)

### Cenário 2: Organizar biblioteca

1. Vai para Library (Tab 2)
2. Alterna para visualização Grid (como Spotify)
3. Usa busca para encontrar música específica
4. Renomeia música (tap inline no nome)
5. Marca como favorita (long press → favoritar)
6. Cria playlist (vai para Tab 3 → Nova Playlist)
7. Adiciona músicas à playlist

### Cenário 3: Ouvir música

1. Está em qualquer tela
2. Tap em música na Library ou Playlist
3. Mini Player aparece embaixo
4. Tap no Mini Player = abre Player completo
5. Controla playback, pula músicas, ajusta volume
6. Swipe down = volta para tela anterior
7. Mini Player continua visível e funcional

---

## **PRIORIDADES DE IMPLEMENTAÇÃO (REVISADO)**

### **Fase 1: MVP Funcional (Semanas 1-4)**

**Backend (Python/FastAPI)**:
- ✅ Endpoint `/api/v1/metadata` - preview antes de baixar
- ✅ Endpoint `/api/v1/download` - streaming chunked
- ✅ Rate limiting (1 req/min)
- ✅ Retry logic com backoff exponencial
- ✅ Error handling robusto
- ✅ Keep-alive cron job (evitar cold starts)
- ✅ Suporte MP3 e M4A

**iOS (SwiftUI + SwiftData)**:
- ✅ Tab Download:
  - Preview de metadata antes de baixar
  - Seleção de formato (MP3/M4A)
  - Verificação de duplicata
  - **Verificação de espaço antes de download**
  - Progress bar com tamanho do arquivo
  - Retry automático em caso de falha
- ✅ Tab Library:
  - Visualização Grid e Lista
  - **Barra de busca no topo**
  - **Dashboard de armazenamento**
  - Ordenação (alfabética, data, mais tocadas)
  - Filtros (favoritos, formato)
- ✅ Player:
  - Mini Player (sempre visível)
  - Player completo (modal)
  - **Background playback**
  - **Lock screen controls**
  - Shuffle/Repeat básico
- ✅ Gerenciamento:
  - Deletar música (swipe ou long press)
  - Favoritar
  - **Limite de 20 downloads/dia com warning**

**Milestone**: App funcional para uso diário sem crashes

---

### **Fase 2: Polimento e UX (Semanas 5-6)**

- ✅ Tab Playlists:
  - Criar/editar/deletar playlists
  - Drag-to-reorder tracks
  - Tocar playlist completa
- ✅ Download de playlists do YouTube:
  - Seleção de tracks individuais antes de baixar
- ✅ Auto-limpeza configurável:
  - Settings para deletar tracks não ouvidas em X dias
  - Notificação antes de deletar
- ✅ Ferramentas de limpeza manual:
  - Ver maiores arquivos
  - Deletar nunca tocadas
  - Liberar cache de thumbnails
- ✅ Melhorias de UX:
  - Animações suaves
  - Empty states polidos
  - Loading states claros
  - Notificações de download completo

**Milestone**: Experiência polida e agradável

---

### **Fase 3: Features Avançadas (Semanas 7-8+)**

**P2 (Nice-to-Have)**:
- ⭐ Widget iOS (Now Playing)
- ⭐ Siri Shortcuts ("Tocar minha playlist de treino")
- ⭐ Sleep timer
- ⭐ Compartilhar música (AirDrop, export)
- ⭐ Estatísticas de escuta (mais tocadas, tempo total)
- ⭐ Histórico completo de downloads

**P3 (Futura)**:
- 🚀 Equalizer com presets
- 🚀 Lyrics sync (integração com Musixmatch API)
- 🚀 iCloud sync entre dispositivos
- 🚀 Dark/Light theme customizável
- 🚀 Importar arquivos locais (Files app)
- 🚀 Export de playlists (.m3u)

---

## **REQUISITOS NÃO-FUNCIONAIS**

- **Simplicidade:** Interface intuitiva, sem curva de aprendizado
- **Performance:** Resposta instantânea em todas as ações
- **Confiabilidade:** Downloads robustos com retry automático
- **Estética:** Visual moderno inspirado em apps premium (Spotify, Apple Music)
- **Privacidade:** Tudo local, nada na nuvem (exceto backend de conversão)

---

## **NOTAS IMPORTANTES**

1. Este é um app **pessoal/educacional**, não será publicado na App Store
2. Instalação manual via Xcode (sideload)
3. Backend separado fará a conversão YouTube → MP3
4. Foco em **aprendizado** e **usabilidade**, não em features complexas inicialmente

---

**Fim do Executive Summary** ✅

---