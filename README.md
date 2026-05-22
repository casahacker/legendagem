# Casa Hacker Legendagem

Página de legendagem ao vivo para eventos presenciais — teatro, palestras, shows.
Arquivo único HTML que usa a [Web Speech API](https://developer.mozilla.org/en-US/docs/Web/API/Web_Speech_API) nativa do browser para transcrever fala em tempo real, com identidade visual do [Casa Hacker Design System](https://github.com/casahacker/design-system).

**Demo:** <https://legendagem.casahacker.org/>

---

## Como funciona

```
  [microfone do laptop]
          │
          ▼
  Chrome / Edge (browser)
   ├── getUserMedia → VU meter
   └── SpeechRecognition (pt-BR)
          │
          ▼
   <div> com texto grande projetado no telão
```

**Não há servidor de ASR.** O reconhecimento de fala roda no próprio browser (Chrome/Edge usam o backend do Google STT pela rede). Significa:

- Zero infraestrutura pra manter — basta servir o HTML estático
- Latência <800ms, *interim results* em tempo real
- Idioma `pt-BR` first-class
- Funciona em qualquer laptop com Chrome + internet

---

## Por que abandonamos o caminho self-hosted

Tentamos antes empacotar o [WhisperLiveKit](https://github.com/QuentinFuxa/WhisperLiveKit) em container Podman com modelo `medium`. O pipeline `browser MediaRecorder → ffmpeg → faster-whisper` se mostrou frágil em CPU-only — depois de horas debugando webm/opus vs PCM via AudioWorklet, decidimos pivotar.

A Web Speech API entrega qualidade equivalente ou melhor em PT-BR (usa o motor do Google STT que é estado-da-arte) sem nenhum servidor. Para eventos pontuais (poucos por mês), o trade-off "Chrome obrigatório + internet" venceu por simplicidade.

Se um dia precisar voltar pra self-hosted (compliance, sem internet no venue), [git log](https://github.com/casahacker/legendagem/commits/main) tem todos os commits do experimento.

---

## Funcionalidades

- Captura via Web Speech API com auto-restart (cobre sessões longas)
- Renderiza só as **2 últimas frases finalizadas** + frase em construção (cinza)
- **Tema claro/escuro** com persistência em localStorage
- **Aumentar/reduzir texto** (range 0.6× a 1.8×)
- **Fullscreen** com auto-hide do footer
- **VU meter** indicando nível do mic
- **Atalhos de teclado** (espaço, F, T, +/-, Esc)
- Branding Casa Hacker (logotipo horizontal SVG inline + tipografia Roboto Flex / IBM Plex Mono)

---

## Atalhos

| Tecla | Ação |
|---|---|
| `Space` | Iniciar / parar |
| `F` | Tela cheia |
| `T` | Alternar tema |
| `+` / `-` | Aumentar / reduzir texto |
| `Esc` | Sair da tela cheia |

---

## Deploy

Como é HTML estático, basta servir via qualquer web server. Aqui está rodando em nginx no servidor da Casa Hacker, mas pode ser GitHub Pages, Netlify, Vercel, ou um pendrive.

**Requisitos:**
- HTTPS obrigatório (a Web Speech API requer secure context)
- Header `Permissions-Policy: microphone=(self)` recomendado
- DNS apontando pro servidor

### Exemplo nginx (HTTPS via Let's Encrypt)

Veja [`deploy/nginx.conf`](deploy/nginx.conf) — basicamente:

```nginx
server {
    server_name legendagem.example.org;
    root /path/to/legendagem/web;
    index display.html;
    add_header Permissions-Policy "microphone=(self)";
    location / { try_files $uri $uri/ /display.html; }
    listen 443 ssl;
    # ... certificados Let's Encrypt ...
}
```

```bash
sudo cp deploy/nginx.conf /etc/nginx/conf.d/legendagem.conf
sudo certbot --nginx -d legendagem.example.org
```

### Modo "USB stick" (offline-friendly)

Como tudo é estático com fontes self-hosted, dá pra:

1. Copiar a pasta `web/` num pendrive
2. Servir local: `python -m http.server 8000` na pasta `web/`
3. Abrir `http://localhost:8000` no Chrome

⚠️ Mesmo nesse modo a Web Speech API **precisa de internet** (Chrome envia o áudio pra um servidor do Google pra transcrever). Se for evento offline, escolha outra solução (ver "Alternativas" abaixo).

---

## Compatibilidade de browser

| Browser | Suporte |
|---|---|
| ✅ Chrome (desktop) | Sim |
| ✅ Edge (desktop) | Sim |
| ✅ Chrome (Android) | Sim |
| ⚠️ Safari | Parcial — pode ter inconsistências |
| ❌ Firefox | Não há implementação estável |

Recomendação pra eventos: **Chrome desktop em laptop com mic externo**, projetar em fullscreen no telão.

---

## Estrutura do repo

```
legendagem/
├── README.md
├── .gitignore
└── web/
    ├── display.html          # único arquivo da aplicação (~21KB)
    └── fonts/
        ├── IBMPlexMono-Regular.woff2
        └── RobotoFlex-Variable.woff2
```

Sem build, sem dependências, sem package.json.

---

## Limitações conhecidas

- **Chrome/Edge only** — Firefox e Safari ainda não têm `SpeechRecognition` confiável
- **Precisa internet** — Chrome envia áudio pro Google STT em nuvem
- **Sessões longas**: Chrome encerra a transcrição após silêncios prolongados; o código já faz auto-restart no `onend`, mas pode haver gap de meio segundo
- **Sem diarização** (não distingue múltiplas vozes)
- **Sem timestamp por palavra** (Web Speech API só dá texto)
- **Sem pontuação automática consistente** — varia por idioma e versão do Chrome

---

## Alternativas (se Web Speech não atender)

| Solução | Self-host | PT-BR | Custo | Esforço |
|---|---|---|---|---|
| **Azure Speech Services** | ❌ | excelente | US$ 1/h (5h grátis/mês) | 1-2h |
| **Deepgram Nova-3** | ❌ | excelente | US$ 0,46/h (US$ 200 free credit) | 1-2h |
| **WhisperLiveKit** | ✅ | bom | grátis (mas CPU intenso) | alto · veja histórico do repo |
| **faster-whisper-server** | ✅ | bom | grátis | alto |
| **Vosk** | ✅ | regular | grátis | médio |

Para esta página é trivial trocar o motor: o ponto de extensão fica em `start()` no `display.html` — basta substituir o `SpeechRecognition` por um cliente WebSocket pro backend escolhido. A UI (footer, tema, fontes, fullscreen) permanece igual.

---

## Stack

- [Web Speech API](https://developer.mozilla.org/en-US/docs/Web/API/Web_Speech_API) (browser nativo)
- [Casa Hacker Design System](https://github.com/casahacker/design-system) — tokens, logotipo SVG, IBM Plex Mono, Roboto Flex
- nginx (para servir HTTPS)
- Let's Encrypt (TLS)

---

## Licença

Código deste repositório segue a licença do Casa Hacker (a definir).
IBM Plex Mono e Roboto Flex são SIL Open Font License 1.1.
