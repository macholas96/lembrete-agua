#!/bin/bash
# Compila o LembreteAgua num .app.
#   bash build.sh /caminho/LembreteAgua.app          (só a arquitetura deste Mac)
#   UNIVERSAL=1 bash build.sh /caminho/LembreteAgua.app   (Apple Silicon + Intel, usado nas releases)
set -euo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OUT="${1:?informe o destino .app}"
VER="$(tr -d '[:space:]' < "$DIR/VERSION")"
REPO="${REPO:-macholas96/lembrete-agua}"
T="$(mktemp -d)"
trap 'rm -rf "$T"' EXIT

compilar() {
  xcrun swiftc -O -swift-version 5 -parse-as-library \
    -target "$1-apple-macos13.0" \
    "$DIR"/Sources/*.swift -o "$2"
}

if [ "${UNIVERSAL:-0}" = "1" ]; then
  compilar arm64 "$T/bin-arm64"
  compilar x86_64 "$T/bin-x86_64"
  lipo -create "$T/bin-arm64" "$T/bin-x86_64" -output "$T/LembreteAgua"
else
  compilar "$(uname -m)" "$T/LembreteAgua"
fi

rm -rf "$OUT"
mkdir -p "$OUT/Contents/MacOS" "$OUT/Contents/Resources" "$OUT/Contents/Library/LaunchAgents"
cp "$T/LembreteAgua" "$OUT/Contents/MacOS/LembreteAgua"
cp "$DIR/NOVIDADES.md" "$OUT/Contents/Resources/NOVIDADES.md"
cp "$DIR/Recursos/com.lembrete.agua.agente.plist" "$OUT/Contents/Library/LaunchAgents/"

# Ícone (.icns) a partir do PNG 1024×1024
ICONE=""
if [ -f "$DIR/Recursos/AppIcon.png" ] && command -v iconutil >/dev/null 2>&1; then
  IS="$T/AppIcon.iconset"
  mkdir -p "$IS"
  for s in 16 32 128 256 512; do
    sips -z "$s" "$s" "$DIR/Recursos/AppIcon.png" --out "$IS/icon_${s}x${s}.png" >/dev/null
    d=$((s * 2))
    sips -z "$d" "$d" "$DIR/Recursos/AppIcon.png" --out "$IS/icon_${s}x${s}@2x.png" >/dev/null
  done
  iconutil -c icns "$IS" -o "$OUT/Contents/Resources/AppIcon.icns"
  ICONE="<key>CFBundleIconFile</key><string>AppIcon</string>"
fi

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
  <key>LSApplicationCategoryType</key><string>public.app-category.healthcare-fitness</string>
  <key>NSHighResolutionCapable</key><true/>
  <key>NSCameraUsageDescription</key><string>Para confirmar, ao vivo, que você bebeu água. Nenhuma imagem é salva.</string>
  <key>LembreteAguaRepo</key><string>$REPO</string>
  $ICONE
</dict></plist>
PLIST

# Assinatura: Developer ID se houver (releases oficiais), senão assinatura local.
if [ -n "${IDENTIDADE_ASSINATURA:-}" ]; then
  codesign --force --options runtime --timestamp --sign "$IDENTIDADE_ASSINATURA" "$OUT"
else
  codesign --force --sign - "$OUT" >/dev/null
fi
echo "Compilado: $OUT (versão $VER)"
