#!/bin/bash
# Inicia o serviço de legendagem ao vivo (WhisperLiveKit).
# Container podman com venv interno; comando equivalente que roda dentro:
#   source /opt/venv/bin/activate
#   whisperlivekit-server --model medium --language pt --host 0.0.0.0 --port 8000
set -euo pipefail

echo "→ subindo legendagem-app.service"
sudo systemctl start legendagem-app

echo "→ aguardando WhisperLiveKit responder (modelo medium pode demorar 30-120s no primeiro start)"
for i in $(seq 1 120); do
    if curl -sf -o /dev/null --max-time 2 http://127.0.0.1:18092/ ; then
        echo "✓ Pronto."
        echo "  Display:    https://legendagem.casahacker.org/"
        echo "  WebSocket:  wss://legendagem.casahacker.org/asr"
        exit 0
    fi
    sleep 2
done

echo "⚠ Timeout: serviço não respondeu em 240s. Verifique:"
echo "  sudo systemctl status legendagem-app"
echo "  sudo podman logs legendagem"
exit 1
