import Foundation

enum DimmingPolicy {
    static let minimum = 15.0

    static func clamp(_ brightness: Double) -> Double {
        brightness.isFinite ? min(100, max(minimum, brightness)) : 100
    }

    static func opacity(brightness: Double, selected: Bool, paused: Bool) -> Double {
        selected && !paused ? 1 - clamp(brightness) / 100 : 0
    }

    static func selected(saved: Bool?, builtIn: Bool) -> Bool {
        saved ?? !builtIn
    }
}
