import Foundation

struct SlashCommand {
    enum Action {
        /// Notes Format menu item titles (Korean, English).
        case formatMenu([String])
        case template(URL)
    }

    let title: String
    let icon: String
    let keywords: String
    let action: Action

    func matches(_ query: String) -> Bool {
        query.isEmpty || title.localizedCaseInsensitiveContains(query) || keywords.localizedCaseInsensitiveContains(query)
    }

    // ponytail: English titles are unverified guesses; only the Korean menu was probed on macOS 27.
    static let formats: [SlashCommand] = [
        .init(title: "제목", icon: "textformat.size.larger", keywords: "title", action: .formatMenu(["제목", "Title"])),
        .init(title: "머리말", icon: "textformat.size", keywords: "heading h1", action: .formatMenu(["머리말", "Heading"])),
        .init(title: "부머리말", icon: "textformat.size.smaller", keywords: "subheading h2", action: .formatMenu(["부머리말", "Subheading"])),
        .init(title: "본문", icon: "text.alignleft", keywords: "body text", action: .formatMenu(["본문", "Body"])),
        .init(title: "구분점 목록", icon: "list.bullet", keywords: "bullet ul list", action: .formatMenu(["구분점 목록", "Bulleted List"])),
        .init(title: "대시 목록", icon: "list.dash", keywords: "dash list", action: .formatMenu(["대시 목록", "Dashed List"])),
        .init(title: "번호 목록", icon: "list.number", keywords: "numbered ol list", action: .formatMenu(["번호 목록", "Numbered List"])),
        .init(title: "체크리스트", icon: "checklist", keywords: "checklist todo", action: .formatMenu(["체크리스트", "Checklist"])),
        .init(title: "블록 인용", icon: "text.quote", keywords: "quote", action: .formatMenu(["블록 인용", "Block Quote"])),
        .init(title: "모노 스타일", icon: "chevron.left.forwardslash.chevron.right", keywords: "mono code", action: .formatMenu(["모노 스타일", "Monostyled"])),
        .init(title: "표", icon: "tablecells", keywords: "table", action: .formatMenu(["표", "Table"])),
    ]

    static func all() -> [SlashCommand] {
        formats + Templates.all().map {
            .init(title: $0.deletingPathExtension().lastPathComponent, icon: "doc.text", keywords: "template 템플릿", action: .template($0))
        }
    }
}

enum Templates {
    static let directory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        .appending(path: "notes-plus/templates", directoryHint: .isDirectory)

    /// Creates the folder with one sample template on first run.
    static func ensureDirectory() {
        let fm = FileManager.default
        guard !fm.fileExists(atPath: directory.path) else { return }
        try? fm.createDirectory(at: directory, withIntermediateDirectories: true)
        try? "회의록\n참석자: \n안건: \n결정 사항: \n후속 작업: \n"
            .write(to: directory.appending(path: "회의록.md"), atomically: true, encoding: .utf8)
    }

    static func all() -> [URL] {
        let files = (try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)) ?? []
        return files.filter { ["md", "txt"].contains($0.pathExtension) }
            .sorted { $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending }
    }
}

enum SlashQuery {
    /// `/` at line or word start, followed by a query with no whitespace or slash, ending at the caret.
    private static let regex = try! NSRegularExpression(pattern: #"(?:^|(?<=\s))/([^\s/]{0,30})$"#)

    /// Returns the UTF-16 range of `/query` ending at `cursor`, plus the query text.
    static func parse(_ text: String, cursor: Int) -> (range: NSRange, query: String)? {
        let ns = text as NSString
        guard cursor <= ns.length else { return nil }
        let prefix = ns.substring(to: cursor) as NSString
        guard let m = regex.firstMatch(in: prefix as String, range: NSRange(location: 0, length: prefix.length)) else { return nil }
        return (m.range, prefix.substring(with: m.range(at: 1)))
    }

    static func selfTest() {
        func check(_ text: String, _ cursor: Int, _ expected: (Int, Int, String)?) {
            let got = parse(text, cursor: cursor)
            let ok = expected.map { got?.range == NSRange(location: $0.0, length: $0.1) && got?.query == $0.2 } ?? (got == nil)
            precondition(ok, "parse(\(text.debugDescription), \(cursor)) = \(String(describing: got))")
        }
        check("/", 1, (0, 1, ""))
        check("abc /he", 7, (4, 3, "he"))
        check("a\n/머리", 5, (2, 3, "머리"))
        check("/abc", 2, (0, 2, "a"))
        check("http://x", 8, nil)
        check("a/b", 3, nil)
        check("/he llo", 7, nil)
        check("", 0, nil)
    }
}
