import AppKit
import Combine
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    let model = PrompterModel()
    private let mic = MicMonitor()
    private var prompter: PrompterController!
    private var statusItem: NSStatusItem!
    private var settingsWindow: NSWindow?
    private var bag = Set<AnyCancellable>()

    func applicationDidFinishLaunching(_ notification: Notification) {
        prompter = PrompterController(model: model)
        setUpStatusItem()

        mic.onLevel = { [weak self] level in self?.model.rawLevel = level }
        mic.onDenied = { [weak self] in self?.model.micDenied = true }

        // The microphone runs only while a feature needs it.
        Publishers.CombineLatest(model.$glowEnabled, model.$voicePaced)
            .sink { [weak self] glow, paced in
                guard let self else { return }
                if glow || paced { self.mic.start() } else { self.mic.stop(); self.model.rawLevel = 0 }
            }
            .store(in: &bag)

        if !UserDefaults.standard.bool(forKey: "launchedBefore") {
            UserDefaults.standard.set(true, forKey: "launchedBefore")
            openSettings()
        }
        if ProcessInfo.processInfo.environment["EYELINE_AUTOPLAY"] == "1" { model.restart() }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        model.isVisible = true
        openSettings()
        return true
    }

    // MARK: Menu bar

    private func setUpStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.image = NSImage(systemSymbolName: "text.viewfinder", accessibilityDescription: "EyeLine")
        let menu = NSMenu()
        menu.delegate = self
        statusItem.menu = menu
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()
        add(to: menu, model.isVisible ? "Hide Prompter" : "Show Prompter", #selector(toggleVisible), "h")
        add(to: menu, model.isPlaying ? "Pause" : "Play", #selector(togglePlay), "p")
        add(to: menu, "Restart from Top", #selector(restart), "r")
        menu.addItem(.separator())
        add(to: menu, "Script & Settings…", #selector(openSettings), ",")
        menu.addItem(.separator())
        add(to: menu, "Quit EyeLine", #selector(quit), "q")
    }

    private func add(to menu: NSMenu, _ title: String, _ action: Selector, _ key: String) {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: key)
        item.target = self
        menu.addItem(item)
    }

    @objc private func toggleVisible() { model.isVisible.toggle() }
    @objc private func togglePlay() { model.isVisible = true; model.togglePlay() }
    @objc private func restart() { model.isVisible = true; model.restart() }
    @objc private func quit() { NSApp.terminate(nil) }

    @objc func openSettings() {
        if settingsWindow == nil {
            let window = NSWindow(contentViewController: NSHostingController(rootView: SettingsView(model: model)))
            window.title = "EyeLine"
            window.styleMask = [.titled, .closable, .miniaturizable, .resizable]
            window.setContentSize(NSSize(width: 500, height: 560))
            window.isReleasedWhenClosed = false
            window.center()
            settingsWindow = window
        }
        NSApp.activate(ignoringOtherApps: true)
        settingsWindow?.makeKeyAndOrderFront(nil)
    }
}

MainActor.assumeIsolated {
    if Snapshot.runIfRequested() { exit(0) }
    if MicTest.runIfRequested() { exit(0) }
    let app = NSApplication.shared
    let delegate = AppDelegate()
    app.delegate = delegate
    app.setActivationPolicy(.accessory)
    app.run()
}
