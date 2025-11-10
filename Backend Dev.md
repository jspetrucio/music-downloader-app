
---

# 🎵 **YouTube Music Downloader - Backend Requirements**

## **Arquitetura Geral**

Este projeto consiste em **duas partes independentes** que se comunicam via API REST:

1. **Frontend**: Aplicativo iOS nativo (SwiftUI + SwiftData)
2. **Backend**: API Python para conversão YouTube → Áudio (MP3 ou M4A)

### **Princípios Arquiteturais**

- **Backend Stateless**: não armazena arquivos permanentemente, apenas processa
- **iOS Storage-First**: todo armazenamento permanente acontece no dispositivo
- **Streaming Chunked**: arquivos grandes são transmitidos em chunks (evita timeout)
- **Idempotência**: mesma requisição pode ser repetida sem efeitos colaterais
- **Graceful Degradation**: falhas parciais não derrubam o sistema

---

## **BACKEND - Especificações Técnicas**

### **Objetivo:**

Criar uma API REST simples que recebe URLs do YouTube, converte vídeos em MP3 de alta qualidade, e retorna o arquivo de áudio junto com metadados.

### **Stack Tecnológica:**

- **Framework**: FastAPI (Python)
- **Download/Conversão**: yt-dlp
- **Conversão de Audio**: ffmpeg (se necessário)
- **Deploy Final**: Render.com (free tier)
- **Teste Local**: Rodar no Mac durante desenvolvimento

### **Endpoints da API (v1):**

#### **BASE URL**: `https://[PROJECT-NAME].onrender.com/api/v1`

---

#### **1. POST /api/v1/metadata**

**Objetivo**: Buscar metadados do vídeo/playlist **antes** de baixar (preview).

**Request:**

```json
POST /api/v1/metadata
Content-Type: application/json

{
  "url": "https://www.youtube.com/watch?v=VIDEO_ID"
}
```

**Response (Success - Vídeo Único):**

```json
HTTP 200 OK
Content-Type: application/json

{
  "type": "video",
  "metadata": {
    "title": "Nome Original do Vídeo",
    "artist": "Nome do Canal/Artista",
    "duration": 245,
    "thumbnailURL": "https://i.ytimg.com/vi/VIDEO_ID/maxresdefault.jpg",
    "videoID": "VIDEO_ID",
    "estimatedSize": {
      "mp3": 3932160,
      "m4a": 2621440
    }
  }
}
```

**Response (Success - Playlist):**

```json
HTTP 200 OK
Content-Type: application/json

{
  "type": "playlist",
  "playlistTitle": "Minha Playlist Favorita",
  "videos": [
    {
      "url": "https://youtube.com/watch?v=ABC",
      "title": "Música 1",
      "artist": "Artista 1",
      "duration": 180,
      "thumbnailURL": "...",
      "estimatedSize": { "mp3": 2621440, "m4a": 1835008 }
    },
    {
      "url": "https://youtube.com/watch?v=XYZ",
      "title": "Música 2",
      "artist": "Artista 2",
      "duration": 240,
      "thumbnailURL": "...",
      "estimatedSize": { "mp3": 3145728, "m4a": 2097152 }
    }
  ]
}
```

**Response (Error):**

```json
HTTP 400/404/500
Content-Type: application/json

{
  "error": {
    "code": "INVALID_URL",
    "message": "URL inválida ou não é do YouTube",
    "details": ["Domínios aceitos: youtube.com, youtu.be, music.youtube.com"]
  }
}
```

**Error Codes**:
- `INVALID_URL`: URL não é do YouTube
- `VIDEO_UNAVAILABLE`: Vídeo privado/removido
- `GEO_RESTRICTED`: Bloqueado por região
- `EXTRACTION_FAILED`: Erro ao extrair metadados

---

#### **2. POST /api/v1/download**

**Objetivo**: Baixar e converter vídeo para áudio (streaming chunked).

**Request:**

```json
POST /api/v1/download
Content-Type: application/json

{
  "url": "https://www.youtube.com/watch?v=VIDEO_ID",
  "format": "m4a",
  "quality": "high"
}
```

**Parâmetros**:
- `url` (required): URL do YouTube
- `format` (optional): "mp3" ou "m4a" (default: "m4a")
- `quality` (optional): "high", "medium", "low" (default: "high")

