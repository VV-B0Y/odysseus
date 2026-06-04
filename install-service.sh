#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SERVICE_FILE="$SCRIPT_DIR/basedcode-ai.service"

if [ ! -f "$SERVICE_FILE" ]; then
  echo "Error: basedcode-ai.service not found in $SCRIPT_DIR"
  exit 1
fi

echo "Installing BasedCode AI UI service..."
echo "Make sure you've edited basedcode-ai.service with your username and paths first!"
echo ""

sudo cp "$SERVICE_FILE" /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable basedcode-ai
sudo systemctl start basedcode-ai
sudo systemctl status basedcode-ai
