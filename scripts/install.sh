#!/bin/sh
set -eu
root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
app=/Applications/Timeglass.app
staging="/Applications/Timeglass-staging-$$.app"
sh "$root/scripts/package.sh" "$staging"
if [ -e "$app" ]; then
    mkdir -p "$HOME/Applications"
    mv "$app" "$HOME/Applications/Timeglass-backup-$(date +%Y%m%d-%H%M%S)-$$.app"
fi
mv "$staging" "$app"
echo "Installed $app"
