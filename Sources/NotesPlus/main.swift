import AppKit

if CommandLine.arguments.contains("--selftest") {
    SlashQuery.selfTest()
    print("selftest ok")
    exit(0)
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let slash = SlashController()
    private var permissionTimer: Timer?

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem.button?.image = NSImage(systemSymbolName: "note.text", accessibilityDescription: "NotesPlus")
        let menu = NSMenu()
        menu.addItem(withTitle: "템플릿 폴더 열기", action: #selector(openTemplates), keyEquivalent: "").target = self
        menu.addItem(.separator())
        menu.addItem(withTitle: "NotesPlus 종료", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        statusItem.menu = menu

        Templates.ensureDirectory()
        let prompt = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        if AXIsProcessTrustedWithOptions(prompt) {
            slash.start()
        } else {
            // Start as soon as the user grants Accessibility.
            permissionTimer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] timer in
                guard AXIsProcessTrusted() else { return }
                timer.invalidate()
                self?.slash.start()
            }
        }
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
