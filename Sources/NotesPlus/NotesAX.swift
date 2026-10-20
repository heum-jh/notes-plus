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
        bounds(el, NSRange(location: location, length: 0)) ?? bounds(el, NSRange(location: max(location - 1, 0), length: 1))
    }

    /// Screen rectangle of a text range in Cocoa coordinates.
    static func bounds(_ el: AXUIElement, _ range: NSRange) -> NSRect? {
        var r = CFRange(location: range.location, length: range.length)
        guard let param = AXValueCreate(.cfRange, &r) else { return nil }
        var out: CFTypeRef?
        guard AXUIElementCopyParameterizedAttributeValue(el, kAXBoundsForRangeParameterizedAttribute as CFString, param, &out) == .success,
              let out, CFGetTypeID(out) == AXValueGetTypeID() else { return nil }
        var rect = CGRect.zero
        AXValueGetValue(out as! AXValue, .cgRect, &rect)
        return rect.height > 0 ? cocoaRect(rect) : nil
    }

    /// Frame of the focused Notes window in Cocoa coordinates.
    static func focusedWindowFrame() -> NSRect? {
        guard let app = frontmostNotes,
              let window = element(AXUIElementCreateApplication(app.processIdentifier), kAXFocusedWindowAttribute),
              let pos = copy(window, kAXPositionAttribute), let size = copy(window, kAXSizeAttribute),
              CFGetTypeID(pos) == AXValueGetTypeID(), CFGetTypeID(size) == AXValueGetTypeID() else { return nil }
        var origin = CGPoint.zero, extent = CGSize.zero
        AXValueGetValue(pos as! AXValue, .cgPoint, &origin)
        AXValueGetValue(size as! AXValue, .cgSize, &extent)
        return cocoaRect(CGRect(origin: origin, size: extent))
    }

    /// Note UUID from the text area's `Note[id=<UUID>]` identifier.
    static func noteIdentifier(_ el: AXUIElement) -> String? {
        guard let id = copy(el, kAXIdentifierAttribute) as? String, id.hasPrefix("Note[id="), id.hasSuffix("]") else { return nil }
        return String(id.dropFirst("Note[id=".count).dropLast())
    }

    /// AX uses a top-left origin on the primary screen; AppKit uses bottom-left.
    private static func cocoaRect(_ rect: CGRect) -> NSRect {
        let primaryHeight = NSScreen.screens.first?.frame.height ?? 0
        return NSRect(x: rect.minX, y: primaryHeight - rect.maxY, width: rect.width, height: rect.height)
    }

    /// Character attributes at `location` (keys like AXFont, AXForegroundColor, AXUnderline, AXStrikethrough).
    static func attributes(_ el: AXUIElement, at location: Int) -> [NSAttributedString.Key: Any] {
        var cf = CFRange(location: location, length: 1)
        var out: CFTypeRef?
        guard let range = AXValueCreate(.cfRange, &cf),
              AXUIElementCopyParameterizedAttributeValue(el, "AXAttributedStringForRange" as CFString, range, &out) == .success,
              let string = out as? NSAttributedString, string.length > 0 else { return [:] }
        return string.attributes(at: 0, effectiveRange: nil)
    }

    /// Sends a keyboard shortcut to the frontmost app.
    static func pressKey(_ code: CGKeyCode, _ flags: CGEventFlags) {
        for down in [true, false] {
            let event = CGEvent(keyboardEventSource: nil, virtualKey: code, keyDown: down)
            event?.flags = flags
            event?.post(tap: .cghidEventTap)
        }
    }

    /// Types `text` as synthetic key events, so Notes reacts as if the user typed it.
    static func type(_ text: String) {
        for unit in text.utf16 {
            for down in [true, false] {
                var u = unit
                let event = CGEvent(keyboardEventSource: nil, virtualKey: 0, keyDown: down)
                event?.keyboardSetUnicodeString(stringLength: 1, unicodeString: &u)
                event?.post(tap: .cghidEventTap)
            }
        }
    }

    static let formatMenu = ["포맷", "Format"]
    static let editMenu = ["편집", "Edit"]

    /// Presses the first item under the Notes menu titled one of `menu` whose title is in `titles`.
    /// Titles are matched at runtime instead of fixed menu paths, so items that move between macOS releases still resolve.
    @discardableResult
    static func pressMenu(_ menu: [String], _ titles: [String]) -> Bool {
        guard let app = frontmostNotes else { return false }
        let axApp = AXUIElementCreateApplication(app.processIdentifier)
        guard let bar = element(axApp, kAXMenuBarAttribute),
              let top = children(bar).first(where: { menu.contains(copy($0, kAXTitleAttribute) as? String ?? "") }),
              let item = findMenuItem(in: top, titles: Set(titles), depth: 0) else { return false }
        return AXUIElementPerformAction(item, kAXPressAction as CFString) == .success
    }

    static let pasteMarkdownItem = ["Markdown으로 붙여넣기", "Paste as Markdown"]
    static let pastePlainItem = ["붙여넣고 스타일 일치", "Paste and Match Style"]

    /// Inserts `text` through a Notes Edit menu paste item, restoring the clipboard afterwards.
    /// Notes ignores multi-line writes to `AXSelectedText`, so pasting is the reliable way to insert blocks of text.
    static func paste(_ text: String, using item: [String]) -> Bool {
        let pb = NSPasteboard.general
        let saved: [NSPasteboardItem] = pb.pasteboardItems?.map { item in
            let copy = NSPasteboardItem()
            for type in item.types {
                if let data = item.data(forType: type) { copy.setData(data, forType: type) }
            }
            return copy
        } ?? []
        pb.clearContents()
        pb.setString(text, forType: .string)
        let pressed = pressMenu(editMenu, item)
        // ponytail: fixed delay for Notes to read the clipboard; poll changeCount if pastes get dropped.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            pb.clearContents()
            if !saved.isEmpty { pb.writeObjects(saved) }
        }
        return pressed
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
