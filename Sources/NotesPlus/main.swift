import AppKit
import ServiceManagement
import SwiftUI
import Sparkle

if CommandLine.arguments.contains("--selftest") {
    SlashQuery.selfTest()
    MarkdownShortcut.selfTest()
    FormatBar.selfTest()
    MenuEntry.selfTest()
    Templates.selfTest()
    print("selftest ok")
    exit(0)
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let slash = SlashController()
    private let observer = NotesObserver()
    private let formatBar = FormatBar()
    private let backlinks = Backlinks()
    private var permissionTimer: Timer?
    private var settingsWindow: NSWindow?
    private let panel: NSPopover = {
        let popover = NSPopover()
        popover.behavior = .transient
        return popover
    }()
    // Checks the appcast daily (SUEnableAutomaticChecks in Info.plist) and offers to install new releases.
    private let updater = SPUStandardUpdaterController(startingUpdater: true, updaterDelegate: nil, userDriverDelegate: nil)

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem.button?.image = NSImage(systemSymbolName: "note.text", accessibilityDescription: "NotesPlus")
        statusItem.button?.target = self
        statusItem.button?.action = #selector(togglePanel)

        Templates.ensureDirectory()
        let prompt = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        if AXIsProcessTrustedWithOptions(prompt) {
            startFeatures()
        } else {
            // Start as soon as the user grants Accessibility.
            permissionTimer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] timer in
                guard AXIsProcessTrusted() else { return }
                timer.invalidate()
                self?.startFeatures()
            }
        }
    }

    private func startFeatures() {
        allowBackgroundCursor()
        slash.start()
        observer.onChange = { [weak self] in
            self?.formatBar.update()
            self?.backlinks.update(avoiding: self?.formatBar.visibleFrame)
        }
        formatBar.onButtonPressed = { [weak self] in self?.observer.onChange() }
        observer.start()
    }

    /// A background app's NSCursor changes are ignored unless this private WindowServer property is set;
    /// without it the format bar can't show the pointing hand while Notes is frontmost.
    private func allowBackgroundCursor() {
        typealias DefaultConnection = @convention(c) () -> Int32
        typealias SetProperty = @convention(c) (Int32, Int32, CFString, CFTypeRef) -> Int32
        guard let main = dlsym(UnsafeMutableRawPointer(bitPattern: -2), "_CGSDefaultConnection"),
              let set = dlsym(UnsafeMutableRawPointer(bitPattern: -2), "CGSSetConnectionProperty") else { return }
        let connection = unsafeBitCast(main, to: DefaultConnection.self)()
        _ = unsafeBitCast(set, to: SetProperty.self)(connection, connection, "SetsCursorInBackground" as CFString, kCFBooleanTrue)
    }

    @objc private func togglePanel() {
        guard let button = statusItem.button else { return }
        if panel.isShown { panel.performClose(nil); return }
        panel.contentViewController = NSHostingController(rootView: MenuPanelView(actions: menuActions()))
        // SwiftUI sizes the popover after it is shown, which makes it grow upward off the screen; fix the size first.
        panel.contentSize = MenuPanelView.size
        panel.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
    }

    private func menuActions() -> MenuActions {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "?"
        return MenuActions(
            version: version,
            setFeature: { [weak self] feature, on in
                Settings.set(feature, on)
                self?.slash.hide()
                self?.observer.onChange()  // Panels of a feature that was just turned off close right away.
            },
            setLogin: { [weak self] on in self?.setLogin(on) ?? false },
            loginEnabled: { SMAppService.mainApp.status == .enabled },
            run: { [weak self] entry in self?.run(entry) }
        )
    }

    private func run(_ entry: MenuEntry) {
        panel.performClose(nil)
        switch entry {
        case .settings: openSettings()
        case .update: updater.checkForUpdates(nil)
        case .quit: NSApp.terminate(nil)
        default: break
        }
    }

    private func openSettings() {
        let view = SettingsView(actions: menuActions()) { [weak self] in self?.observer.onChange() }
        let window = settingsWindow ?? NSWindow(contentRect: .zero, styleMask: [.titled, .closable], backing: .buffered, defer: false)
        window.title = "NotesPlus 설정"
        window.contentViewController = NSHostingController(rootView: view)
        window.isReleasedWhenClosed = false
        if !window.isVisible { window.center() }
        settingsWindow = window
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }

    /// Returns whether the login item is enabled afterwards.
    private func setLogin(_ on: Bool) -> Bool {
        do {
            if on { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
        } catch {
            NSLog("NotesPlus: login item change failed: \(error)")
            NSSound.beep()
        }
        // Registering can succeed yet wait for the user to approve it in System Settings.
        if SMAppService.mainApp.status == .requiresApproval { SMAppService.openSystemSettingsLoginItems() }
        return SMAppService.mainApp.status == .enabled
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
