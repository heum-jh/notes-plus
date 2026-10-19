import AppKit

/// Accessibility access to the Apple Notes editor and menu bar.
enum NotesAX {
    static let bundleID = "com.apple.Notes"

    /// Notes, only while it is the frontmost app.
    static var frontmostNotes: NSRunningApplication? {
        guard let app = NSWorkspace.shared.frontmostApplication, app.bundleIdentifier == bundleID else { return nil }
        return app
    }

    /// The focused note body (`AXTextArea`), or nil when Notes is not focused on one.
    static func focusedTextArea() -> AXUIElement? {
        guard let app = frontmostNotes else { return nil }
        let axApp = AXUIElementCreateApplication(app.processIdentifier)
        guard let el = element(axApp, kAXFocusedUIElementAttribute),
              copy(el, kAXRoleAttribute) as? String == kAXTextAreaRole else { return nil }
        return el
    }

    static func value(_ el: AXUIElement) -> String? {
        copy(el, kAXValueAttribute) as? String
    }

    static func selectedRange(_ el: AXUIElement) -> NSRange? {
        guard let v = copy(el, kAXSelectedTextRangeAttribute), CFGetTypeID(v) == AXValueGetTypeID() else { return nil }
        var r = CFRange()
        guard AXValueGetValue(v as! AXValue, .cfRange, &r) else { return nil }
        return NSRange(location: r.location, length: r.length)
    }

    static func setSelectedRange(_ el: AXUIElement, _ range: NSRange) {
        var r = CFRange(location: range.location, length: range.length)
        guard let v = AXValueCreate(.cfRange, &r) else { return }
        AXUIElementSetAttributeValue(el, kAXSelectedTextRangeAttribute as CFString, v)
    }

    /// Replaces the current selection (or inserts at the caret).
    static func insert(_ el: AXUIElement, _ text: String) {
        AXUIElementSetAttributeValue(el, kAXSelectedTextAttribute as CFString, text as CFString)
    }

    /// Caret rectangle in Cocoa screen coordinates (bottom-left origin).
    static func caretRect(_ el: AXUIElement, at location: Int) -> NSRect? {
        for candidate in [CFRange(location: location, length: 0), CFRange(location: max(location - 1, 0), length: 1)] {
            var r = candidate
            guard let param = AXValueCreate(.cfRange, &r) else { continue }
            var out: CFTypeRef?
            guard AXUIElementCopyParameterizedAttributeValue(el, kAXBoundsForRangeParameterizedAttribute as CFString, param, &out) == .success,
                  let out, CFGetTypeID(out) == AXValueGetTypeID() else { continue }
            var rect = CGRect.zero
            AXValueGetValue(out as! AXValue, .cgRect, &rect)
            guard rect.height > 0 else { continue }
            let primaryHeight = NSScreen.screens.first?.frame.height ?? 0
            return NSRect(x: rect.minX, y: primaryHeight - rect.maxY, width: rect.width, height: rect.height)
        }
        return nil
    }

    /// Presses the first item under Notes' Format menu whose title is in `titles`.
    /// Titles are matched at runtime instead of fixed menu paths, so items that move between macOS releases still resolve.
    @discardableResult
    static func pressFormatMenu(_ titles: [String]) -> Bool {
        guard let app = frontmostNotes else { return false }
        let axApp = AXUIElementCreateApplication(app.processIdentifier)
        guard let bar = element(axApp, kAXMenuBarAttribute),
              let format = children(bar).first(where: { ["포맷", "Format"].contains(copy($0, kAXTitleAttribute) as? String) }),
              let item = findMenuItem(in: format, titles: Set(titles), depth: 0) else { return false }
        return AXUIElementPerformAction(item, kAXPressAction as CFString) == .success
    }

    private static func findMenuItem(in el: AXUIElement, titles: Set<String>, depth: Int) -> AXUIElement? {
        guard depth < 6 else { return nil }
        for child in children(el) {
            if copy(child, kAXRoleAttribute) as? String == kAXMenuItemRole,
               let title = copy(child, kAXTitleAttribute) as? String, titles.contains(title) {
                return child
            }
            if let hit = findMenuItem(in: child, titles: titles, depth: depth + 1) { return hit }
        }
        return nil
    }

    private static func children(_ el: AXUIElement) -> [AXUIElement] {
        copy(el, kAXChildrenAttribute) as? [AXUIElement] ?? []
    }

    private static func element(_ el: AXUIElement, _ name: String) -> AXUIElement? {
        guard let v = copy(el, name), CFGetTypeID(v) == AXUIElementGetTypeID() else { return nil }
        return (v as! AXUIElement)
    }

    private static func copy(_ el: AXUIElement, _ name: String) -> CFTypeRef? {
        var v: CFTypeRef?
        guard AXUIElementCopyAttributeValue(el, name as CFString, &v) == .success else { return nil }
        return v
    }
}
