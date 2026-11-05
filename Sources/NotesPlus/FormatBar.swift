import AppKit
import Observation
import SwiftUI

/// Floating toolbar that follows the caret (or selection) while a note body is focused.
final class FormatBar {
    enum Action {
        /// Shortcuts go through Notes' own menu validation, so style toggles see the current state.
        /// AX-pressing those menu items uses a stale check mark and only ever adds the style.
        case key(CGKeyCode, CGEventFlags)
        case menu([String], [String])
        case underline
    }

    struct Button {
        let icon: String
        let help: String
        let action: Action
    }

    // Key codes are ANSI positions: B=11, I=34, U=32.
    static let buttons: [Button] = [
        .init(icon: "bold", help: "볼드체 (⌘B)", action: .key(11, .maskCommand)),
        .init(icon: "italic", help: "이탤릭체 (⌘I)", action: .key(34, .maskCommand)),
        .init(icon: "underline", help: "밑줄체 (⌘U)", action: .underline),
        .init(icon: "strikethrough", help: "취소선", action: .menu(NotesAX.formatMenu, ["취소선", "Strikethrough"])),
        .init(icon: "paintpalette", help: "색상 보기", action: .menu(NotesAX.formatMenu, ["색상 보기", "Show Colors"])),
        .init(icon: "textformat.size", help: "머리말", action: .menu(NotesAX.formatMenu, ["머리말", "Heading"])),
        .init(icon: "list.bullet", help: "구분점 목록", action: .menu(NotesAX.formatMenu, ["구분점 목록", "Bulleted List"])),
        .init(icon: "checklist", help: "체크리스트", action: .menu(NotesAX.formatMenu, ["체크리스트", "Checklist"])),
        .init(icon: "apple.intelligence", help: "글쓰기 도구", action: .menu(NotesAX.editMenu, ["글쓰기 도구 표시", "Show Writing Tools"])),
        .init(icon: "link", help: "링크 추가", action: .menu(NotesAX.editMenu, ["링크 추가…", "Add Link…"])),
        .init(icon: "highlighter", help: "강조", action: .menu(NotesAX.formatMenu, ["강조", "Highlight"])),
        // ANSI key codes: [ = 33, ] = 30.
        .init(icon: "increase.indent", help: "들여쓰기 (⌘])", action: .key(30, .maskCommand)),
        .init(icon: "decrease.indent", help: "내어쓰기 (⌘[)", action: .key(33, .maskCommand)),
        .init(icon: "eraser", help: "스타일 제거", action: .menu(NotesAX.formatMenu, ["스타일 제거", "Remove Style"])),
        // Format > 정렬 submenu; the menu search descends into it.
        .init(icon: "text.alignleft", help: "왼쪽 정렬", action: .menu(NotesAX.formatMenu, ["왼쪽 정렬", "Align Left"])),
        .init(icon: "text.aligncenter", help: "가운데 맞춤", action: .menu(NotesAX.formatMenu, ["가운데 맞춤", "Center"])),
        .init(icon: "text.justify", help: "좌우 정렬", action: .menu(NotesAX.formatMenu, ["좌우 정렬", "Justify"])),
        .init(icon: "text.alignright", help: "오른쪽 정렬", action: .menu(NotesAX.formatMenu, ["오른쪽 정렬", "Align Right"])),
    ]

    static let separatorKey = LayoutKeys.separator

    struct BarItem: Identifiable {
        let id: Int
        /// nil for a separator line.
        let button: Button?
    }

    /// Saved order made complete: unknown or repeated buttons dropped, buttons added since the layout was saved appended.
    static func order(_ layout: [String]) -> [String] {
        let icons = buttons.map(\.icon)
        return LayoutKeys.order(layout, known: icons, fallback: icons)
    }

