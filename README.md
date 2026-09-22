# ScreenDimmer

A native macOS menu bar app that dims all selected displays with one continuous slider. Built for a foldable Sculptor whose two physical panels appear as a single macOS display.

## Use

1. Set your previous brightness app to 100%, then quit it. Start with both physical panels at the same baseline brightness if your monitor allows it.
2. Open ScreenDimmer from Applications (or `build/ScreenDimmer.app` after building locally).
3. Leave Sculptor selected and move the slider. Both physical halves receive the same dimming amount across the entire range.
4. Use the sun icon in the menu bar to reopen the controls. Closing the window keeps the app running; Quit removes its dimming.

The built-in MacBook screen is excluded by default. External screens are selected by default, including newly connected ones. Display choices and brightness are remembered. Pause temporarily removes the dimming. Restore 100% removes it permanently until the slider is changed again. Control–Option–Command–0 restores 100% globally when the shortcut is available.

## Why this approach

On this Mac, macOS reported a built-in Color LCD plus one Sculptor at 3200 × 2560, rotated 90°. This establishes that the two physical halves are one logical external display. It does not establish the monitor firmware's exact brightness behavior.

The reported first-half/second-half slider behavior is consistent with a hardware control quirk or an app switching between hardware and software control. [MonitorControl documents its combined hardware/software dimming](https://github.com/MonitorControl/MonitorControl#readme). ScreenDimmer avoids that crossover: it puts one uniform, black, click-through window over each selected macOS screen. Opacity is `1 - brightness / 100` for the full slider range. There is no special behavior at 50% and no DDC or gamma-table modification.

This is software dimming: it darkens the image, not the physical backlight, and does not reduce backlight power. Percentages represent the software setting, not measured luminance. It cannot brighten beyond the monitor's current baseline or fix an existing physical mismatch between panels. Screenshots and screen sharing may include the shade. The mouse pointer and some system-controlled surfaces can remain brighter. Protected video, HDR and every full-screen/Spaces configuration need testing on the actual content you use.

## Build and verify

Requires Apple Silicon, macOS 14+, and Xcode Command Line Tools. No third-party packages, network service, administrator access, Accessibility permission, or Screen Recording permission are required by the app.

```sh
bash scripts/build.sh
bash scripts/test.sh
build/ScreenDimmer.app/Contents/MacOS/ScreenDimmer --diagnostics
build/ScreenDimmer.app/Contents/MacOS/ScreenDimmer --integration-test
open build/ScreenDimmer.app
```

To install a local build, copy `build/ScreenDimmer.app` into Applications. To use a packaged release, unzip `ScreenDimmer-macOS-arm64.zip`, then copy `ScreenDimmer.app` into Applications. The app is built for Apple Silicon Macs running macOS 14 or later. It is locally signed, not Apple-notarized; macOS may require manual approval for a copy downloaded on another Mac.

Diagnostics need access to the logged-in macOS graphical session. Integration tests briefly exercise real overlay windows at several brightness levels, verify full-screen bounds, selection, opacity and click-through, then remove them. They use isolated preferences. Do not run the integration test while another ScreenDimmer instance is dimming, because their overlays would stack temporarily.

Display frames come from `NSScreen.frame`, so negative origins, rotation and scaled displays use their current macOS geometry. Windows rebuild on display changes and refresh after wake/Space changes. The 15% minimum prevents full blackout. Quitting or a process crash removes the windows without leaving modified display gamma or hardware settings.

Uses Apple's [NSWindow API](https://developer.apple.com/documentation/appkit/nswindow) and [overlay collection behavior](https://developer.apple.com/documentation/appkit/nswindow/collectionbehavior-swift.struct/canjoinallapplications). The build is locally ad-hoc signed; it is not notarized for distribution to other Macs.