**Response (Success - Streaming):**

```http
HTTP 200 OK
Content-Type: audio/m4a
Transfer-Encoding: chunked
Content-Disposition: attachment; filename="song.m4a"
X-Song-Title: Nome Original do Vídeo
X-Song-Artist: Nome do Canal
X-Song-Duration: 245
X-Song-VideoID: VIDEO_ID

[Binary audio data streamed in chunks]
```

**Response (Error):**

```json
HTTP 400/429/500/504
Content-Type: application/json

{
  "error": {
    "code": "DOWNLOAD_FAILED",
    "message": "Falha ao baixar vídeo do YouTube",
    "details": ["YouTube retornou 403 Forbidden"],
    "retryAfter": 60
  }
}
```

**Error Codes**:
- `INVALID_FORMAT`: Formato inválido (aceita mp3, m4a)
- `DOWNLOAD_FAILED`: Falha ao baixar do YouTube
- `CONVERSION_FAILED`: Falha na conversão ffmpeg
- `RATE_LIMITED`: Excedeu limite de requisições (429)
- `TIMEOUT`: Processamento excedeu 120s (504)

---

#### **3. GET /health**

**Objetivo**: Health check para verificar se backend está ativo e funcional.

**Request:**

```http
GET /health
```

**Response:**

```json
HTTP 200 OK
Content-Type: application/json

{
  "status": "healthy",
  "timestamp": "2025-01-15T10:30:00Z",
  "version": "1.0.0",
  "dependencies": {
    "yt-dlp": "2024.12.13",
    "ffmpeg": "6.1.1"
  },
  "metrics": {
    "uptimeSeconds": 3600,
    "requestsToday": 42
  }
}
```

**Response (Unhealthy):**

```json
HTTP 503 Service Unavailable
Content-Type: application/json

{
  "status": "unhealthy",
  "timestamp": "2025-01-15T10:30:00Z",
  "dependencies": {
    "yt-dlp": "NOT_INSTALLED",
    "ffmpeg": "6.1.1"
  }
}
```

---

## **Requisitos Funcionais do Backend**

### **Conversão de Vídeo:**

