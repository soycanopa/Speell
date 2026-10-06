#!/bin/bash
# Empaqueta el binario de Speell en un .app mínimo: CFBundleIdentifier es lo
# que exige UNUserNotificationCenter para las notificaciones del sistema.
# Uso: Scripts/make-app.sh [debug|release]
set -euo pipefail
cd "$(dirname "$0")/.."
CONFIG="${1:-debug}"
BIN=".build/$CONFIG/Speell"
APP=".build/$CONFIG/Speell.app"
[ -f "$BIN" ] || { echo "no existe $BIN (corre swift build primero)"; exit 1; }
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/Speell"
# El bundle de recursos de SwiftPM (los svgs de los iconos, via
# Bundle.module): sin él, el accessor mata el proceso con fatalError al
# primer acceso. Va en Contents/Resources y junto al ejecutable, los dos
# lugares donde el accessor lo busca.
RESOURCES_BUNDLE=".build/$CONFIG/Speell_Speell.bundle"
if [ -d "$RESOURCES_BUNDLE" ]; then
  cp -R "$RESOURCES_BUNDLE" "$APP/Contents/Resources/"
  cp -R "$RESOURCES_BUNDLE" "$APP/Contents/MacOS/"
fi
cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleIdentifier</key><string>com.speell.app</string>
  <key>CFBundleName</key><string>Speell</string>
  <key>CFBundleExecutable</key><string>Speell</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>0.2.0</string>
  <key>LSMinimumSystemVersion</key><string>13.4</string>
  <key>NSPrincipalClass</key><string>NSApplication</string>
</dict>
</plist>
PLIST
echo "$APP"
