import AppKit
import SwiftUI
import QuartzCore
import Carbon

struct Display: Identifiable {
    let id: String
    let displayID: CGDirectDisplayID
    let screen: NSScreen
    let builtIn: Bool
    var name: String { screen.localizedName }
    var details: String {
        "\(Int(screen.frame.width)) × \(Int(screen.frame.height)) points · \(builtIn ? "Built-in" : "External")"
    }
}

final class ShadeWindow: NSWindow {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }

    init(screen: NSScreen) {
        super.init(contentRect: screen.frame, styleMask: .borderless, backing: .buffered, defer: false)
        isReleasedWhenClosed = false
        backgroundColor = .black
        isOpaque = false
        hasShadow = false
        ignoresMouseEvents = true
        hidesOnDeactivate = false
        isExcludedFromWindowsMenu = true
        level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.screenSaverWindow)) - 1)
        collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle, .fullScreenAuxiliary, .canJoinAllApplications]
        animationBehavior = .none
        alphaValue = 0
        setFrame(screen.frame, display: true)
    }
}

final class Dimmer: ObservableObject {
    @Published var brightness: Double = 100 {
        didSet {
            let safe = DimmingPolicy.clamp(brightness)
            if safe != brightness { brightness = safe }
            defaults.set(brightness, forKey: "brightness")
            apply()
        }
    }
    @Published var paused = false { didSet { apply() } }
    @Published var displays: [Display] = []
    @Published var selection: [String: Bool] = [:]
    @Published var shortcutAvailable = false
    private let defaults: UserDefaults
    private var shades: [String: ShadeWindow] = [:]
    private var observers: [NSObjectProtocol] = []
    var onChange: (() -> Void)?

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        selection = defaults.dictionary(forKey: "selection") as? [String: Bool] ?? [:]
        if defaults.object(forKey: "brightness") != nil {
            brightness = DimmingPolicy.clamp(defaults.double(forKey: "brightness"))
        }
        refresh()
        observers.append(NotificationCenter.default.addObserver(forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main) { [weak self] _ in
            self?.refresh()
        })
        for name in [NSWorkspace.screensDidWakeNotification, NSWorkspace.didWakeNotification, NSWorkspace.activeSpaceDidChangeNotification] {
            observers.append(NSWorkspace.shared.notificationCenter.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                self?.refresh()
            })
        }
    }

    func isSelected(_ display: Display) -> Bool {
        DimmingPolicy.selected(saved: selection[display.id], builtIn: display.builtIn)
    }

    func select(_ display: Display, _ enabled: Bool) {
        selection[display.id] = enabled
        defaults.set(selection, forKey: "selection")
        apply()
    }

    func restore() {
        brightness = 100
        paused = false
    }

    func refresh() {
        displays = NSScreen.screens.compactMap { screen in
            guard let number = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber else { return nil }
            let displayID = number.uint32Value
            let id: String
            if let uuid = CGDisplayCreateUUIDFromDisplayID(displayID)?.takeRetainedValue(),
               let value = CFUUIDCreateString(nil, uuid) {
                id = value as String
            } else {
                id = "display-\(displayID)"
            }
            return Display(id: id, displayID: displayID, screen: screen, builtIn: CGDisplayIsBuiltin(displayID) != 0)
        }
        let current = Set(displays.map(\.id))
        for id in Array(shades.keys) where !current.contains(id) {
            shades.removeValue(forKey: id)?.close()
        }
        for display in displays {
            if shades[display.id] == nil { shades[display.id] = ShadeWindow(screen: display.screen) }
            shades[display.id]?.setFrame(display.screen.frame, display: true)
        }
        apply()
    }

    func apply() {
        // One main-thread transaction, one shared value, no hardware/gamma crossover.
        NSAnimationContext.beginGrouping()
        NSAnimationContext.current.duration = 0
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        for display in displays {
            guard let shade = shades[display.id] else { continue }
            let opacity = DimmingPolicy.opacity(brightness: brightness, selected: isSelected(display), paused: paused)
            shade.alphaValue = opacity
            if opacity > 0 { shade.orderFrontRegardless() } else { shade.orderOut(nil) }
        }
        CATransaction.commit()
        NSAnimationContext.endGrouping()
        onChange?()
    }

    func removeShades() {
        for shade in shades.values { shade.close() }
        shades.removeAll()
    }

    func snapshot() -> [[String: Any]] {
        displays.map { display in
            let shade = shades[display.id]!
            return ["name": display.name, "builtIn": display.builtIn, "selected": isSelected(display),
                    "displayID": display.displayID, "frame": NSStringFromRect(display.screen.frame),
                    "overlayFrame": NSStringFromRect(shade.frame), "opacity": Double(shade.alphaValue),
                    "visible": shade.isVisible, "clickThrough": shade.ignoresMouseEvents]
        }
    }
}

