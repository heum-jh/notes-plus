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
    ]

    private let model = FormatBarModel()

    private lazy var panel = FloatingPanel(FormatBarView(model: model) { [weak self] button in
        Self.log("before \(button.help)")
        switch button.action {
        case .key(let code, let flags): NotesAX.pressKey(code, flags)
        case .menu(let menu, let titles): if !NotesAX.pressMenu(menu, titles) { NSSound.beep() }
        case .underline: Self.toggleUnderline()
        }
        // Flip the highlight right away; Notes sends no AX notification for style changes, so confirm shortly after.
        if ["bold", "italic", "underline", "strikethrough"].contains(button.icon) {
            self?.model.active.formSymmetricDifference([button.icon])
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { Self.log("after \(button.help)"); self?.update() }
    })

    func update() {
        guard let el = NotesAX.focusedTextArea(), let sel = NotesAX.selectedRange(el),
              let rect = sel.length > 0 ? NotesAX.bounds(el, sel) : NotesAX.caretRect(el, at: sel.location) else {
            panel.orderOut(nil)
            return
        }
        // With a bare caret, the character before it is what new text will look like.
        let location = sel.length > 0 || sel.location == 0 ? sel.location : sel.location - 1
        let attributes = NotesAX.attributes(el, at: location)
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
        panel.show(bottomLeft: NSPoint(x: rect.minX, y: rect.maxY + 6))
    }

    // ponytail: temporary trace for the italic/underline report; remove once reproduced.
    private static func log(_ label: String) {
        guard let el = NotesAX.focusedTextArea(), let sel = NotesAX.selectedRange(el) else { NSLog("NotesPlus: \(label) no text area"); return }
        let a = NotesAX.attributes(el, at: sel.location)
        let font = (a[.init("AXFont")] as? [String: Any])?["AXFontName"] ?? "-"
        NSLog("NotesPlus: \(label) front=\(NSWorkspace.shared.frontmostApplication?.bundleIdentifier ?? "-") sel=\(sel) font=\(font) underline=\(a[.init("AXUnderline")] ?? "-")")
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
}

struct FormatBarView: View {
    let model: FormatBarModel
    let onPress: (FormatBar.Button) -> Void

    var body: some View {
        HStack(spacing: 2) {
            ForEach(FormatBar.buttons, id: \.help) { button in
                SwiftUI.Button { onPress(button) } label: {
                    Image(systemName: button.icon)
                        .frame(width: 26, height: 24)
                        .foregroundStyle(model.active.contains(button.icon) ? Color.accentColor : .primary)
                        .background(model.active.contains(button.icon) ? Color.accentColor.opacity(0.2) : .clear,
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
            }
        }
        .padding(4)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
    }
}
