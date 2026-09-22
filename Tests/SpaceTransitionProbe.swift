// Read-only sampler. Run while the app is dimming, then switch desktops.
// This verifies transfer-table stability, not measured physical luminance.
import Foundation
import CoreGraphics

@main struct SpaceTransitionProbe {
    static func main() {
        var ids = [CGDirectDisplayID](repeating: 0, count: 32)
        var count: UInt32 = 0
        precondition(CGGetOnlineDisplayList(32, &ids, &count) == .success)
        let displays = Array(ids.prefix(Int(count)))
        let baseline = Dictionary(uniqueKeysWithValues: displays.compactMap { id in GammaTable.read(id).map { (id, $0) } })
        var changes = [UInt32: Int]()
        var failures = 0
        var samples = 0
        let end = Date().addingTimeInterval(20)
        while Date() < end {
            for (id, expected) in baseline {
                guard let actual = GammaTable.read(id) else { failures += 1; continue }
                if !actual.matches(expected) { changes[id, default: 0] += 1 }
            }
            samples += 1
            Thread.sleep(forTimeInterval: 0.02)
        }
        let result: [String: Any] = ["samples": samples, "displayCount": baseline.count,
            "changedSamples": changes.map { ["displayID": $0.key, "count": $0.value] }, "readFailures": failures,
            "stable": !baseline.isEmpty && changes.isEmpty && failures == 0]
        let data = try! JSONSerialization.data(withJSONObject: result, options: [.prettyPrinted, .sortedKeys])
        print(String(data: data, encoding: .utf8)!)
    }
}
