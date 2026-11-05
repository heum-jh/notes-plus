import AppKit
import Observation
import SwiftUI

/// Watches key presses in Notes and shows a `/` command menu at the caret.
final class SlashController {
    private enum Key {
        static let `return`: Int64 = 36, enter: Int64 = 76, tab: Int64 = 48, escape: Int64 = 53, up: Int64 = 126, down: Int64 = 125, left: Int64 = 123, right: Int64 = 124
    }

    private var tap: CFMachPort?
    private let model = SlashMenuModel()
    private lazy var panel = FloatingPanel(SlashMenuView(model: model) { [weak self] index in self?.execute(index) })
    /// Text area and `/query` range the menu currently targets.
    private var target: (element: AXUIElement, range: NSRange, cell: AXUIElement?)?
    /// Location of a `/` dismissed with Esc, so it is not reopened while typing after it.
    private var dismissedAt: Int?
    private var anchor = NSPoint.zero
    /// Command tree for the open menu; read from disk once per menu session, not on every keystroke.
    private var cachedTree: [SlashCommand]?

    /// Installs the key event tap. Requires the Accessibility permission.
    @discardableResult
    func start() -> Bool {
        guard tap == nil else { return true }
        let mask = CGEventMask(1 << CGEventType.keyDown.rawValue)
        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap, place: .headInsertEventTap, options: .defaultTap, eventsOfInterest: mask,
            callback: { _, type, event, refcon in
                Unmanaged<SlashController>.fromOpaque(refcon!).takeUnretainedValue().handle(type, event)
            },
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else { return false }
        self.tap = tap
        CFRunLoopAddSource(CFRunLoopGetMain(), CFMachPortCreateRunLoopSource(nil, tap, 0), .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main) { [weak self] _ in
            self?.hide()
        }
        return true
    }

    private func handle(_ type: CGEventType, _ event: CGEvent) -> Unmanaged<CGEvent>? {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let tap { CGEvent.tapEnable(tap: tap, enable: true) }
            return Unmanaged.passUnretained(event)
        }
        guard NotesAX.frontmostNotes != nil else { return Unmanaged.passUnretained(event) }

