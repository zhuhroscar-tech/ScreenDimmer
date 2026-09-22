#!/bin/bash
# Some upgraded Command Line Tools installations contain two definitions of
# SwiftBridging. Hide only the obsolete duplicate in the compiler's virtual
# filesystem, leaving the installed toolchain untouched.
SWIFT_FLAGS=(-module-cache-path "$PWD/build/fixed-module-cache")
SWIFT_INCLUDE="$(xcode-select -p)/usr/include/swift"
if [[ -f "$SWIFT_INCLUDE/module.modulemap" && -f "$SWIFT_INCLUDE/bridging.modulemap" ]] && cmp -s <(sed '/^[[:space:]]*\/\//d' "$SWIFT_INCLUDE/module.modulemap") <(sed '/^[[:space:]]*\/\//d' "$SWIFT_INCLUDE/bridging.modulemap"); then
    touch "$PWD/build/empty.modulemap"
    /usr/bin/plutil -create xml1 "$PWD/build/toolchain-overlay.json"
    /usr/bin/plutil -insert version -integer 0 "$PWD/build/toolchain-overlay.json"
    /usr/bin/plutil -insert roots -json '[]' "$PWD/build/toolchain-overlay.json"
    /usr/bin/plutil -insert roots.0 -json '{}' "$PWD/build/toolchain-overlay.json"
    /usr/bin/plutil -insert roots.0.type -string file "$PWD/build/toolchain-overlay.json"
    /usr/bin/plutil -insert roots.0.name -string "$SWIFT_INCLUDE/module.modulemap" "$PWD/build/toolchain-overlay.json"
    /usr/bin/plutil -insert roots.0.external-contents -string "$PWD/build/empty.modulemap" "$PWD/build/toolchain-overlay.json"
    /usr/bin/plutil -convert json "$PWD/build/toolchain-overlay.json"
    SWIFT_FLAGS+=(-vfsoverlay "$PWD/build/toolchain-overlay.json")
fi
