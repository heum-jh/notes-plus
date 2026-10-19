import AppKit

/// Turns Markdown typed in Notes into native Notes formatting.
enum MarkdownShortcut {
    enum Edit: Equatable {
        /// Line-start marker such as `## `, replaced by a paragraph style.
        case block(marker: NSRange, menu: [String])
        /// Inline `**text**` style markers around the text.
        case inline(open: NSRange, close: NSRange, menu: [String])
    }

    /// Keys after which the current line is checked.
    static let triggers: Set<String> = [" ", "`", "*", "~", "="]

    // Heading levels follow Notes' own Paste as Markdown: # Title, ## Heading, ### Subheading.
    private static let blocks: [(marker: String, menu: [String])] = [
        ("# ", ["제목", "Title"]),
        ("## ", ["머리말", "Heading"]),
        ("### ", ["부머리말", "Subheading"]),
        ("- ", ["대시 목록", "Dashed List"]),
        ("* ", ["구분점 목록", "Bulleted List"]),
        ("1. ", ["번호 목록", "Numbered List"]),
        ("[] ", ["체크리스트", "Checklist"]),
        ("[ ] ", ["체크리스트", "Checklist"]),
        ("> ", ["블록 인용", "Block Quote"]),
        ("```", ["모노 스타일", "Monostyled"]),
    ]

    /// Inner text must not start or end with whitespace, so `2 * 3 * 4` stays plain.
    private static let inlines: [(regex: NSRegularExpression, marker: Int, menu: [String])] = [
        (#"(?<!\*)\*\*([^*\s](?:[^*]*[^*\s])?)\*\*$"#, 2, ["볼드체", "Bold"]),
        (#"~~([^~\s](?:[^~]*[^~\s])?)~~$"#, 2, ["취소선", "Strikethrough"]),
        (#"==([^=\s](?:[^=]*[^=\s])?)==$"#, 2, ["강조", "Highlight"]),
        (#"(?<![*\w])\*([^*\s](?:[^*]*[^*\s])?)\*$"#, 1, ["이탤릭체", "Italic"]),
    ].map { (try! NSRegularExpression(pattern: $0.0), $0.1, $0.2) }

    /// Finds the shortcut completed at `cursor`. Ranges are UTF-16 offsets into `text`.
    static func detect(_ text: String, cursor: Int) -> Edit? {
        let ns = text as NSString
        guard cursor <= ns.length else { return nil }
        let before = ns.substring(to: cursor) as NSString
        let newline = before.range(of: "\n", options: .backwards)
        let lineStart = newline.location == NSNotFound ? 0 : newline.location + 1
        let line = before.substring(from: lineStart)

        if let block = blocks.first(where: { $0.marker == line }) {
            return .block(marker: NSRange(location: lineStart, length: (line as NSString).length), menu: block.menu)
        }
        let lineRange = NSRange(location: 0, length: (line as NSString).length)
        for rule in inlines {
            guard let m = rule.regex.firstMatch(in: line, range: lineRange) else { continue }
            let start = lineStart + m.range.location, end = lineStart + NSMaxRange(m.range)
            return .inline(open: NSRange(location: start, length: rule.marker),
                           close: NSRange(location: end - rule.marker, length: rule.marker), menu: rule.menu)
        }
        return nil
    }

    static func applyIfMatched() {
        guard let el = NotesAX.focusedTextArea(), let text = NotesAX.value(el),
              let sel = NotesAX.selectedRange(el), sel.length == 0,
              let edit = detect(text, cursor: sel.location) else { return }
        switch edit {
        case .block(let marker, let menu):
            NotesAX.setSelectedRange(el, marker)
            NotesAX.insert(el, "")
            if !NotesAX.pressMenu(NotesAX.formatMenu, menu) { NSSound.beep() }
        case .inline(let open, let close, let menu):
            // Delete the closing marker first so the opening offsets stay valid.
            NotesAX.setSelectedRange(el, close)
            NotesAX.insert(el, "")
            NotesAX.setSelectedRange(el, open)
            NotesAX.insert(el, "")
            let innerLength = close.location - NSMaxRange(open)
            NotesAX.setSelectedRange(el, NSRange(location: open.location, length: innerLength))
            guard NotesAX.pressMenu(NotesAX.formatMenu, menu) else { NSSound.beep(); return }
            // Collapse to the end and toggle again so text typed next is plain.
            NotesAX.setSelectedRange(el, NSRange(location: open.location + innerLength, length: 0))
            NotesAX.pressMenu(NotesAX.formatMenu, menu)
        }
    }

    static func selfTest() {
        let heading = ["머리말", "Heading"], bold = ["볼드체", "Bold"], italic = ["이탤릭체", "Italic"]
        precondition(detect("## ", cursor: 3) == .block(marker: NSRange(location: 0, length: 3), menu: heading))
        precondition(detect("abc\n## ", cursor: 7) == .block(marker: NSRange(location: 4, length: 3), menu: heading))
        precondition(detect("x ## ", cursor: 5) == nil)
        precondition(detect("a **굵게**", cursor: 8) == .inline(open: NSRange(location: 2, length: 2), close: NSRange(location: 6, length: 2), menu: bold))
        precondition(detect("**굵게*", cursor: 5) == nil)
        precondition(detect("*기울*", cursor: 4) == .inline(open: NSRange(location: 0, length: 1), close: NSRange(location: 3, length: 1), menu: italic))
        precondition(detect("2 * 3 *", cursor: 7) == nil)
        precondition(detect("~~x~~", cursor: 5) != nil)
        precondition(detect("plain text ", cursor: 11) == nil)
    }
}
