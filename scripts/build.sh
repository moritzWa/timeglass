#!/bin/sh
set -eu
root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
mkdir -p "$root/build"
xcrun swiftc -parse-as-library -swift-version 6 -target arm64-apple-macosx26.0 \
  "$root/Sources/TimerModel.swift" "$root/Sources/App.swift" -o "$root/build/timeglass"
