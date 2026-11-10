#!/bin/bash
# Gera o DMG de instalação (arrastar para Aplicativos).   Uso: bash scripts/criar-dmg.sh LembreteAgua.app LembreteAgua.dmg
set -euo pipefail
APP="$1"
OUT="$2"
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
T="$(mktemp -d)"
trap 'rm -rf "$T"' EXIT
mkdir -p "$T/src"
ditto "$APP" "$T/src/LembreteAgua.app"
rm -f "$OUT"

if command -v create-dmg >/dev/null 2>&1 || brew install create-dmg >/dev/null 2>&1; then
  tiffutil -cathidpicheck "$DIR/Recursos/dmg-fundo.png" "$DIR/Recursos/dmg-fundo@2x.png" -out "$T/fundo.tiff"
  if create-dmg \
      --volname "LembreteAgua" \
      --volicon "$T/src/LembreteAgua.app/Contents/Resources/AppIcon.icns" \
      --background "$T/fundo.tiff" \
      --window-pos 200 120 \
      --window-size 660 420 \
      --icon-size 112 \
      --icon "LembreteAgua.app" 170 215 \
      --hide-extension "LembreteAgua.app" \
      --app-drop-link 490 215 \
      "$OUT" "$T/src"; then
    echo "DMG criado: $OUT"
    exit 0
  fi
  echo "create-dmg falhou; gerando DMG simples."
  rm -f "$OUT"
fi

ln -s /Applications "$T/src/Applications"
hdiutil create -volname "LembreteAgua" -srcfolder "$T/src" -ov -format UDZO "$OUT"
echo "DMG (simples) criado: $OUT"
