#!/bin/sh
set -eu
root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
mkdir -p "$root/build"
xcrun swiftc -parse-as-library -swift-version 6 "$root/Sources/TimerModel.swift" \
  "$root/Tests/ModelTests.swift" -o "$root/build/model-tests"
"$root/build/model-tests"
