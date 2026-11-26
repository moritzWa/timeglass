#!/bin/sh
set -eu
root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
mkdir -p "$root/build"
optimization=-Onone
if [ "$#" -gt 0 ]; then
    case "$1" in
        --debug) optimization=-Onone ;;
        --release) optimization=-O ;;
        *) echo "usage: build.sh [--debug|--release]" >&2; exit 1 ;;
    esac
fi
xcrun swiftc -parse-as-library -swift-version 6 -target arm64-apple-macosx26.0 \
  "$optimization" "$root/Sources/TimerModel.swift" "$root/Sources/App.swift" -o "$root/build/timeglass"