1. Aceitar URLs do YouTube (formatos: youtube.com/watch?v=_, youtu.be/_, m.youtube.com/*, music.youtube.com/*, playlists)
2. Baixar apenas o áudio (não o vídeo completo - economiza banda/tempo)
3. **Suporte a múltiplos formatos**:
   - **MP3**: 320kbps (universal, maior compatibilidade)
   - **M4A**: 256kbps AAC (melhor qualidade/tamanho, recomendado para iOS)
4. Extrair metadados: título original, artista/canal, duração, thumbnail, videoID
5. **Streaming chunked**: transmitir arquivo em chunks de 8KB enquanto converte (evita timeout)

### **Gestão de Arquivos:**

1. **Backend stateless**: NÃO armazena arquivos permanentemente
2. Processamento em memória/stream direto para o cliente
3. Arquivos temporários (se necessário) deletados imediatamente após envio
4. **Sem limite de tamanho de arquivo** (usuário decide, mas mostramos tamanho estimado antes)
5. Limpeza automática de processos órfãos (se houver)

### **Validações:**

1. Verificar se URL é válida e acessível
2. Detectar vídeos privados/removidos/restritos por região
3. Timeout de 60 segundos para download/conversão
4. Retry automático (1x) se falhar por erro temporário

### **Performance:**

1. Processamento assíncrono (não bloquear requisição)
2. Limitar conversões simultâneas (ex: máximo 3 ao mesmo tempo)
3. Cache de thumbnails (opcional, mas recomendado)

### **Segurança:**

1. **Rate limiting**:
   - `/metadata`: 10 req/minuto por IP
   - `/download`: 1 req/minuto por IP
   - `/health`: sem limite
2. **Validação de URL**: whitelist de domínios (youtube.com, youtu.be, music.youtube.com)
3. **Sanitização de filename**: prevenir path traversal, command injection
4. **CORS configurado**: aceitar requisições de qualquer origem (app pessoal)
5. **Input validation**: Pydantic models para validar todos os inputs
6. **Error sanitization**: nunca expor stack traces completas ao cliente

---

## **Ambiente de Deployment**

### **Desenvolvimento Local (Mac):**

- Rodar servidor em `localhost:8000`
- Ambiente virtual Python (venv)
- Logs verbosos para debugging
- Hot reload habilitado

### **Produção (Render.com):**

- Deploy via GitHub (CI/CD automático)
- Variáveis de ambiente para configuração
- HTTPS automático (Render fornece)
- URL final: `https://[PROJECT-NAME].onrender.com`

**Render.com Requirements:**

- Runtime: Python 3.11+
- Build Command: `pip install -r requirements.txt && pip install yt-dlp --upgrade`
- Start Command: `uvicorn main:app --host 0.0.0.0 --port $PORT`
- Instâncias: Free tier (1 instância, 512MB RAM, **sleep após 15min inatividade**)

**⚠️ Problema de Cold Start (Render Free Tier)**:
- Após 15 min de inatividade, servidor hiberna
- Primeira requisição após hibernação demora **15-30 segundos**
- **Solução**: Keep-alive via cron job externo

**Estratégia de Keep-Alive**:

1. **Serviço de Cron Gratuito**: cron-job.org ou GitHub Actions
2. **Frequência**: Ping a cada 10 minutos
3. **Endpoint**: `GET /health` (leve, não conta como conversão)
4. **Configuração**:

```yaml
# GitHub Actions (.github/workflows/keep-alive.yml)
name: Keep Backend Alive
on:
  schedule:
    - cron: '*/10 * * * *'  # A cada 10 minutos
jobs:
  ping:
    runs-on: ubuntu-latest
    steps:
      - name: Ping health endpoint
        run: curl https://[PROJECT-NAME].onrender.com/health
```

**Consumo de horas**:
- Keep-alive: 6 pings/hora × 24h = 144 pings/dia
- Total mensal: ~4320 pings = ~72h de uptime/mês
- **Sobram**: 750h - 72h = 678h para uso real (mais que suficiente)

---

## **Dependências Python (requirements.txt):**

```txt
fastapi==0.109.0
uvicorn[standard]==0.27.0
yt-dlp==2024.12.13
pydantic==2.5.3
slowapi==0.1.9
python-json-logger==2.0.7
```

**Dependências do Sistema:**

- ffmpeg (já disponível no Render.com)
- yt-dlp (instalado via pip, atualizado no build)

---

## **Fluxo de Comunicação App ↔ Backend**

### **Cenário 1: Download Bem-Sucedido (Novo Fluxo)**

```
1. App iOS → POST /api/v1/metadata com URL
2. Backend → Valida e extrai metadados
3. Backend → Retorna: título, artista, duração, tamanho estimado (MP3 e M4A)
4. App iOS → Mostra preview card ao usuário
5. Usuário escolhe formato (MP3 ou M4A) e confirma
6. App iOS verifica espaço disponível
7. App iOS → POST /api/v1/download com URL + formato escolhido
8. Backend:
   - Baixa áudio do YouTube
   - Converte para formato escolhido
   - Stream chunks em tempo real (8KB por vez)
9. App iOS → Recebe chunks progressivamente, salva em temp file
10. App iOS → Move temp file para Documents/songs/
11. App iOS → Cria registro no SwiftData
12. App iOS → Mostra notificação "Download completo"
```

### **Cenário 2: Playlist URL**

```
1. App iOS → POST /api/v1/metadata com URL de playlist
2. Backend → Detecta que é playlist, extrai todos os vídeos
3. Backend → Retorna lista de vídeos com metadados individuais
4. App iOS → Mostra lista selecionável (checkboxes)
5. Usuário seleciona quais vídeos baixar
6. App iOS → Itera sobre selecionados, chamando /download para cada
7. Mostra progresso total (ex: "Baixando 3 de 10...")
```

### **Cenário 3: Duplicata Detectada**

```
1. App iOS → POST /api/v1/metadata com URL
2. App iOS → Verifica SwiftData se URL já existe
3. App iOS → Mostra alerta: "Você já baixou esta música. Baixar novamente?"
4. Se usuário confirma → prossegue com download normal
5. Se usuário cancela → volta para tab Download
```

### **Cenário 4: Download Falha (com Retry)**

```
1. App iOS → POST /api/v1/download
2. Backend → Inicia download, mas YouTube retorna 403
3. Backend → Retry automático #1 (aguarda 2s)
4. Backend → Retry automático #2 (aguarda 4s)
5. Backend → Retry automático #3 (aguarda 8s)
6. Backend → Falha após 3 tentativas
7. Backend → Retorna HTTP 500 com erro "DOWNLOAD_FAILED"
8. App iOS → Mostra alerta com botão "Tentar Novamente"
9. Se usuário clica → repete fluxo desde o passo 1
```

### **Cenário 5: Cold Start do Render**

```
1. App iOS → POST /api/v1/metadata (primeira req após 15min)
2. App iOS → Timeout após 5s sem resposta
3. App iOS → Mostra "Ativando servidor... (pode levar 30s)"
4. App iOS → Retry automático após 30s
5. Backend acorda e responde normalmente
6. Fluxo continua normal
```

### **Cenário 6: Limite Diário Excedido**

```
1. App iOS conta downloads do dia (via SwiftData)
2. Se usuário atingir 20 downloads → mostra warning antes do próximo
3. Alert: "Você atingiu o limite recomendado (20/dia). Continuar pode violar ToS. Prosseguir?"
4. Se usuário aceita → permite download normalmente
5. Se usuário cancela → volta para tab Download
```

---

## **Configurações Específicas do Render.com**

### **Environment Variables (a configurar no Render dashboard):**

```
PORT=10000  (Render define automaticamente)
MAX_CONCURRENT_DOWNLOADS=3
FILE_RETENTION_HOURS=24
MAX_VIDEO_LENGTH_SECONDS=900  (15 min)
RATE_LIMIT_PER_MINUTE=10
```

### **Estrutura de Diretórios no Deploy:**

```
/
├── main.py              (FastAPI app)
├── requirements.txt     (dependências)
├── README.md           (documentação)
├── .gitignore          (ignorar venv, __pycache__, etc)
└── temp/               (armazenamento temporário de MP3s)
```

---

## **Considerações Importantes**

### **Limitações do Free Tier do Render:**

- Servidor "hiberna" após 15min de inatividade (primeira requisição pode levar 30-60s)
- 512MB de RAM (suficiente para 2-3 conversões simultâneas)
- 750 horas/mês grátis (mais que suficiente para uso pessoal)

**Solução:** App pode mostrar "Iniciando servidor..." na primeira requisição do dia

### **Alternativas se Render não funcionar:**

- Railway.app (similar, também free tier)
- Fly.io (mais complexo, mas mais recursos no free)

---

## **Integração com iOS App**

### **Configuração no App:**

```
// Desenvolvimento
let API_BASE_URL = "http://localhost:8000"

// Produção
let API_BASE_URL = "https://[PROJECT-NAME].onrender.com"
```

### **Headers Necessários:**

```
Content-Type: application/json
Accept: application/json
```

### **Timeouts Sugeridos:**

- Requisição /convert: 90 segundos
- Download de arquivo: 120 segundos
- Health check: 5 segundos

---

## **Testes Requeridos**

Antes de considerar backend pronto, testar:

1. ✅ URL válida do YouTube → conversão bem-sucedida
2. ✅ URL inválida → erro apropriado
3. ✅ Vídeo muito longo → rejeição ou aviso
4. ✅ Vídeo privado/removido → erro claro
5. ✅ Múltiplas requisições simultâneas → não travar
6. ✅ Download do MP3 → arquivo válido e reproduzível
7. ✅ Health check → resposta rápida

---

## **Prioridades de Implementação**

### **Fase 1 - MVP Funcional:**

1. Endpoint /convert básico
2. Download + conversão yt-dlp
3. Retorno de MP3
4. Teste local no Mac

### **Fase 2 - Production Ready:**

1. Endpoint /download com gestão de arquivos
2. Validações e error handling
3. Rate limiting
4. Deploy no Render.com

### **Fase 3 - Melhorias:**

1. Limpeza automática de arquivos antigos
2. Cache de thumbnails
3. Logs estruturados
4. Métricas básicas

---

## **Notas Finais**

- Este backend é **exclusivamente para uso pessoal/educacional**
- Não será exposto publicamente (apenas para seu app iOS)
- Código deve ser simples e manutenível (não precisa ser enterprise-grade)
- Foco em funcionalidade e confiabilidade, não em otimizações prematuras

---

**Fim das Especificações do Backend** ✅

---
