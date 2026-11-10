#!/bin/bash
# Instalação alternativa pelo Terminal (o normal é baixar o DMG e arrastar para Aplicativos).
#   curl -fsSL https://raw.githubusercontent.com/macholas96/lembrete-agua/main/instalar.sh | bash
set -euo pipefail
REPO="${1:-macholas96/lembrete-agua}"
DEST="/Applications/LembreteAgua.app"
[[ "$(uname)" == "Darwin" ]] || { echo "Isto é para macOS."; exit 1; }
if [ "$(sw_vers -productVersion | cut -d. -f1)" -lt 13 ]; then
  echo "Precisa do macOS 13 (Ventura) ou mais novo."; exit 1
fi

T="$(mktemp -d)"
trap 'rm -rf "$T"' EXIT

echo "Baixando a versão mais recente..."
if curl -fsSL "https://github.com/$REPO/releases/latest/download/LembreteAgua.zip" -o "$T/app.zip"; then
  ditto -x -k "$T/app.zip" "$T"
else
  echo "Ainda não há versão pronta publicada; compilando a partir do código (precisa das ferramentas da Apple)."
  if ! xcrun --find swiftc >/dev/null 2>&1; then
    xcode-select --install || true
    echo "Instale as Ferramentas de Linha de Comando e rode de novo."; exit 1
  fi
  curl -fsSL "https://codeload.github.com/$REPO/tar.gz/refs/heads/main" | tar xz -C "$T"
  SRC="$(find "$T" -mindepth 1 -maxdepth 1 -type d | head -1)"
  bash "$SRC/build.sh" "$T/LembreteAgua.app"
fi

# Remove a instalação antiga (versão 1.0, que rodava por um LaunchAgent próprio)
launchctl bootout "gui/$(id -u)/com.lembrete.agua" 2>/dev/null || true
rm -f "$HOME/Library/LaunchAgents/com.lembrete.agua.plist"
rm -rf "$HOME/Applications/LembreteAgua.app"
pkill -x LembreteAgua 2>/dev/null || true

rm -rf "$DEST"
ditto "$T/LembreteAgua.app" "$DEST"
xattr -dr com.apple.quarantine "$DEST" 2>/dev/null || true
open "$DEST"
echo "✅ Instalado em Aplicativos. Siga as boas-vindas que abriram na tela."
