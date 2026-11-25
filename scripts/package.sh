#!/bin/sh
set -eu
root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
app=${1:?usage: package.sh NEW_APP_PATH}
[ ! -e "$app" ] || { echo "Refusing to overwrite $app" >&2; exit 1; }
mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources"
cp "$root/build/timeglass" "$app/Contents/MacOS/timeglass"
cp "$root/assets/Timeglass.icns" "$app/Contents/Resources/Timeglass.icns"
cat > "$app/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleExecutable</key><string>timeglass</string>
<key>CFBundleIdentifier</key><string>com.moritz.timeglass</string>
<key>CFBundleName</key><string>Timeglass</string>
<key>CFBundleDisplayName</key><string>Timeglass</string>
<key>CFBundleIconFile</key><string>Timeglass</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleShortVersionString</key><string>0.1.0</string>
<key>CFBundleVersion</key><string>1</string>
<key>LSMinimumSystemVersion</key><string>26.0</string>
<key>NSHighResolutionCapable</key><true/>
</dict></plist>
PLIST
identity=${TIMEGLASS_SIGN_IDENTITY:-$(security find-identity -v -p codesigning 2>/dev/null | awk '/Developer ID Application:/ {print $2; exit}')}
codesign --force --sign "${identity:--}" "$app"
codesign --verify --strict "$app"