    /// What the bar draws: hidden buttons removed, and separators collapsed so none leads, trails or doubles up.
    static func items(layout: [String], hidden: Set<String>) -> [BarItem] {
        var keys: [String] = []
        for key in order(layout) where !hidden.contains(key) {
            if key == separatorKey, keys.isEmpty || keys.last == separatorKey { continue }
            keys.append(key)
        }
        if keys.last == separatorKey { keys.removeLast() }
        return keys.enumerated().map { index, key in BarItem(id: index, button: buttons.first { $0.icon == key }) }
    }

    static func selfTest() {
        func keys(_ layout: [String], _ hidden: Set<String> = []) -> [String] {
            items(layout: layout, hidden: hidden).map { $0.button?.icon ?? separatorKey }
        }
        let all = buttons.map(\.icon)
        precondition(keys([]) == all)
        precondition(Array(keys(["italic", "|", "bold"]).prefix(3)) == ["italic", "|", "bold"])
        precondition(keys(["|", "bold", "|", "|", "italic", "|"]).prefix(3) == ["bold", "|", "italic"])
        let onlyBoldItalic = Set(all).subtracting(["bold", "italic"])
        precondition(keys(["bold", "|", "italic"], onlyBoldItalic) == ["bold", "|", "italic"])
        precondition(keys(["bold", "|", "italic"], onlyBoldItalic.union(["italic"])) == ["bold"])
        precondition(keys(["nope", "bold", "bold"]).filter { $0 == "bold" }.count == 1 && !keys(["nope"]).contains("nope"))
        precondition(order(["italic"]).first == "italic" && order(["italic"]).count == all.count)
    }

    /// Runs after a button press settles; the app uses it to refresh every panel, not just this one.
    var onButtonPressed: () -> Void = {}

    private let model = FormatBarModel()

    private lazy var panel = FloatingPanel(FormatBarView(model: model) { [weak self] button in
        switch button.action {
        case .key(let code, let flags): NotesAX.pressKey(code, flags)
        case .menu(let menu, let titles): if !NotesAX.pressMenu(menu, titles) { NSSound.beep() }
        case .underline: Self.toggleUnderline()
        }
        // Flip the highlight right away; Notes sends no AX notification for style changes, so confirm shortly after.
        if ["bold", "italic", "underline", "strikethrough"].contains(button.icon) {
            self?.model.active.formSymmetricDifference([button.icon])
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { self?.onButtonPressed() }
    })

    /// Screen frame while the bar is showing, so other panels can stay clear of it.
    var visibleFrame: NSRect? { panel.isVisible ? panel.frame : nil }

    func update() {
        guard Settings.isOn(.formatBar) else { panel.orderOut(nil); return }
        guard let el = NotesAX.focusedTextArea(), let sel = NotesAX.selectedRange(el),
              let rect = sel.length > 0 ? NotesAX.bounds(el, sel) : NotesAX.caretRect(el, at: sel.location) else {
            panel.orderOut(nil)
            return
        }
        // With a bare caret, the character before it is what new text will look like.
        let location = sel.length > 0 || sel.location == 0 ? sel.location : sel.location - 1
        let attributes = NotesAX.attributes(el, at: location)
        let hidden = Settings.hiddenBarItems, layout = Settings.barLayout
        let hiddenChanged = hidden != model.hidden || layout != model.layout
        model.hidden = hidden
        model.layout = layout
        model.color = attributes[.init("AXForegroundColor")].map { NSColor(cgColor: $0 as! CGColor) } ?? nil
        // Keyed by button icon. AX exposes no traits, so bold/italic come from the font name
        // (.AppleSystemUIFontEmphasized, .AppleSystemUIFontItalic, ...-Bold).
        let font = (attributes[.init("AXFont")] as? [String: Any])?["AXFontName"] as? String ?? ""
        model.active = Set([
            font.contains("Emphasized") || font.contains("Bold") ? "bold" : nil,
            font.contains("Italic") ? "italic" : nil,
            attributes[.init("AXUnderline")] as? Int == 1 ? "underline" : nil,
            attributes[.init("AXStrikethrough")] as? Int == 1 ? "strikethrough" : nil,
        ].compactMap { $0 })
        let origin = NSPoint(x: rect.minX, y: rect.maxY + 6)
        panel.show(bottomLeft: origin)
        // The panel was sized before SwiftUI applied the new button set; size it again once it has.
        if hiddenChanged { DispatchQueue.main.async { [weak self] in self?.panel.show(bottomLeft: origin) } }
    }

    /// Notes 27 never removes an underline: ⌘U and the menu item only add it.
    /// So an underlined selection gets "스타일 제거" and its bold, italic and strikethrough put back.
    private static func toggleUnderline() {
        guard let el = NotesAX.focusedTextArea(), let sel = NotesAX.selectedRange(el), sel.length > 0 else {
            NotesAX.pressKey(32, .maskCommand)
            return
        }
        let attributes = NotesAX.attributes(el, at: sel.location)
        guard attributes[.init("AXUnderline")] as? Int == 1 else {
            NotesAX.pressKey(32, .maskCommand)
            return
        }
        // ponytail: text color and highlight are not restored; read and reapply them if that matters.
        let font = (attributes[.init("AXFont")] as? [String: Any])?["AXFontName"] as? String ?? ""
        guard NotesAX.pressMenu(NotesAX.formatMenu, ["스타일 제거", "Remove Style"]) else { NSSound.beep(); return }
        if font.contains("Emphasized") || font.contains("Bold") { NotesAX.pressKey(11, .maskCommand) }
        if font.contains("Italic") { NotesAX.pressKey(34, .maskCommand) }
        if attributes[.init("AXStrikethrough")] as? Int == 1 {
            // Let the queued shortcuts land first; the menu press is synchronous and would overtake them.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                _ = NotesAX.pressMenu(NotesAX.formatMenu, ["취소선", "Strikethrough"])
            }
        }
    }
}

