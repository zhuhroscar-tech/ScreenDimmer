import Foundation

/// Keeps Safari's default page zoom high on the foldable's tiny logical
/// point-size (2x native resolution makes normal pages look small) and back
/// to 100% once the foldable panel is gone, so a laptop-only session isn't
/// stuck oversized.
enum SafariZoomPolicy {
    static let connectedZoom = 1.75
    static let disconnectedZoom = 1.0
    static let key = "DefaultPageZoom"

    /// Safari is App-Sandboxed; its real preferences live in its container,
    /// not the classic ~/Library/Preferences path `defaults` normally edits.
    static func containerPlistURL(home: URL = FileManager.default.homeDirectoryForCurrentUser) -> URL {
        home.appendingPathComponent("Library/Containers/com.apple.Safari/Data/Library/Preferences/com.apple.Safari.plist")
    }
}

final class SafariZoomSync: ObservableObject {
    @Published private(set) var lastAppliedZoom: Double?
    @Published private(set) var lastError: String?
    @Published var enabled: Bool {
        didSet {
            defaults.set(enabled, forKey: "safariZoomSyncEnabled")
            if let connected = lastKnownExternal { apply(connected: connected) }
        }
    }
    private let defaults: UserDefaults
    private let plistURL: URL
    private var lastKnownExternal: Bool?

    init(defaults: UserDefaults = .standard, plistURL: URL = SafariZoomPolicy.containerPlistURL()) {
        self.defaults = defaults
        self.plistURL = plistURL
        self.enabled = defaults.object(forKey: "safariZoomSyncEnabled") as? Bool ?? true
    }

    /// Call with whether any non-built-in (foldable/external) display is
    /// currently connected. No-ops if disabled or the state hasn't changed.
    func sync(externalConnected: Bool) {
        guard lastKnownExternal != externalConnected else { return }
        lastKnownExternal = externalConnected
        guard enabled else { return }
        apply(connected: externalConnected)
    }

    private func apply(connected: Bool) {
        write(connected ? SafariZoomPolicy.connectedZoom : SafariZoomPolicy.disconnectedZoom)
    }

    @discardableResult
    func write(_ zoom: Double) -> Bool {
        var dict: [String: Any] = [:]
        var format: PropertyListSerialization.PropertyListFormat = .binary
        if let data = try? Data(contentsOf: plistURL),
           let plist = try? PropertyListSerialization.propertyList(from: data, options: [.mutableContainers], format: &format) as? [String: Any] {
            dict = plist
        }
        if let current = dict[SafariZoomPolicy.key] as? Double, abs(current - zoom) < 0.001 {
            lastAppliedZoom = zoom
            lastError = nil
            return true
        }
        dict[SafariZoomPolicy.key] = zoom
        do {
            let data = try PropertyListSerialization.data(fromPropertyList: dict, format: format, options: 0)
            try FileManager.default.createDirectory(at: plistURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            try data.write(to: plistURL, options: .atomic)
            lastAppliedZoom = zoom
            lastError = nil
            return true
        } catch {
            lastAppliedZoom = nil
            lastError = "Grant ScreenDimmer Full Disk Access in System Settings → Privacy & Security to sync Safari's zoom. (\(error.localizedDescription))"
            return false
        }
    }
}