        if panel.isVisible {
            switch event.getIntegerValueField(.keyboardEventKeycode) {
            case Key.down: model.move(1); return nil
            case Key.up: model.move(-1); return nil
            case Key.return, Key.enter, Key.tab: execute(model.selected); return nil
            case Key.right where model.items.indices.contains(model.selected) && model.items[model.selected].isGroup: open(model.selected); return nil
            case Key.left where !model.parents.isEmpty: back(); return nil
            case Key.escape: dismissedAt = target?.range.location; hide(); return nil
            default: break
            }
        }
        // ponytail: reading the note via AX only on trigger keys or while the menu is open keeps typing cheap.
        let typed = NSEvent(cgEvent: event)?.characters ?? ""
        // Let Notes apply the key first, then read the updated text.
        if panel.isVisible || typed == "/" {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.03) { [weak self] in self?.refresh() }
        } else if MarkdownShortcut.triggers.contains(typed) {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.03) { MarkdownShortcut.applyIfMatched() }
        } else if typed == "[" {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.03) { Backlinks.convertWikiLinkTrigger() }
        }
        return Unmanaged.passUnretained(event)
    }

    private func refresh() {
        guard let el = NotesAX.focusedTextArea(), let text = NotesAX.value(el),
              let sel = NotesAX.selectedRange(el), sel.length == 0,
              let match = SlashQuery.parse(text, cursor: sel.location) else {
            dismissedAt = nil
            hide()
            return
        }
        guard match.range.location != dismissedAt else { return }
        let cell = NotesAX.tableCell(of: el)
        // A click can move the caret without closing the menu; a different spot starts a fresh session.
        if let current = target, current.range.location != match.range.location || !CFEqual(current.element, el) {
            cachedTree = nil
            model.parents = []
        }
        let tree = cachedTree ?? SlashCommand.tree(inTable: cell != nil)
        cachedTree = tree
        let items: [SlashCommand]
        if match.query.isEmpty {
            // Keep the opened submenu while the query stays empty.
            items = model.parents.isEmpty ? tree : model.items
        } else {
            model.parents = []
            // Section dividers only make sense in the full list.
            items = tree.flatMap(\.leaves).filter { $0.matches(match.query) }.map { var row = $0; row.dividerBefore = false; return row }
        }
        guard !items.isEmpty else { hide(); return }
        target = (el, match.range, cell)
        if model.parents.isEmpty { model.selected = 0 }
        model.items = items
        let caret = NotesAX.caretRect(el, at: sel.location) ?? NSRect(origin: NSEvent.mouseLocation, size: .zero)
        anchor = NSPoint(x: caret.minX, y: caret.minY - 4)
        if panel.isVisible { reposition() } else { panel.show(topLeft: anchor) }
    }

    private func open(_ index: Int) {
        guard case .group(let children) = model.items[index].action else { return }
        model.parents.append((model.items, index))
        model.items = children
        model.selected = 0
        reposition()
    }

    private func back() {
        guard let parent = model.parents.popLast() else { return }
        model.items = parent.items
        model.selected = parent.selected
        reposition()
    }

    /// Resizes after SwiftUI has applied the new rows; `fittingSize` is stale right after `model.items` changes.
    private func reposition() {
        DispatchQueue.main.async { [weak self] in
            guard let self, panel.isVisible else { return }
            panel.show(topLeft: anchor)
        }
    }

    private func execute(_ index: Int) {
        guard let target, model.items.indices.contains(index) else { return }
        let command = model.items[index]
        if command.isGroup { open(index); return }
        // Resolve a table action before deleting `/query`, so a missing action costs nothing.
        var tableAction: (cell: AXUIElement, name: String)?
        if case .table(let wanted) = command.action {
            guard let cell = target.cell, let name = NotesAX.actionName(cell, containing: wanted) else {
                NSLog("NotesPlus: table action not found: \(wanted)")
                NSSound.beep()
                return
            }
            tableAction = (cell, name)
        }
        hide()
        // Remove the typed `/query`, then apply the command at that spot.
        NotesAX.setSelectedRange(target.element, target.range)
        NotesAX.insert(target.element, "")
        switch command.action {
        case .group: break
        case .table:
            if let tableAction, AXUIElementPerformAction(tableAction.cell, tableAction.name as CFString) != .success { NSSound.beep() }
        case .menu(let menu, let titles):
            if !NotesAX.pressMenu(menu, titles) { NSSound.beep() }
        case .template(let url):
            guard let text = try? String(contentsOf: url, encoding: .utf8) else { NSSound.beep(); return }
            // Markdown templates keep headings and checklists; .txt is pasted as plain text.
            let item = url.pathExtension == "md" ? NotesAX.pasteMarkdownItem : NotesAX.pastePlainItem
            if !NotesAX.paste(text, using: item) { NSLog("NotesPlus: paste menu not found: \(item)"); NSSound.beep() }
        }
    }

    private func hide() {
        target = nil
        cachedTree = nil
        model.parents = []
        panel.orderOut(nil)
    }
}

@Observable
final class SlashMenuModel {
    var items: [SlashCommand] = []
    var selected = 0
    /// Levels above the open submenu, with the row that opened each.
    var parents: [(items: [SlashCommand], selected: Int)] = []

    func move(_ delta: Int) {
        guard !items.isEmpty else { return }
        selected = (selected + delta + items.count) % items.count
    }
}

struct SlashMenuView: View {
    let model: SlashMenuModel
    let onPick: (Int) -> Void

    var body: some View {
        // ponytail: row height 28 is an estimate; the list scrolls past 10 rows.
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(model.items.enumerated()), id: \.offset) { index, item in
                        if item.dividerBefore { Divider().padding(.vertical, 4) }
                        HStack(spacing: 8) {
                            Image(systemName: item.icon).frame(width: 18)
                            Text(item.title)
                            Spacer()
                            if item.isGroup { Image(systemName: "chevron.right").foregroundStyle(.secondary) }
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(index == model.selected ? Color.accentColor.opacity(0.25) : .clear, in: RoundedRectangle(cornerRadius: 6))
                        .contentShape(Rectangle())
                        .onTapGesture { onPick(index) }
                        .id(index)
                    }
                }
            }
            .frame(height: CGFloat(min(model.items.count, 10)) * 28 + CGFloat(model.items.prefix(10).filter(\.dividerBefore).count) * 9)
            .onChange(of: model.selected) { _, new in proxy.scrollTo(new) }
        }
        .padding(6)
        .frame(width: 240)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10))
    }
}