@Observable
final class FormatBarModel {
    var color: NSColor?
    var active: Set<String> = []
    var hidden: Set<String> = []
    var layout: [String] = []
    /// Set by the settings window while the pointer is over a row, to point out that button.
    var highlighted: String?

    init(layout: [String] = [], hidden: Set<String> = [], highlighted: String? = nil) {
        self.layout = layout
        self.hidden = hidden
        self.highlighted = highlighted
    }
}

struct FormatBarView: View {
    let model: FormatBarModel
    let onPress: (FormatBar.Button) -> Void

    var body: some View {
        HStack(spacing: 2) {
            ForEach(FormatBar.items(layout: model.layout, hidden: model.hidden)) { item in
                if let button = item.button {
                    SwiftUI.Button { onPress(button) } label: {
                        Image(systemName: button.icon)
                            .frame(width: 26, height: 24)
                            .foregroundStyle(model.active.contains(button.icon) ? Color.accentColor : .primary)
                            .background(model.active.contains(button.icon) ? Color.accentColor.opacity(0.2) : model.highlighted == button.icon ? Color.primary.opacity(0.18) : .clear,
                                        in: RoundedRectangle(cornerRadius: 5))
                            .overlay(alignment: .bottom) {
                                if case .menu(_, let titles) = button.action, titles.first == "색상 보기", let color = model.color {
                                    Capsule().fill(Color(nsColor: color)).frame(width: 16, height: 3)
                                        .overlay(Capsule().stroke(.secondary, lineWidth: 0.5))
                                }
                            }
                    }
                    .buttonStyle(.borderless)
                    .help(button.help)
                    // Notes owns the cursor while it is frontmost, so re-assert on every move.
                    .onContinuousHover { phase in
                        if case .active = phase { NSCursor.pointingHand.set() } else { NSCursor.arrow.set() }
                    }
                } else {
                    Divider().frame(height: 16).padding(.horizontal, 2)
                }
            }
        }
        .padding(4)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
    }
}
