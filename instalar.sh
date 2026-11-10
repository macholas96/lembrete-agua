#!/bin/bash
# Instala (ou reinstala) o LembreteAgua.
#   De dentro da pasta baixada:   bash instalar.sh [usuario/repositorio]
#   Direto do GitHub:             curl -fsSL https://raw.githubusercontent.com/USUARIO/REPO/main/instalar.sh | bash -s USUARIO/REPO
set -euo pipefail
REPO="${1:-}"
LABEL="com.lembrete.agua"
APP="$HOME/Applications/LembreteAgua.app"
PLIST="$HOME/Library/LaunchAgents/$LABEL.plist"
DADOS="$HOME/Library/Application Support/LembreteAgua"

[[ "$(uname)" == "Darwin" ]] || { echo "Isto é para macOS."; exit 1; }
if [ "$(sw_vers -productVersion | cut -d. -f1)" -lt 13 ]; then
  echo "Precisa do macOS 13 (Ventura) ou mais novo."; exit 1
fi
if ! xcrun --find swiftc >/dev/null 2>&1; then
  echo "Faltam as Ferramentas de Linha de Comando da Apple (gratuitas)."
  echo "Vou abrir o instalador da Apple. Quando terminar, rode este comando de novo."
  xcode-select --install || true
  exit 1
fi

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
SRC="${BASH_SOURCE[0]:-}"
DIR=""
if [ -n "$SRC" ] && [ -f "$SRC" ]; then DIR="$(cd "$(dirname "$SRC")" && pwd)"; fi
if [ -z "$DIR" ] || [ ! -f "$DIR/build.sh" ]; then
  [ -n "$REPO" ] || { echo "Informe o repositório:  ... | bash -s usuario/repositorio"; exit 1; }
  echo "Baixando de github.com/$REPO..."
  curl -fsSL "https://codeload.github.com/$REPO/tar.gz/refs/heads/main" | tar xz -C "$TMP"
  DIR="$(find "$TMP" -mindepth 1 -maxdepth 1 -type d | head -1)"
fi

echo "Compilando (leva 1–2 min)..."
bash "$DIR/build.sh" "$TMP/LembreteAgua.app"

launchctl bootout "gui/$(id -u)/$LABEL" 2>/dev/null || true
mkdir -p "$HOME/Applications" "$HOME/Library/LaunchAgents" "$DADOS"
rm -rf "$APP"
mv "$TMP/LembreteAgua.app" "$APP"
tccutil reset Camera "$LABEL" >/dev/null 2>&1 || true
[ -n "$REPO" ] && echo "$REPO" > "$DADOS/fonte.txt"
cp "$DIR/desinstalar.sh" "$DADOS/desinstalar.sh" && chmod +x "$DADOS/desinstalar.sh"

cat > "$PLIST" <<PL
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>Label</key><string>$LABEL</string>
  <key>ProgramArguments</key><array><string>$APP/Contents/MacOS/LembreteAgua</string></array>
  <key>RunAtLoad</key><true/>
  <key>KeepAlive</key><true/>
  <key>ThrottleInterval</key><integer>5</integer>
  <key>ProcessType</key><string>Interactive</string>
</dict></plist>
PL
launchctl bootstrap "gui/$(id -u)" "$PLIST"

echo
echo "✅ Instalado! A janela de Ajustes vai abrir — e procure a gotinha 💧 na barra de menus."
echo "→ Quando o macOS pedir acesso à câmera, clique em PERMITIR."
echo
echo "Para ver a tela azul agora:"
echo "  touch \"$DADOS/testar\""
