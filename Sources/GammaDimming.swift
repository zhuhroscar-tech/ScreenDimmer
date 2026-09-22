import CoreGraphics

struct GammaTable {
    var red: [Float]
    var green: [Float]
    var blue: [Float]

    func scaled(_ factor: Double) -> GammaTable {
        let scale = Float(min(1, max(0.15, factor)))
        return GammaTable(red: red.map { $0 * scale }, green: green.map { $0 * scale }, blue: blue.map { $0 * scale })
    }

    func matches(_ other: GammaTable) -> Bool {
        func equal(_ a: [Float], _ b: [Float]) -> Bool {
            a.count == b.count && zip(a, b).allSatisfy { abs($0 - $1) < 0.002 }
        }
        return equal(red, other.red) && equal(green, other.green) && equal(blue, other.blue)
    }

    static func read(_ display: CGDirectDisplayID) -> GammaTable? {
        let capacity = CGDisplayGammaTableCapacity(display)
        guard capacity > 1, capacity <= 65536 else { return nil }
        var red = [Float](repeating: 0, count: Int(capacity))
        var green = red
        var blue = red
        var count: UInt32 = 0
        guard CGGetDisplayTransferByTable(display, capacity, &red, &green, &blue, &count) == .success,
              count > 1, count <= capacity else { return nil }
        let table = GammaTable(red: Array(red.prefix(Int(count))), green: Array(green.prefix(Int(count))), blue: Array(blue.prefix(Int(count))))
        guard (table.red + table.green + table.blue).allSatisfy({ $0.isFinite && $0 >= 0 && $0 <= 1 }),
              table.red.contains(where: { $0 > 0.1 }) else { return nil }
        return table
    }

    static func write(_ display: CGDirectDisplayID, _ table: GammaTable) -> Bool {
        CGSetDisplayTransferByTable(display, UInt32(table.red.count), table.red, table.green, table.blue) == .success
    }
}

/// Baselines are captured once per dimming session, never from our own dimmed ramp.
/// No desktop/Space window participates in this path.
final class GammaDimming {
    private var originals: [CGDirectDisplayID: GammaTable] = [:]
    private var applied: [CGDirectDisplayID: GammaTable] = [:]
    private let read: (CGDirectDisplayID) -> GammaTable?
    private let write: (CGDirectDisplayID, GammaTable) -> Bool

    init(read: @escaping (CGDirectDisplayID) -> GammaTable? = GammaTable.read,
         write: @escaping (CGDirectDisplayID, GammaTable) -> Bool = GammaTable.write) {
        self.read = read
        self.write = write
    }

    func setFactor(_ factor: Double, for display: CGDirectDisplayID) -> Bool {
        if factor >= 1 { return restore(display) }
        guard let baseline = originals[display] ?? read(display) else { return false }
        originals[display] = baseline
        let target = baseline.scaled(factor)
        guard write(display, target), let actual = read(display), actual.matches(target) else { return false }
        applied[display] = target
        return true
    }

    func matchesApplied(_ display: CGDirectDisplayID) -> Bool {
        guard let target = applied[display], let actual = read(display) else { return false }
        return actual.matches(target)
    }

    @discardableResult func restore(_ display: CGDirectDisplayID) -> Bool {
        guard let baseline = originals[display] else { return true }
        guard write(display, baseline), let actual = read(display), actual.matches(baseline) else { return false }
        originals.removeValue(forKey: display)
        applied.removeValue(forKey: display)
        return true
    }

    func restoreAll() {
        for id in Array(originals.keys) { restore(id) }
    }

    func removeDisconnected(keeping connected: Set<CGDirectDisplayID>) {
        for id in Array(originals.keys) where !connected.contains(id) {
            // A detached display cannot be written. Do not reuse its stale ramp
            // if macOS later recycles the numeric display identifier.
            originals.removeValue(forKey: id)
            applied.removeValue(forKey: id)
        }
    }
}
