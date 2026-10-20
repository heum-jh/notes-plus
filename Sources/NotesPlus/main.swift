import AppKit
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
            self?.backlinks.update()
        }
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

    @objc private func openTemplates() {
        NSWorkspace.shared.open(Templates.directory)
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
