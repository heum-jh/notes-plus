import AppKit
import SwiftUI

/// Floating toolbar that follows the caret (or selection) while a note body is focused.
final class FormatBar {
    enum Action {
        /// Shortcuts go through Notes' own menu validation, so style toggles see the current state.
        /// AX-pressing those menu items uses a stale check mark and only ever adds the style.
        case key(CGKeyCode, CGEventFlags)
        case menu([String], [String])
    }

    struct Button {
        let icon: String
        let help: String
        let action: Action
    }

    // Key codes are ANSI positions: B=11, I=34, U=32, E=14.
    static let buttons: [Button] = [
        .init(icon: "bold", help: "볼드체 (⌘B)", action: .key(11, .maskCommand)),
        .init(icon: "italic", help: "이탤릭체 (⌘I)", action: .key(34, .maskCommand)),
        .init(icon: "underline", help: "밑줄체 (⌘U)", action: .key(32, .maskCommand)),
        // ponytail: no default shortcut, so the menu path may not toggle off; add a shortcut lookup if it bites.
        .init(icon: "strikethrough", help: "취소선", action: .menu(NotesAX.formatMenu, ["취소선", "Strikethrough"])),
        .init(icon: "highlighter", help: "강조 (⇧⌘E)", action: .key(14, [.maskCommand, .maskShift])),
        .init(icon: "paintpalette", help: "색상 보기", action: .menu(NotesAX.formatMenu, ["색상 보기", "Show Colors"])),
        .init(icon: "textformat.size", help: "머리말", action: .menu(NotesAX.formatMenu, ["머리말", "Heading"])),
        .init(icon: "list.bullet", help: "구분점 목록", action: .menu(NotesAX.formatMenu, ["구분점 목록", "Bulleted List"])),
        .init(icon: "checklist", help: "체크리스트", action: .menu(NotesAX.formatMenu, ["체크리스트", "Checklist"])),
        .init(icon: "link", help: "링크 추가", action: .menu(NotesAX.editMenu, ["링크 추가…", "Add Link…"])),
    ]

    private lazy var panel = FloatingPanel(FormatBarView { button in
        switch button.action {
        case .key(let code, let flags): NotesAX.pressKey(code, flags)
        case .menu(let menu, let titles): if !NotesAX.pressMenu(menu, titles) { NSSound.beep() }
        }
    })

    func update() {
        guard let el = NotesAX.focusedTextArea(), let sel = NotesAX.selectedRange(el),
              let rect = sel.length > 0 ? NotesAX.bounds(el, sel) : NotesAX.caretRect(el, at: sel.location) else {
            panel.orderOut(nil)
            return
        }
        panel.show(bottomLeft: NSPoint(x: rect.minX, y: rect.maxY + 6))
    }
}

struct FormatBarView: View {
    let onPress: (FormatBar.Button) -> Void

    var body: some View {
        HStack(spacing: 2) {
            ForEach(FormatBar.buttons, id: \.help) { button in
                SwiftUI.Button { onPress(button) } label: {
                    Image(systemName: button.icon).frame(width: 26, height: 24)
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
