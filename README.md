# Casa Hacker Legendagem

Sistema de legendagem ao vivo para eventos presenciais — teatro, palestras e shows.
Baseado em [WhisperLiveKit](https://github.com/QuentinFuxa/WhisperLiveKit), empacotado em container Podman/Docker, com página de display HTML/CSS/JS standalone aplicando o [Casa Hacker Design System](https://github.com/casahacker/design-system).

**Demo em produção:** <https://legendagem.casahacker.org/>

---

## Funcionalidades

- Transcrição em tempo real via WebSocket (WhisperLiveKit + faster-whisper)
- Idioma Português (`--language pt`), modelo `medium` (~1.5GB, baixa na primeira execução)
- CPU-only por padrão (não requer GPU)
- Página de display em página única (HTML/CSS/JS inline + 2 fontes WOFF2)
  - Tema claro/escuro com persistência
  - Botões de aumentar/reduzir texto (clamp 0.6× a 1.8×)
  - Modo fullscreen com auto-hide do footer
  - Indicador de status (desconectado · conectando · ao vivo · erro)
  - Mostra apenas as 2 últimas frases finalizadas (sem histórico) + texto em construção em cinza
  - Branding Casa Hacker no rodapé com símbolo "H" pixelado oficial
  - Tokens de cor do CHDS (`--ch-code`, `--ch-dos`, `--ch-css`, `--ch-java`, etc.)
- Configuração de servidor escondida (auto-detecta `wss://<host>/asr`); revelável com `Ctrl+Shift+S` ou `?config=1`

---

## Atalhos de teclado

| Tecla | Ação |
|---|---|
| `F` | Tela cheia |
| `T` | Alternar tema |
| `+` / `-` | Aumentar / reduzir texto |
| `Esc` | Sair da tela cheia |
| `Ctrl+Shift+S` | Revelar/ocultar campo de configuração do servidor |

---

## Arquitetura

```
                      browser (operador)
                            │
                            │  https://legendagem.example.org/
                            ▼
                  ┌─────────────────────┐
                  │       nginx         │  TLS termination
                  │  ── / ────────────  │  serve display.html + fonts
                  │  ── /asr ──── WS ── │  proxy_pass com Upgrade
                  └─────────┬───────────┘
                            │
                  127.0.0.1:18092
                            │
                  ┌─────────▼──────────────────────────────┐
                  │  podman container "legendagem"          │
                  │  python:3.12-slim + venv + ffmpeg       │
                  │  whisperlivekit-server :8000            │
                  │  modelo medium · idioma pt · CPU-only   │
                  └────────────────────────────────────────┘
```

---

## Pré-requisitos

- Linux com **Podman 4+** (testado em RHEL 10)
- `podman-compose` (1.5+) para o `compose.yaml`
- ~5GB livres no disco (imagem ~2.4GB + modelo ~1.5GB + cache)
- ~2GB RAM disponível em runtime
- Nginx + Certbot se for expor HTTPS (recomendado)
- Domínio com DNS apontando pra esta máquina

---

## Quickstart

### 1. Clonar e construir a imagem

```bash
git clone https://github.com/casahacker/legendagem.git /data/apps/legendagem
cd /data/apps/legendagem

# build da imagem (PyTorch CPU-only, ~5-10min)
TMPDIR=/data/tmp sudo -E podman build --tmpdir /data/tmp -t localhost/legendagem:latest .
```

Por padrão o pip puxa PyTorch com CUDA, que infla a imagem em 3+ GB sem benefício real em servidores sem GPU.
O `Dockerfile` força CPU via `--index-url https://download.pytorch.org/whl/cpu`.

### 2. Variáveis e volumes

- `/data/legendagem/models` — cache do HuggingFace (`HF_HOME`). Persistir entre runs evita re-download do modelo.

### 3. Subir o container (modo evento)

```bash
./start-evento.sh
```

Equivalente a:
```bash
sudo systemctl start legendagem-app
# que internamente roda:
#   cd /data/apps/legendagem && podman-compose up -d
# que ativa o venv em /opt/venv dentro do container e dispara:
#   whisperlivekit-server --model medium --language pt --host 0.0.0.0 --port 8000
```

Encerrar:
```bash
./stop-evento.sh
```

### 4. Acessar o display

- HTTPS recomendado: <https://seu-dominio/>
- Direto (LAN): abrir `web/display.html` em qualquer browser e digitar o IP do servidor

---

## Deploy completo (referência)

Os arquivos em [`deploy/`](deploy/) são os usados em produção em `casahacker.org` — adapte:

- **`deploy/legendagem-app.service`** — unidade systemd com prevenção de bridge stale (subnet 10.89.12.0/24); enabled mas não start (manual via `start-evento.sh`)
- **`deploy/nginx-legendagem.conf`** — vhost nginx com:
  - TLS via Let's Encrypt
  - `location /asr` com `proxy_http_version 1.1` + `Upgrade`/`Connection` (necessário pra WebSocket)
  - `proxy_read_timeout 3600s` (eventos longos)
  - Header `Permissions-Policy: microphone=(self)` (necessário para `getUserMedia`)
  - `root /data/apps/legendagem/web` servindo `display.html` + fonts

```bash
# instalar
sudo cp deploy/legendagem-app.service /etc/systemd/system/
sudo cp deploy/nginx-legendagem.conf  /etc/nginx/conf.d/legendagem.conf
sudo systemctl daemon-reload
sudo certbot --nginx -d legendagem.seu-dominio.org
```

---

## Como funciona o display

A página `web/display.html` é um *single-file app* (~16KB + 2 WOFF2):

1. **Servidor** auto-preenchido com `wss://<host-atual>/asr` (override via `?server=...`)
2. **Conectar** pede permissão do microfone (`navigator.mediaDevices.getUserMedia`)
3. Usa **`MediaRecorder`** com `audio/webm;codecs=opus` em chunks de 250ms
4. Envia os chunks binários pelo WebSocket
5. Recebe JSON com `{lines:[…], buffer_transcription: "…"}` do servidor
6. Renderiza só as **2 últimas frases finalizadas** (anterior + atual) + buffer em construção

O design é direcionado pra alta legibilidade em palco:
- texto >= 4vw, font-weight 500
- balance de quebra de linha (`text-wrap: balance`)
- fundo full-screen, footer auto-hide em fullscreen

---

## Customização

### Trocar modelo / idioma

Edite o `CMD` do `Dockerfile`:

```dockerfile
CMD ["whisperlivekit-server", "--model", "small", "--language", "en", "--host", "0.0.0.0", "--port", "8000"]
```

Modelos disponíveis: `tiny`, `base`, `small`, `medium`, `large-v3`. `medium` é o ponto doce para PT-BR em CPU; `small` é ~2× mais rápido com pequena perda de qualidade.

### Trocar tokens visuais

Edite `:root` em `web/display.html` — variáveis começam com `--ch-` (brand) e `--stage-` (display).
A paleta completa do Casa Hacker DS está documentada em <https://github.com/casahacker/design-system>.

---

## Limitações conhecidas

- **Modelo medium em CPU é apertado pra real-time** em servidores cloud comuns. Pode haver delay de 2-5s e words-per-minute baixo em discursos rápidos. Para eventos sérios, considere `small` (mais leve) ou um servidor com GPU.
- **Display + microfone no mesmo dispositivo**: o WhisperLiveKit não tem broadcast nativo. O dispositivo onde a página roda é também o que captura o áudio. Setup típico: laptop perto do palco com mic input, projetando no telão.
- **Mixed content**: páginas HTTPS bloqueiam WS:// — sempre use `wss://` quando a página estiver atrás de TLS.
- **Diarização desabilitada** por padrão. Para ativar, adicione `--diarization` ao CMD.

---

## Stack

- [WhisperLiveKit](https://github.com/QuentinFuxa/WhisperLiveKit) — wrapper FastAPI+WebSocket sobre faster-whisper
- [faster-whisper](https://github.com/SYSTRAN/faster-whisper) — CTranslate2 backend, ~4× mais rápido que openai-whisper
- [Casa Hacker Design System](https://github.com/casahacker/design-system) — tokens, fontes, identidade visual
- Python 3.12, PyTorch 2.x CPU-only, ffmpeg, nginx, podman

---

## Licença

Código deste repositório segue a licença do Casa Hacker (a definir).
WhisperLiveKit e faster-whisper são MIT.
IBM Plex Mono e Roboto Flex são SIL Open Font License 1.1.
