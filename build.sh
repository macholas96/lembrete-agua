#!/bin/bash
# Compila o LembreteAgua num .app.   Uso: bash build.sh /caminho/LembreteAgua.app
set -euo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OUT="${1:?informe o destino .app}"
VER="$(tr -d '[:space:]' < "$DIR/VERSION")"
T="$(mktemp -d)"
trap 'rm -rf "$T"' EXIT

xcrun swiftc -O -swift-version 5 -parse-as-library \
  -target "$(uname -m)-apple-macos13.0" \
  "$DIR"/Sources/*.swift -o "$T/LembreteAgua"

rm -rf "$OUT"
mkdir -p "$OUT/Contents/MacOS" "$OUT/Contents/Resources"
cp "$T/LembreteAgua" "$OUT/Contents/MacOS/LembreteAgua"
cp "$DIR/NOVIDADES.md" "$OUT/Contents/Resources/NOVIDADES.md"
cat > "$OUT/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>CFBundleIdentifier</key><string>com.lembrete.agua</string>
  <key>CFBundleName</key><string>LembreteAgua</string>
  <key>CFBundleDisplayName</key><string>LembreteAgua</string>
  <key>CFBundleExecutable</key><string>LembreteAgua</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleVersion</key><string>$VER</string>
  <key>CFBundleShortVersionString</key><string>$VER</string>
  <key>LSMinimumSystemVersion</key><string>13.0</string>
  <key>LSUIElement</key><true/>
  <key>NSHighResolutionCapable</key><true/>
  <key>NSCameraUsageDescription</key><string>Para confirmar, ao vivo, que você bebeu água. Nenhuma imagem é salva.</string>
</dict></plist>
PLIST
codesign --force --sign - "$OUT" >/dev/null
echo "Compilado: $OUT (versão $VER)"
