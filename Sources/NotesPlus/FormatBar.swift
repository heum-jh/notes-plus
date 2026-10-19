import AppKit
import SwiftUI

/// Floating toolbar that follows the caret (or selection) while a note body is focused.
final class FormatBar {
    struct Button {
        let icon: String
        let help: String
        let menu: [String]
        let titles: [String]
    }

    static let buttons: [Button] = [
        .init(icon: "bold", help: "볼드체", menu: NotesAX.formatMenu, titles: ["볼드체", "Bold"]),
        .init(icon: "italic", help: "이탤릭체", menu: NotesAX.formatMenu, titles: ["이탤릭체", "Italic"]),
        .init(icon: "underline", help: "밑줄체", menu: NotesAX.formatMenu, titles: ["밑줄체", "Underline"]),
        .init(icon: "strikethrough", help: "취소선", menu: NotesAX.formatMenu, titles: ["취소선", "Strikethrough"]),
        .init(icon: "highlighter", help: "강조", menu: NotesAX.formatMenu, titles: ["강조", "Highlight"]),
        .init(icon: "textformat.size", help: "머리말", menu: NotesAX.formatMenu, titles: ["머리말", "Heading"]),
        .init(icon: "list.bullet", help: "구분점 목록", menu: NotesAX.formatMenu, titles: ["구분점 목록", "Bulleted List"]),
        .init(icon: "checklist", help: "체크리스트", menu: NotesAX.formatMenu, titles: ["체크리스트", "Checklist"]),
        .init(icon: "link", help: "링크 추가", menu: NotesAX.editMenu, titles: ["링크 추가…", "Add Link…"]),
    ]

    private lazy var panel = FloatingPanel(FormatBarView { button in
        if !NotesAX.pressMenu(button.menu, button.titles) { NSSound.beep() }
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
            }
        }
        .padding(4)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
    }
}
