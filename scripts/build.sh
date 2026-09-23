#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
APP="$PWD/build/ScreenDimmer.app"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources" "$PWD/build/module-cache"
source scripts/toolchain.sh
xcrun swiftc -O "${SWIFT_FLAGS[@]}" -target arm64-apple-macosx14.0 Sources/DimmingPolicy.swift Sources/GammaDimming.swift Sources/SafariZoomSync.swift Sources/main.swift -o "$APP/Contents/MacOS/ScreenDimmer" -framework AppKit -framework SwiftUI -framework Carbon -framework QuartzCore
cp Info.plist "$APP/Contents/Info.plist"
codesign --force --sign - "$APP"
printf 'Built: %s\n' "$APP"
