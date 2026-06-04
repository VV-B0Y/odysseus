#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SERVICE_FILE="$SCRIPT_DIR/basedcode-ui.service"

if [ ! -f "$SERVICE_FILE" ]; then
  echo "Error: basedcode-ui.service not found in $SCRIPT_DIR"
  exit 1
fi

echo "Installing Based code UI service..."
echo "Make sure you've edited basedcode-ui.service with your username and paths first!"
echo ""

sudo cp "$SERVICE_FILE" /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable basedcode-ui
sudo systemctl start basedcode-ui
sudo systemctl status basedcode-ui
