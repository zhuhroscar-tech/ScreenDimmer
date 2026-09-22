#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p build/module-cache
source scripts/toolchain.sh
xcrun swiftc "${SWIFT_FLAGS[@]}" Sources/DimmingPolicy.swift Sources/GammaDimming.swift Tests/main.swift -o build/policy-tests
build/policy-tests
