#!/usr/bin/env bash
# CI helper (macos-14 runners): select the newest installed Xcode 16.x and make sure an
# "iPhone 16" simulator exists, since xcodebuild's destination is pinned to it.
set -euo pipefail

XCODE_APP="$(ls -d /Applications/Xcode_16*.app 2>/dev/null | sort -V | tail -1 || true)"
if [ -z "$XCODE_APP" ]; then
  echo "No Xcode 16.x found in /Applications" >&2
  ls -d /Applications/Xcode*.app >&2 || true
  exit 1
fi
sudo xcode-select -s "$XCODE_APP/Contents/Developer"
xcodebuild -version

DEVICE_NAME="${SIMULATOR_NAME:-iPhone 16}"
if ! xcrun simctl list devices available | grep -q "    $DEVICE_NAME ("; then
  RUNTIME="$(xcrun simctl list runtimes available -j | python3 -c '
import json, sys
runtimes = [r for r in json.load(sys.stdin)["runtimes"] if r.get("platform") == "iOS" and r.get("isAvailable")]
runtimes.sort(key=lambda r: [int(p) for p in r["version"].split(".")])
print(runtimes[-1]["identifier"] if runtimes else "")
')"
  if [ -z "$RUNTIME" ]; then
    echo "No available iOS simulator runtime" >&2
    exit 1
  fi
  echo "Creating simulator '$DEVICE_NAME' on $RUNTIME"
  xcrun simctl create "$DEVICE_NAME" com.apple.CoreSimulator.SimDeviceType.iPhone-16 "$RUNTIME"
fi
xcrun simctl list devices available | grep "$DEVICE_NAME" || true
