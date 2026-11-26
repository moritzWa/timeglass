#!/bin/sh
# Prepare a signed, notarized and stapled ZIP. Does not publish to GitHub.
set -eu
root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
: "$NOTARY_PROFILE"
identity=$(security find-identity -v -p codesigning | awk '/Developer ID Application:/ {print $2; exit}')
[ -n "$identity" ] || { echo "A Developer ID Application certificate is required" >&2; exit 1; }
version=0.1.0
out="$root/build/distribution/$version"
[ ! -e "$out" ] || { echo "Refusing to replace existing release output: $out" >&2; exit 1; }
mkdir -p "$out"
cd "$root"
sh "$root/scripts/test.sh"
sh "$root/scripts/build.sh" --release
TIMEGLASS_SIGN_IDENTITY="$identity" sh "$root/scripts/package.sh" "$out/Timeglass.app"
ditto -c -k --keepParent "$out/Timeglass.app" "$out/notarize.zip"
xcrun notarytool submit "$out/notarize.zip" --keychain-profile "$NOTARY_PROFILE" --wait --output-format json > "$out/notarization.json"
python3 - "$out/notarization.json" <<'PY'
import json,sys
result=json.load(open(sys.argv[1]))
print("Notarization:",result["status"],result["id"])
if result["status"]!="Accepted": raise SystemExit("Notarization was not accepted; do not publish")
PY
xcrun stapler staple "$out/Timeglass.app"
xcrun stapler validate "$out/Timeglass.app"
codesign --verify --deep --strict "$out/Timeglass.app"
spctl --assess --type execute --verbose=2 "$out/Timeglass.app"
ditto -c -k --keepParent "$out/Timeglass.app" "$out/Timeglass-$version-macos-arm64.zip"
cd "$out"
shasum -a 256 "Timeglass-$version-macos-arm64.zip" > SHA256SUMS.txt
echo "Verified release output: $out"
