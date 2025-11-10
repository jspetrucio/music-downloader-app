# Music Downloader App - Interactive Mockups

## 🎨 Mockups Interativos HTML/CSS

Este diretório contém mockups interativos em HTML/CSS das principais telas do Music Downloader App, baseados nas especificações completas do design.

## 📱 Telas Disponíveis

1. **[index.html](index.html)** - Página inicial com navegação
2. **[download.html](download.html)** - Tab de Download com URL input
3. **[library.html](library.html)** - Tab da Biblioteca (Grid + List view)
4. **[playlists.html](playlists.html)** - Tab de Playlists
5. **[player.html](player.html)** - Player completo (Full screen)

## 🚀 Como Usar

### Método 1: Navegador Desktop
```bash
open index.html
```
Ou simplesmente clique duas vezes no arquivo `index.html`

### Método 2: iPhone/Android (Tamanho Real)
1. Abra o `index.html` no navegador do seu celular
2. Navegue entre as telas
3. Veja o design em tamanho real

### Método 3: Servidor Local (Recomendado para desenvolvimento)
```bash
cd /Users/josdasil/Documents/App-music/project-documentation/design/mockups/
python3 -m http.server 8000
```
Depois abra: http://localhost:8000

## 🎯 Recursos Interativos

### Download Tab
- ✅ Cole URL (clique no botão 📋)
- ✅ Veja card de metadata aparecer
- ✅ Inicie download simulado
- ✅ Veja barra de progresso animada
- ✅ Storage dashboard sempre visível

### Library Tab
- ✅ Toggle entre Grid e List view
- ✅ Busca de músicas (visual apenas)
- ✅ Filtros (Todas, MP3, M4A, Favoritas)
- ✅ Cards clicáveis
- ✅ Estatísticas de biblioteca

### Playlists Tab
- ✅ Cards com gradientes coloridos
- ✅ Thumbnails 2x2
- ✅ Contador de músicas
- ✅ Botão de criar playlist

### Player
- ✅ Album art com animação de pulse
- ✅ Seek bar visual
- ✅ Controles de playback (shuffle, play/pause, repeat)
- ✅ Controle de volume
- ✅ Botão de fila
- ✅ Gradient background baseado na capa

## 🎨 Design System

### Cores
- **Background**: #000000 (True black OLED)
- **Secondary**: #1C1C1E
- **Tertiary**: #2C2C2E
- **Accent Blue**: #0A84FF
- **Success Green**: #32D74B

### Tipografia
- **Font**: SF Pro Display (iOS native)
- **Large Title**: 34px Bold
- **Title 1**: 28px Bold
- **Title 2**: 22px Bold
- **Headline**: 17px Semibold
- **Body**: 17px Regular

### Espaçamento
- **Grid Base**: 4pt (8px, 12px, 16px, 24px)
- **Border Radius**: Small (8px), Medium (12px), Large (16px)

## 📐 Dimensões do iPhone

- **Largura**: 428px (iPhone Pro Max)
- **Altura**: 926px
- **Status Bar**: 48px
- **Tab Bar**: 68px
- **Mini Player**: 60px
- **Cantos Arredondados**: 48px

## 🔧 Arquivos

```
mockups/
├── index.html          # Página inicial com cards de navegação
├── download.html       # Tela de Download
├── library.html        # Tela da Biblioteca
├── playlists.html      # Tela de Playlists
├── player.html         # Player completo
├── styles.css          # Estilos compartilhados (iPhone frame, tab bar, mini player)
└── README.md           # Este arquivo
```

## ✨ Recursos Visuais

- **Dark Mode**: OLED-friendly true black
- **Animações**: Spring physics, fade-in, slide-up
- **Gradientes**: 6 variações coloridas para playlists e album art
- **Shadows**: Sutis para elevação de cards
- **Transições**: Suaves e naturais (200-400ms)
- **Responsivo**: Adapta para diferentes tamanhos de tela

## 🎭 Estados Implementados

### Download Tab
- [x] Empty state (sem URL)
- [x] Loading metadata
- [x] Metadata loaded (ready to download)
- [x] Download in progress (com barra)
- [x] Download complete (toast animado)

### Library Tab
- [x] Grid view (2 colunas)
- [x] List view (compact rows)
- [x] Search bar
- [x] Filter pills (4 filtros)
- [x] View toggle (grid/list)

### Player
- [x] Large album art
- [x] Song info (title + artist)
- [x] Seek bar com thumb
- [x] Playback controls (5 botões)
- [x] Volume slider
- [x] Queue button

## 🚧 Limitações

Estes mockups são **protótipos visuais**, não o app final:

- ❌ Não conectam ao backend real
- ❌ Não reproduzem áudio de verdade
- ❌ Não salvam dados
- ❌ Funcionalidade de busca é visual apenas
- ❌ Swipe gestures não implementados

**Propósito**: Visualizar o design, testar fluxos, e servir de referência para o frontend engineer.

## 📱 Testando em Dispositivo Real

### iPhone/Android:
1. Coloque os arquivos em um servidor (GitHub Pages, Netlify, ou local)
2. Abra no navegador móvel
3. Adicione à Home Screen para experiência fullscreen
4. Teste gestos e interações

### Adicionando à Home Screen (iOS):
1. Abra `index.html` no Safari
2. Toque no botão Compartilhar
3. "Adicionar à Tela de Início"
4. Agora você tem um "app" na Home Screen!

## 🎯 Próximos Passos

Após revisar os mockups:

1. ✅ Validar design com stakeholders
2. ✅ Aprovar cores e tipografia
3. ✅ Confirmar fluxos de usuário
4. ⏳ Iniciar implementação SwiftUI (frontend-engineer)
5. ⏳ Implementar backend API (backend-engineer)

## 📞 Feedback

Para sugestões de design ou mudanças:
1. Abra os mockups
2. Teste todas as interações
3. Documente feedback específico por tela
4. Compartilhe com o designer

---

**Criado por**: Claude UX/UI Designer
**Data**: 2025-11-08
**Versão**: 1.0
**Status**: ✅ Pronto para revisão
