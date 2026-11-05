import AppKit
import ServiceManagement
import Sparkle

if CommandLine.arguments.contains("--selftest") {
    SlashQuery.selfTest()
    MarkdownShortcut.selfTest()
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
    // Checks the appcast daily (SUEnableAutomaticChecks in Info.plist) and offers to install new releases.
    private let updater = SPUStandardUpdaterController(startingUpdater: true, updaterDelegate: nil, userDriverDelegate: nil)

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem.button?.image = NSImage(systemSymbolName: "note.text", accessibilityDescription: "NotesPlus")
        let menu = NSMenu()
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "?"
        menu.addItem(withTitle: "NotesPlus \(version)", action: nil, keyEquivalent: "")
        menu.addItem(withTitle: "업데이트 확인…", action: #selector(SPUStandardUpdaterController.checkForUpdates(_:)), keyEquivalent: "").target = updater
        menu.addItem(.separator())
        for feature in Settings.Feature.allCases {
            let item = menu.addItem(withTitle: feature.title, action: #selector(toggleFeature(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = feature
            item.state = Settings.isOn(feature) ? .on : .off
        }
        // Tags: 1 = show/hide row, 2 = separator-after row (reset needs to tell them apart).
        let barMenu = NSMenu()
        barMenu.addItem(.sectionHeader(title: "표시"))
        for button in FormatBar.buttons {
            let item = barMenu.addItem(withTitle: button.help, action: #selector(toggleBarItem(_:)), keyEquivalent: "")
            item.target = self
            item.tag = 1
            item.representedObject = button.icon
            item.state = Settings.hiddenBarItems.contains(button.icon) ? .off : .on
        }
        barMenu.addItem(.sectionHeader(title: "뒤에 구분선"))
        for button in FormatBar.buttons {
            let item = barMenu.addItem(withTitle: "\(button.help) 뒤", action: #selector(toggleBarDivider(_:)), keyEquivalent: "")
            item.target = self
            item.tag = 2
            item.representedObject = button.icon
            item.state = Settings.dividerAfter.contains(button.icon) ? .on : .off
        }
        barMenu.addItem(.separator())
        barMenu.addItem(withTitle: "기본값으로", action: #selector(resetBarItems), keyEquivalent: "").target = self
        menu.addItem(withTitle: "서식 바 항목", action: nil, keyEquivalent: "").submenu = barMenu
        let login = menu.addItem(withTitle: "로그인 시 자동 실행", action: #selector(toggleLogin(_:)), keyEquivalent: "")
        login.target = self
        login.state = SMAppService.mainApp.status == .enabled ? .on : .off
        menu.addItem(.separator())
        menu.addItem(withTitle: "템플릿 폴더 열기", action: #selector(openTemplates), keyEquivalent: "").target = self
        menu.addItem(.separator())
        menu.addItem(withTitle: "NotesPlus 종료", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        statusItem.menu = menu

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

    @objc private func toggleFeature(_ sender: NSMenuItem) {
        guard let feature = sender.representedObject as? Settings.Feature else { return }
        Settings.set(feature, !Settings.isOn(feature))
        sender.state = Settings.isOn(feature) ? .on : .off
        slash.hide()
        observer.onChange()  // Panels of a feature that was just turned off close right away.
    }

    @objc private func toggleBarItem(_ sender: NSMenuItem) {
        guard let icon = sender.representedObject as? String else { return }
        var hidden = Settings.hiddenBarItems
        if hidden.contains(icon) {
            hidden.remove(icon)
        } else if hidden.count + 1 < FormatBar.buttons.count {
            hidden.insert(icon)
        } else {
            NSSound.beep()  // An empty bar would be a stray blank pill; turn the whole bar off from the main menu instead.
            return
        }
        Settings.hiddenBarItems = hidden
        sender.state = hidden.contains(icon) ? .off : .on
        observer.onChange()
    }

    @objc private func toggleBarDivider(_ sender: NSMenuItem) {
        guard let icon = sender.representedObject as? String else { return }
        var dividers = Settings.dividerAfter
        if dividers.contains(icon) { dividers.remove(icon) } else { dividers.insert(icon) }
        Settings.dividerAfter = dividers
        sender.state = dividers.contains(icon) ? .on : .off
        observer.onChange()
    }

    @objc private func resetBarItems(_ sender: NSMenuItem) {
        Settings.hiddenBarItems = []
        Settings.dividerAfter = []
        sender.menu?.items.forEach { $0.state = $0.tag == 1 ? .on : .off }
        observer.onChange()
    }

    @objc private func toggleLogin(_ sender: NSMenuItem) {
        do {
            if SMAppService.mainApp.status == .enabled { try SMAppService.mainApp.unregister() } else { try SMAppService.mainApp.register() }
        } catch {
            NSLog("NotesPlus: login item change failed: \(error)")
            NSSound.beep()
        }
        // Registering can succeed yet wait for the user to approve it in System Settings.
        if SMAppService.mainApp.status == .requiresApproval { SMAppService.openSystemSettingsLoginItems() }
        sender.state = SMAppService.mainApp.status == .enabled ? .on : .off
    }

    @objc private func openTemplates() {
        NSWorkspace.shared.open(Templates.directory)
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
