import Foundation

struct SlashCommand {
    enum Action {
        /// Notes menu (`NotesAX.formatMenu`/`editMenu`) and item titles (Korean, English).
        case menu([String], [String])
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
        .init(title: "제목", icon: "textformat.size.larger", keywords: "title", action: .menu(NotesAX.formatMenu, ["제목", "Title"])),
        .init(title: "머리말", icon: "textformat.size", keywords: "heading h1", action: .menu(NotesAX.formatMenu, ["머리말", "Heading"])),
        .init(title: "부머리말", icon: "textformat.size.smaller", keywords: "subheading h2", action: .menu(NotesAX.formatMenu, ["부머리말", "Subheading"])),
        .init(title: "본문", icon: "text.alignleft", keywords: "body text", action: .menu(NotesAX.formatMenu, ["본문", "Body"])),
        .init(title: "구분점 목록", icon: "list.bullet", keywords: "bullet ul list", action: .menu(NotesAX.formatMenu, ["구분점 목록", "Bulleted List"])),
        .init(title: "대시 목록", icon: "list.dash", keywords: "dash list", action: .menu(NotesAX.formatMenu, ["대시 목록", "Dashed List"])),
        .init(title: "번호 목록", icon: "list.number", keywords: "numbered ol list", action: .menu(NotesAX.formatMenu, ["번호 목록", "Numbered List"])),
        .init(title: "체크리스트", icon: "checklist", keywords: "checklist todo", action: .menu(NotesAX.formatMenu, ["체크리스트", "Checklist"])),
        .init(title: "블록 인용", icon: "text.quote", keywords: "quote", action: .menu(NotesAX.formatMenu, ["블록 인용", "Block Quote"])),
        .init(title: "모노 스타일", icon: "chevron.left.forwardslash.chevron.right", keywords: "mono code", action: .menu(NotesAX.formatMenu, ["모노 스타일", "Monostyled"])),
        .init(title: "표", icon: "tablecells", keywords: "table", action: .menu(NotesAX.formatMenu, ["표", "Table"])),
    ]

    /// macOS Writing Tools (Apple Intelligence) from 편집 > 글쓰기 도구; NotesPlus runs no model itself.
    /// With no selection they work on the surrounding text, as Notes decides.
    static let writingTools: [SlashCommand] = [
        .init(title: "이어 쓰기", icon: "pencil.line", keywords: "continue compose 작문 write", action: .menu(NotesAX.editMenu, ["작문…", "Compose…"])),
        .init(title: "다듬기", icon: "sparkles", keywords: "improve rewrite 재작성", action: .menu(NotesAX.editMenu, ["재작성", "Rewrite"])),
        .init(title: "요약", icon: "paperclip", keywords: "summarize summary", action: .menu(NotesAX.editMenu, ["요약", "Summarize"])),
        .init(title: "맞춤법·문법 교정", icon: "checkmark", keywords: "fix spelling grammar proofread 교정", action: .menu(NotesAX.editMenu, ["교정", "Proofread"])),
        .init(title: "간결하게", icon: "text.alignleft", keywords: "shorter concise 짧게", action: .menu(NotesAX.editMenu, ["간결하게 만들기", "Make Concise"])),
        .init(title: "친근하게", icon: "face.smiling", keywords: "friendly tone", action: .menu(NotesAX.editMenu, ["친근하게 만들기", "Make Friendly"])),
        .init(title: "전문적으로", icon: "briefcase", keywords: "professional tone", action: .menu(NotesAX.editMenu, ["전문적으로 만들기", "Make Professional"])),
        .init(title: "키 포인트", icon: "list.star", keywords: "key points", action: .menu(NotesAX.editMenu, ["키 포인트 생성", "Key Points"])),
        .init(title: "직접 요청", icon: "questionmark.square", keywords: "custom prompt ai 글쓰기 도구 longer 길게", action: .menu(NotesAX.editMenu, ["글쓰기 도구 표시", "Show Writing Tools"])),
    ]

    static func all() -> [SlashCommand] {
        formats + writingTools + Templates.all().map {
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
