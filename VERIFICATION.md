# Verification

Verified on this Mac running macOS 15.7.7 with the connected Sculptor.

- Release build and ad-hoc signature verification passed.
- Policy tests passed for all integer settings from 15% to 100%, including the 50% boundary, pause, display selection, invalid values and minimum brightness.
- Live integration tests passed at 100%, 75%, 50%, 25% and 15%.
- Sculptor overlay exactly matched its full logical frame: origin (-3200, -1436), size 3200 × 2560.
- Built-in display received no dimming with the default selection.
- All overlay windows ignored mouse input.
- Pause and Restore removed the overlays; refreshing screen geometry preserved correct operation.
- Launched the app and inspected its actual accessibility tree and rendered window. Both connected displays and the shared slider were present. The global restore shortcut registered successfully.
- The user began adjusting brightness and display selection during the interface check; those settings were preserved.

Raw integration results are in `build/integration-results.json`. These verify software window coverage and opacity, not physical luminance measurements. Physical unplug/replug, sleep/wake, HDR video, and every full-screen/Spaces configuration have not been manually verified.

The build scripts work around this Mac's duplicate SwiftBridging module definition using a project-local compiler filesystem overlay. Installed developer tools are unchanged.
