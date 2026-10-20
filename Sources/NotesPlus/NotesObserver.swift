import AppKit

/// Calls `onChange` (debounced) when the selection or focus changes in Notes, or when apps switch.
final class NotesObserver {
    var onChange: () -> Void = {}
    private var observer: AXObserver?
    private var pid: pid_t = 0
    private var pending: DispatchWorkItem?

    func start() {
        NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main) { [weak self] _ in
            self?.attach()
            self?.scheduleChange()
        }
        attach()
    }

    /// (Re)creates the AX observer when a new Notes process becomes frontmost.
    private func attach() {
        guard let app = NotesAX.frontmostNotes, app.processIdentifier != pid else { return }
        if let observer { CFRunLoopRemoveSource(CFRunLoopGetMain(), AXObserverGetRunLoopSource(observer), .defaultMode) }
        observer = nil
        pid = app.processIdentifier
        var created: AXObserver?
        let callback: AXObserverCallback = { _, _, _, refcon in
            Unmanaged<NotesObserver>.fromOpaque(refcon!).takeUnretainedValue().scheduleChange()
        }
        guard AXObserverCreate(pid, callback, &created) == .success, let created else { return }
        let appElement = AXUIElementCreateApplication(pid)
        let refcon = Unmanaged.passUnretained(self).toOpaque()
        for name in [kAXSelectedTextChangedNotification, kAXFocusedUIElementChangedNotification, kAXFocusedWindowChangedNotification] {
            AXObserverAddNotification(created, appElement, name as CFString, refcon)
        }
        CFRunLoopAddSource(CFRunLoopGetMain(), AXObserverGetRunLoopSource(created), .defaultMode)
        observer = created
    }

    private func scheduleChange() {
        pending?.cancel()
        let work = DispatchWorkItem { [weak self] in self?.onChange() }
        pending = work
        // Waits out drag-selection and rapid typing before touching AX again.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05, execute: work)
    }
}
