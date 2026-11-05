#!/bin/zsh
set -euo pipefail
cd "${0:A:h:h}"
swift build --disable-sandbox -c release -debug-info-format none
BIN_DIR="$(swift build --disable-sandbox -c release --show-bin-path)"
APP="$PWD/dist/VPS Monitor.app"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Helpers" "$APP/Contents/Resources"
cp "$BIN_DIR/VPSMonitor" "$APP/Contents/MacOS/VPSMonitor.next"
mv -f "$APP/Contents/MacOS/VPSMonitor.next" "$APP/Contents/MacOS/VPSMonitor"
cp "$BIN_DIR/VPSAskPass" "$APP/Contents/Helpers/VPSAskPass.next"
mv -f "$APP/Contents/Helpers/VPSAskPass.next" "$APP/Contents/Helpers/VPSAskPass"
swift scripts/make-icon.swift "$PWD/.build/VPSMonitor.iconset"
cp "$PWD/.build/AppIcon.icns" "$APP/Contents/Resources/AppIcon.icns"
for resource in "$BIN_DIR"/*.bundle(N); do
    /usr/bin/ditto "$resource" "$APP/Contents/Resources/${resource:t}"
done
cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleName</key><string>VPS Monitor</string>
<key>CFBundleDisplayName</key><string>VPS Monitor</string>
<key>CFBundleIdentifier</key><string>local.vpsmonitor.mac</string>
<key>CFBundleVersion</key><string>4</string>
<key>CFBundleShortVersionString</key><string>1.0.3</string>
<key>CFBundleExecutable</key><string>VPSMonitor</string>
<key>CFBundleIconFile</key><string>AppIcon</string>
<key>CFBundleSupportedPlatforms</key><array><string>MacOSX</string></array>
<key>CFBundlePackageType</key><string>APPL</string>
<key>LSMinimumSystemVersion</key><string>14.0</string>
<key>NSHighResolutionCapable</key><true/>
</dict></plist>
PLIST
/usr/bin/codesign --force --sign - --identifier local.vpsmonitor.askpass "$APP/Contents/Helpers/VPSAskPass"
/usr/bin/codesign --force --sign - --identifier local.vpsmonitor.mac "$APP"
"$APP/Contents/MacOS/VPSMonitor" --self-check
print "Built: $APP"
