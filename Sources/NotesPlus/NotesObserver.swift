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
        let callback: AXObserverCallback = { _, _, name, refcon in
            let me = Unmanaged<NotesObserver>.fromOpaque(refcon!).takeUnretainedValue()
            let isWindowGeometry = name as String == kAXMovedNotification || name as String == kAXResizedNotification
            if name as String == kAXFocusedWindowChangedNotification { me.watchWindows() }
            me.scheduleChange(throttle: isWindowGeometry)
        }
        guard AXObserverCreate(pid, callback, &created) == .success, let created else { return }
        let appElement = AXUIElementCreateApplication(pid)
        let refcon = Unmanaged.passUnretained(self).toOpaque()
        for name in [kAXSelectedTextChangedNotification, kAXFocusedUIElementChangedNotification, kAXFocusedWindowChangedNotification] {
            AXObserverAddNotification(created, appElement, name as CFString, refcon)
        }
        CFRunLoopAddSource(CFRunLoopGetMain(), AXObserverGetRunLoopSource(created), .defaultMode)
        observer = created
        watchWindows()
    }

    /// Move/resize notifications fire on the window element, not the app, so every window is watched.
    /// Re-adding an already watched window just returns an error, which is ignored.
    private func watchWindows() {
        guard let observer else { return }
        let refcon = Unmanaged.passUnretained(self).toOpaque()
        let windows = NotesAX.windows(pid)
        for window in windows {
            for name in [kAXMovedNotification, kAXResizedNotification] {
                AXObserverAddNotification(observer, window, name as CFString, refcon)
            }
        }
    }

    /// `throttle`: window drags fire continuously, so keep the pending update instead of resetting it,
    /// which lets panels follow the window during the drag rather than only after it stops.
    private func scheduleChange(throttle: Bool = false) {
        if throttle, pending != nil { return }
        pending?.cancel()
        let work = DispatchWorkItem { [weak self] in
            self?.pending = nil
            self?.onChange()
        }
        pending = work
        // Waits out drag-selection and rapid typing before touching AX again.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05, execute: work)
    }
}
