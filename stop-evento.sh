#!/bin/bash
# Encerra o serviço de legendagem (libera ~2GB RAM).
set -euo pipefail

echo "→ parando legendagem-app.service"
sudo systemctl stop legendagem-app

echo "✓ Serviço encerrado."
