import Foundation

func check(_ condition: Bool, _ message: String) {
    guard condition else { fatalError(message) }
}

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
