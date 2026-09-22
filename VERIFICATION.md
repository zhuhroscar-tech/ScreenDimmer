# Verification — 1.1.0

Verified on macOS 15.7.7 with the connected Sculptor (3200 × 2560).

- Release build, signature verification, and brightness-policy tests passed.
- Gamma tests passed: original calibration retained, repeated updates do not compound, unselected displays unchanged, restoration retry after a write failure, unsupported-display handling, and fresh baseline on reconnect.
- Live integration tests passed at 100%, 75%, 50%, 25%, and 15%.
- Sculptor accepted the scaled RGB tables at every dimmed setting and readback matched. Its overlay was hidden throughout these tests.
- Pause and Restore returned all three RGB channels to their captured original tables, verified by live readback.
- Built-in display was unchanged with the default selection.
- A 20-second read-only observation collected 679 samples from both displays with no transfer-table changes or read failures. The sampler cannot prove that a gesture occurred during that interval.
- Installed and launched version 1.1.0. The interface reported display dimming on Sculptor at the saved 75% setting.

Raw results: `build/integration-results-v1.1.json`. `Tests/SpaceTransitionProbe.swift` provides a read-only 20-second gamma sampler for use during desktop swipes. It checks transfer-table stability, not physical luminance or the gesture itself.

Version 1.0's overlay-only implementation was reported to flash during three-finger Spaces transitions; 1.1 uses display gamma to remove that dependence on desktop windows. Actual three-finger gesture confirmation is separate from the automated checks. HDR video, physical unplug/replug, sleep/wake, abrupt process termination, and all Spaces configurations have not been verified. Unsupported displays retain the overlay limitation.

The build scripts work around this Mac's duplicate SwiftBridging module definition using a project-local compiler filesystem overlay. Installed developer tools are unchanged.
