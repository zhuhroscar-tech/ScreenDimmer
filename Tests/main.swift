import Foundation

func check(_ condition: Bool, _ message: String) {
    guard condition else { fatalError(message) }
}

func readText(_ path: String) -> String {
    guard let data = FileManager.default.contents(atPath: path), let text = String(data: data, encoding: .utf8) else {
        fatalError("Missing or unreadable file: \(path)")
    }
    return text
}

for requiredPath in ["README.md", "CHANGELOG.md", "LICENSE", ".github/workflows/ci.yml"] {
    check(FileManager.default.fileExists(atPath: requiredPath), "Missing required repository file: \(requiredPath)")
}
let readme = readText("README.md")
let changelog = readText("CHANGELOG.md")
let info = readText("Info.plist")
check(readme.contains("[CHANGELOG.md](CHANGELOG.md)"), "README must link release history")
check(readme.contains("[LICENSE](LICENSE)"), "README must link license terms")
check(changelog.contains("## v1.2.0"), "Changelog must document current app version")
check(info.contains("<key>CFBundleShortVersionString</key><string>1.2.0</string>"), "Info.plist version must match current changelog entry")
print("PASS: repository metadata, release-history links, license link, CI workflow, version parity")

for value in stride(from: 15.0, through: 100, by: 1) {
    let alpha = DimmingPolicy.opacity(brightness: value, selected: true, paused: false)
    check(abs(alpha - (1 - value / 100)) < 0.000001, "Discontinuous brightness at \(value)")
    check(DimmingPolicy.opacity(brightness: value, selected: false, paused: false) == 0, "Unselected screen was dimmed")
    check(DimmingPolicy.opacity(brightness: value, selected: true, paused: true) == 0, "Pause failed")
}
check(DimmingPolicy.clamp(-100) == 15, "Blackout protection failed")
check(DimmingPolicy.clamp(150) == 100, "Upper bound failed")
check(DimmingPolicy.clamp(.nan) == 100, "Invalid stored value failed")
check(DimmingPolicy.clamp(.infinity) == 100, "Infinity failed")
check(!DimmingPolicy.selected(saved: nil, builtIn: true), "Built-in display must default off")
check(DimmingPolicy.selected(saved: nil, builtIn: false), "External display must default on")
check(!DimmingPolicy.selected(saved: false, builtIn: false), "Saved opt-out failed")
check(DimmingPolicy.selected(saved: true, builtIn: true), "Saved opt-in failed")
print("PASS: continuous brightness across 50%, selection, pause, invalid values, blackout protection")

let baseline = GammaTable(red: [0, 0.2, 0.8, 1], green: [0, 0.3, 0.7, 0.95], blue: [0, 0.1, 0.6, 0.9])
var hardware: [UInt32: GammaTable] = [1: baseline, 2: baseline]
var failWrites = false
let gamma = GammaDimming(read: { hardware[$0] }, write: { id, table in
    if failWrites { return false }
    hardware[id] = table
    return true
})
check(gamma.setFactor(0.5, for: 2), "Gamma apply failed")
check(hardware[2]!.matches(baseline.scaled(0.5)), "Wrong gamma ramp")
for _ in 0..<10 { check(gamma.setFactor(0.5, for: 2), "Repeated apply failed") }
check(hardware[2]!.matches(baseline.scaled(0.5)), "Space refresh compounded dimming")
check(hardware[1]!.matches(baseline), "Unselected display changed")
check(gamma.setFactor(0.75, for: 2), "Brightness adjustment failed")
check(hardware[2]!.matches(baseline.scaled(0.75)), "Original calibration was lost")
failWrites = true
check(!gamma.restore(2), "Failed restoration incorrectly reported success")
failWrites = false
check(gamma.restore(2), "Restoration retry failed")
check(hardware[2]!.matches(baseline), "Original RGB tables not restored")
check(!gamma.setFactor(0.5, for: 999), "Unsupported gamma must fall back")
_ = gamma.setFactor(0.25, for: 2)
gamma.removeDisconnected(keeping: [1])
hardware[2] = baseline.scaled(0.9)
check(gamma.setFactor(0.5, for: 2), "Reconnect failed")
check(hardware[2]!.matches(baseline.scaled(0.9).scaled(0.5)), "Reconnected screen used stale calibration")
gamma.restoreAll()
check(hardware[2]!.matches(baseline.scaled(0.9)), "Quit failed to restore new baseline")
print("PASS: gamma readback, no compounded dimming, independent displays, calibration restore, failed restore retry, unsupported display, reconnect")
