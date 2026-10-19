import AppKit
import Observation
import SwiftUI

/// Watches key presses in Notes and shows a `/` command menu at the caret.
final class SlashController {
    private enum Key {
        static let `return`: Int64 = 36, enter: Int64 = 76, tab: Int64 = 48, escape: Int64 = 53, up: Int64 = 126, down: Int64 = 125
    }

    private var tap: CFMachPort?
    private let model = SlashMenuModel()
    private lazy var panel = SlashPanel(model: model) { [weak self] index in self?.execute(index) }
    /// Text area and `/query` range the menu currently targets.
    private var target: (element: AXUIElement, range: NSRange)?
    /// Location of a `/` dismissed with Esc, so it is not reopened while typing after it.
    private var dismissedAt: Int?

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
            case Key.escape: dismissedAt = target?.range.location; hide(); return nil
            default: break
            }
        }
        // ponytail: reading the note via AX only on `/` or while the menu is open keeps typing cheap.
        if panel.isVisible || NSEvent(cgEvent: event)?.characters == "/" {
            // Let Notes apply the key first, then read the updated text.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.03) { [weak self] in self?.refresh() }
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
        // ponytail: first 10 matches only; add scrolling if template lists grow.
        let items = Array(SlashCommand.all().filter { $0.matches(match.query) }.prefix(10))
        guard !items.isEmpty else { hide(); return }
        target = (el, match.range)
        model.items = items
        model.selected = 0
        let caret = NotesAX.caretRect(el, at: sel.location) ?? NSRect(origin: NSEvent.mouseLocation, size: .zero)
        panel.show(below: caret)
    }

    private func execute(_ index: Int) {
        guard let target, model.items.indices.contains(index) else { return }
        let command = model.items[index]
        hide()
        // Remove the typed `/query`, then apply the command at that spot.
        NotesAX.setSelectedRange(target.element, target.range)
        NotesAX.insert(target.element, "")
        switch command.action {
        case .formatMenu(let titles):
            if !NotesAX.pressFormatMenu(titles) { NSSound.beep() }
        case .template(let url):
            guard let text = try? String(contentsOf: url, encoding: .utf8) else { NSSound.beep(); return }
            NotesAX.insert(target.element, text)
        }
    }

    private func hide() {
        target = nil
        panel.orderOut(nil)
    }
}

@Observable
final class SlashMenuModel {
    var items: [SlashCommand] = []
    var selected = 0

    func move(_ delta: Int) {
        guard !items.isEmpty else { return }
        selected = (selected + delta + items.count) % items.count
    }
}

/// Borderless panel that never takes focus away from Notes.
final class SlashPanel: NSPanel {
    private let hosting: NSHostingView<SlashMenuView>

    init(model: SlashMenuModel, onPick: @escaping (Int) -> Void) {
        hosting = NSHostingView(rootView: SlashMenuView(model: model, onPick: onPick))
        super.init(contentRect: .zero, styleMask: [.nonactivatingPanel, .borderless], backing: .buffered, defer: true)
        level = .popUpMenu
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        contentView = hosting
    }

    func show(below caret: NSRect) {
        setContentSize(hosting.fittingSize)
        setFrameTopLeftPoint(NSPoint(x: caret.minX, y: caret.minY - 4))
        orderFrontRegardless()
    }
}

struct SlashMenuView: View {
    let model: SlashMenuModel
    let onPick: (Int) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(model.items.enumerated()), id: \.offset) { index, item in
                HStack(spacing: 8) {
                    Image(systemName: item.icon).frame(width: 18)
                    Text(item.title)
                    Spacer()
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(index == model.selected ? Color.accentColor.opacity(0.25) : .clear, in: RoundedRectangle(cornerRadius: 6))
                .contentShape(Rectangle())
                .onTapGesture { onPick(index) }
            }
        }
        .padding(6)
        .frame(width: 240)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10))
    }
}