struct Controls: View {
    @ObservedObject var model: Dimmer
    private let accent = Color(red: 0.39, green: 0.89, blue: 0.77)

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            HStack(spacing: 12) {
                Image(systemName: "sun.max.fill").font(.system(size: 25)).foregroundStyle(accent)
                    .frame(width: 48, height: 48).background(accent.opacity(0.12), in: RoundedRectangle(cornerRadius: 14))
                VStack(alignment: .leading, spacing: 4) {
                    Text("ScreenDimmer").font(.system(size: 23, weight: .semibold))
                    Text("Two panels. One brightness.").font(.system(size: 12)).foregroundStyle(.secondary)
                }
                Spacer()
                Text(model.paused ? "PAUSED" : "LINKED")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundStyle(model.paused ? .orange : accent)
                    .padding(.horizontal, 10).padding(.vertical, 6)
                    .background(.white.opacity(0.06), in: Capsule())
            }

            VStack(spacing: 17) {
                HStack(spacing: 22) {
                    VStack(spacing: 4) {
                        panel
                        panel
                    }.padding(7).background(.black.opacity(0.35), in: RoundedRectangle(cornerRadius: 10))
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(alignment: .firstTextBaseline, spacing: 2) {
                            Text("\(Int(model.brightness.rounded()))").font(.system(size: 54, weight: .light, design: .rounded)).monospacedDigit()
                            Text("%").font(.system(size: 23)).foregroundStyle(.secondary)
                        }
                        Text(model.paused ? "Dimming is paused" : "Shared brightness").font(.system(size: 12)).foregroundStyle(.secondary)
                    }
                    Spacer()
                }
                HStack(spacing: 12) {
                    Image(systemName: "sun.min").foregroundStyle(.secondary)
                    Slider(value: $model.brightness, in: DimmingPolicy.minimum...100, step: 1)
                        .tint(accent).accessibilityLabel("Shared brightness")
                    Image(systemName: "sun.max.fill").foregroundStyle(accent)
                }
                HStack(spacing: 8) {
                    ForEach([25, 50, 75, 100], id: \.self) { value in
                        Button { model.brightness = Double(value); model.paused = false } label: {
                            Text("\(value)%").font(.system(size: 12, weight: .medium)).frame(maxWidth: .infinity).padding(.vertical, 7)
                                .background(Int(model.brightness) == value ? accent.opacity(0.2) : .white.opacity(0.05), in: RoundedRectangle(cornerRadius: 7))
                        }.buttonStyle(.plain).accessibilityLabel("Set brightness to \(value) percent")
                    }
                }
            }.padding(20).background(.white.opacity(0.045), in: RoundedRectangle(cornerRadius: 18))

            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("LINKED DISPLAYS").font(.system(size: 10, weight: .semibold, design: .monospaced)).foregroundStyle(.secondary)
                    Spacer()
                    Button { model.refresh() } label: { Image(systemName: "arrow.clockwise") }
                        .buttonStyle(.plain).help("Refresh connected displays").accessibilityLabel("Refresh displays")
                }
                ScrollView {
                    VStack(spacing: 10) {
                        ForEach(model.displays) { display in
                            HStack(spacing: 12) {
                                Image(systemName: display.builtIn ? "laptopcomputer" : "display").font(.system(size: 21)).frame(width: 30).foregroundStyle(.secondary)
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(display.name).font(.system(size: 13, weight: .medium))
                                    Text(display.details).font(.system(size: 10)).foregroundStyle(.secondary)
                                }
                                Spacer()
                                Toggle("Link \(display.name)", isOn: Binding(get: { model.isSelected(display) }, set: { model.select(display, $0) }))
                                    .labelsHidden().toggleStyle(.switch).tint(accent).controlSize(.small)
                            }.padding(11).background(.white.opacity(0.035), in: RoundedRectangle(cornerRadius: 10))
                        }
                    }
                }.frame(height: min(150, CGFloat(max(1, model.displays.count)) * 62))
                if !model.displays.contains(where: { model.isSelected($0) }) {
                    Text("Select a display above to start dimming.").font(.system(size: 11)).foregroundStyle(.orange)
                }
            }

            Text("Dims the entire selected screen evenly. If another brightness app is active, set it to 100% and quit it first.")
                .font(.system(size: 11)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)

            HStack {
                Button(model.paused ? "Resume" : "Pause") { model.paused.toggle() }.buttonStyle(.bordered)
                Spacer()
                Button("Restore 100%") { model.restore() }.buttonStyle(.borderedProminent).tint(accent).foregroundStyle(.black)
            }
            Text(model.shortcutAvailable ? "Restore anytime: ⌃⌥⌘0  ·  Closing this window keeps dimming on." : "Use the menu bar sun to reopen controls or quit.")
                .font(.system(size: 10)).foregroundStyle(.secondary)
        }
        .padding(26).frame(width: 460)
        .background(Color(red: 0.065, green: 0.085, blue: 0.105))
        .preferredColorScheme(.dark)
    }

    private var panel: some View {
        RoundedRectangle(cornerRadius: 4)
            .fill(LinearGradient(colors: [accent, Color(red: 0.13, green: 0.45, blue: 0.58)], startPoint: .topLeading, endPoint: .bottomTrailing))
            .overlay(Color.black.opacity(model.paused ? 0 : 1 - model.brightness / 100))
            .clipShape(RoundedRectangle(cornerRadius: 4)).frame(width: 77, height: 39)
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    var model: Dimmer!
    var window: NSWindow!
    var status: NSStatusItem!
    var brightnessItem: NSMenuItem!
    var pauseItem: NSMenuItem!
    var hotKey: EventHotKeyRef?
    var eventHandler: EventHandlerRef?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let args = CommandLine.arguments
        if args.contains("--diagnostics") || args.contains("--integration-test") {
            runDiagnostics(integration: args.contains("--integration-test"))
            return
        }
        if let duplicate = NSRunningApplication.runningApplications(withBundleIdentifier: Bundle.main.bundleIdentifier ?? "local.oscar.ScreenDimmer").first(where: { $0.processIdentifier != ProcessInfo.processInfo.processIdentifier }) {
            duplicate.activate(options: [.activateAllWindows])
            NSApp.terminate(nil)
            return
        }
        model = Dimmer()
        createMenu()
        registerRestoreShortcut()
        let content = NSHostingView(rootView: Controls(model: model))
        window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 460, height: 610), styleMask: [.titled, .closable, .miniaturizable], backing: .buffered, defer: false)
        window.title = "ScreenDimmer"
        window.titlebarAppearsTransparent = true
        window.backgroundColor = NSColor(calibratedRed: 0.065, green: 0.085, blue: 0.105, alpha: 1)
        window.contentView = content
        window.setContentSize(content.fittingSize)
        window.isReleasedWhenClosed = false
        window.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.screenSaverWindow)))
        window.center()
        model.onChange = { [weak self] in self?.updateMenu() }
        updateMenu()
        showControls()
    }

    func createMenu() {
        status = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        status.button?.image = NSImage(systemSymbolName: "sun.max.fill", accessibilityDescription: "ScreenDimmer")
        let menu = NSMenu()
        brightnessItem = NSMenuItem(title: "", action: nil, keyEquivalent: "")
        menu.addItem(brightnessItem)
        add(menu, "Open ScreenDimmer…", #selector(showControls))
        menu.addItem(.separator())
        for value in [25, 50, 75, 100] {
            let item = add(menu, "Brightness \(value)%", #selector(preset(_:)))
            item.tag = value
        }
        pauseItem = add(menu, "Pause", #selector(togglePause))
        add(menu, "Restore 100%", #selector(restore))
        menu.addItem(.separator())
        add(menu, "Quit ScreenDimmer", #selector(quit), key: "q")
        status.menu = menu
    }

    @discardableResult func add(_ menu: NSMenu, _ title: String, _ action: Selector, key: String = "") -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: key)
        item.target = self
        menu.addItem(item)
        return item
    }

    func updateMenu() {
        brightnessItem.title = model.paused ? "Dimming paused" : "Shared brightness: \(Int(model.brightness))%"
        pauseItem.title = model.paused ? "Resume dimming" : "Pause dimming"
        status.button?.toolTip = brightnessItem.title
    }

    @objc func showControls() { window?.makeKeyAndOrderFront(nil); NSApp.activate(ignoringOtherApps: true) }
    @objc func preset(_ sender: NSMenuItem) { model.brightness = Double(sender.tag); model.paused = false }
    @objc func togglePause() { model.paused.toggle() }
    @objc func restore() { model.restore() }
    @objc func quit() { NSApp.terminate(nil) }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool { showControls(); return true }
    func applicationWillTerminate(_ notification: Notification) {
        model?.removeShades()
        if let hotKey { UnregisterEventHotKey(hotKey) }
        if let eventHandler { RemoveEventHandler(eventHandler) }
    }

    func registerRestoreShortcut() {
        var type = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        let installed = InstallEventHandler(GetApplicationEventTarget(), { _, _, context in
            guard let context else { return OSStatus(eventNotHandledErr) }
            Unmanaged<AppDelegate>.fromOpaque(context).takeUnretainedValue().restore()
            return noErr
        }, 1, &type, Unmanaged.passUnretained(self).toOpaque(), &eventHandler)
        if installed == noErr {
            let result = RegisterEventHotKey(UInt32(kVK_ANSI_0), UInt32(controlKey | optionKey | cmdKey), EventHotKeyID(signature: 0x5344494D, id: 1), GetApplicationEventTarget(), 0, &hotKey)
            model.shortcutAvailable = result == noErr
        }
    }

    func runDiagnostics(integration: Bool) {
        let suite = "local.oscar.ScreenDimmer.test.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        let probe = Dimmer(defaults: defaults)
        var steps: [[String: Any]] = []
        if integration {
            precondition(!probe.displays.isEmpty, "Integration tests require access to a graphical macOS session")
            for value in [100.0, 75, 50, 25, 15] {
                probe.brightness = value
                for display in probe.displays {
                    let expected = DimmingPolicy.opacity(brightness: value, selected: probe.isSelected(display), paused: false)
                    let row = probe.snapshot().first { $0["displayID"] as? UInt32 == display.displayID }!
                    precondition(abs((row["opacity"] as! Double) - expected) < 0.0001)
                    precondition(row["frame"] as! String == row["overlayFrame"] as! String)
                    precondition(row["clickThrough"] as! Bool)
                    precondition(row["visible"] as! Bool == (expected > 0))
                }
                steps.append(["brightness": value, "displays": probe.snapshot()])
            }
            probe.paused = true
            precondition(probe.snapshot().allSatisfy { ($0["visible"] as! Bool) == false })
            probe.paused = false
            // Refresh exercises the same path used on rotation, hotplug, wake and Space changes.
            probe.refresh()
            probe.restore()
            precondition(probe.snapshot().allSatisfy { ($0["visible"] as! Bool) == false })
        }
        let result: [String: Any] = ["displays": probe.snapshot(), "steps": steps, "integrationPassed": integration]
        if let data = try? JSONSerialization.data(withJSONObject: result, options: [.prettyPrinted, .sortedKeys]), let text = String(data: data, encoding: .utf8) { print(text) }
        probe.removeShades()
        defaults.removePersistentDomain(forName: suite)
        NSApp.terminate(nil)
    }
}

let app = NSApplication.shared
app.setActivationPolicy(.accessory)
let delegate = AppDelegate()
app.delegate = delegate
app.run()
