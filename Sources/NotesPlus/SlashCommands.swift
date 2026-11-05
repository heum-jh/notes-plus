import Foundation

struct SlashCommand {
    enum Action {
        /// Notes menu (`NotesAX.formatMenu`/`editMenu`) and item titles (Korean, English).
        case menu([String], [String])
        case template(URL)
        /// Custom AX action of the table cell under the caret (names are Notes' own, English).
        /// `|` separates alternative names; the first one the cell exposes is used.
        case table(String)
        /// Text inserted at the caret, after `{{date}}`-style variables are filled in.
        case text(String)
        /// Submenu opened with → (cascader); typing a query searches its leaves flat.
        case group([SlashCommand])
    }

    let title: String
    let icon: String
    let keywords: String
    let action: Action
    /// Draws a separator above this row to mark the start of a section.
    var dividerBefore = false

    func matches(_ query: String) -> Bool {
        query.isEmpty || title.localizedCaseInsensitiveContains(query) || keywords.localizedCaseInsensitiveContains(query)
    }

    // ponytail: English titles are unverified guesses; only the Korean menu was probed on macOS 27.
    static let formats: [SlashCommand] = [
        .init(title: "제목", icon: "textformat.size.larger", keywords: "title", action: .menu(NotesAX.formatMenu, ["제목", "Title"])),
        .init(title: "머리말", icon: "textformat.size", keywords: "heading h1", action: .menu(NotesAX.formatMenu, ["머리말", "Heading"])),
        .init(title: "부머리말", icon: "textformat.size.smaller", keywords: "subheading h2", action: .menu(NotesAX.formatMenu, ["부머리말", "Subheading"])),
        .init(title: "본문", icon: "text.alignleft", keywords: "body text", action: .menu(NotesAX.formatMenu, ["본문", "Body"])),
        .init(title: "구분점 목록", icon: "list.bullet", keywords: "bullet ul list", action: .menu(NotesAX.formatMenu, ["구분점 목록", "Bulleted List"]), dividerBefore: true),
        .init(title: "대시 목록", icon: "list.dash", keywords: "dash list", action: .menu(NotesAX.formatMenu, ["대시 목록", "Dashed List"])),
        .init(title: "번호 목록", icon: "list.number", keywords: "numbered ol list", action: .menu(NotesAX.formatMenu, ["번호 목록", "Numbered List"])),
        .init(title: "체크리스트", icon: "checklist", keywords: "checklist todo", action: .menu(NotesAX.formatMenu, ["체크리스트", "Checklist"])),
        .init(title: "블록 인용", icon: "text.quote", keywords: "quote", action: .menu(NotesAX.formatMenu, ["블록 인용", "Block Quote"]), dividerBefore: true),
        .init(title: "모노 스타일", icon: "chevron.left.forwardslash.chevron.right", keywords: "mono code", action: .menu(NotesAX.formatMenu, ["모노 스타일", "Monostyled"])),
        .init(title: "표", icon: "tablecells", keywords: "table", action: .menu(NotesAX.formatMenu, ["표", "Table"])),
    ]

    /// macOS Writing Tools (Apple Intelligence) from 편집 > 글쓰기 도구; NotesPlus runs no model itself.
    /// With no selection they work on the surrounding text, as Notes decides.
    static let writingTools: [SlashCommand] = [
        .init(title: "이어 쓰기", icon: "pencil.line", keywords: "continue compose 작문 write chatgpt gpt", action: .menu(NotesAX.editMenu, ["작문…", "Compose…"])),
        .init(title: "다듬기", icon: "sparkles", keywords: "improve rewrite 재작성", action: .menu(NotesAX.editMenu, ["재작성", "Rewrite"])),
        .init(title: "요약", icon: "paperclip", keywords: "summarize summary", action: .menu(NotesAX.editMenu, ["요약", "Summarize"])),
        .init(title: "맞춤법·문법 교정", icon: "checkmark", keywords: "fix spelling grammar proofread 교정", action: .menu(NotesAX.editMenu, ["교정", "Proofread"])),
        .init(title: "간결하게", icon: "text.alignleft", keywords: "shorter concise 짧게", action: .menu(NotesAX.editMenu, ["간결하게 만들기", "Make Concise"])),
        .init(title: "친근하게", icon: "face.smiling", keywords: "friendly tone", action: .menu(NotesAX.editMenu, ["친근하게 만들기", "Make Friendly"])),
        .init(title: "전문적으로", icon: "briefcase", keywords: "professional tone", action: .menu(NotesAX.editMenu, ["전문적으로 만들기", "Make Professional"])),
        .init(title: "키 포인트", icon: "list.star", keywords: "key points", action: .menu(NotesAX.editMenu, ["키 포인트 생성", "Key Points"])),
        .init(title: "직접 요청", icon: "questionmark.square", keywords: "custom prompt ai 글쓰기 도구 longer 길게 chatgpt gpt", action: .menu(NotesAX.editMenu, ["글쓰기 도구 표시", "Show Writing Tools"])),
    ]

    /// Notes has ⌘⌥+arrow shortcuts for adding rows/columns but none for deleting; the menu lists both.
    static let tableCommands: [SlashCommand] = [
        // ponytail: add-row/column action names are best guesses; a miss is logged with the names the cell really exposes.
        .init(title: "위에 행 추가", icon: "rectangle.badge.plus", keywords: "add row above insert 행 추가", action: .table("Add row above|Insert row above|Add Row Above")),
        .init(title: "아래에 행 추가", icon: "rectangle.badge.plus", keywords: "add row below insert 행 추가", action: .table("Add row below|Insert row below|Add Row Below")),
        .init(title: "왼쪽에 열 추가", icon: "rectangle.badge.plus", keywords: "add column left before insert 열 추가", action: .table("Add column before|Add column left|Insert column before|Add Column Before")),
        .init(title: "오른쪽에 열 추가", icon: "rectangle.badge.plus", keywords: "add column right after insert 열 추가", action: .table("Add column after|Add column right|Insert column after|Add Column After")),
        .init(title: "행 삭제", icon: "rectangle.badge.minus", keywords: "delete row 삭제", action: .table("Delete rows")),
        .init(title: "열 삭제", icon: "rectangle.badge.minus", keywords: "delete column 삭제", action: .table("Delete columns")),
    ]

    static let insertions: [SlashCommand] = [
        .init(title: "구분선", icon: "minus", keywords: "divider line hr separator 분리자", action: .menu(NotesAX.editMenu, NotesAX.dividerItem), dividerBefore: true),
        .init(title: "오늘 날짜", icon: "calendar", keywords: "date today 날짜", action: .text("{{date}}")),
        .init(title: "현재 시간", icon: "clock", keywords: "time now 시간", action: .text("{{time}}")),
        .init(title: "날짜와 시간", icon: "calendar.badge.clock", keywords: "datetime 날짜 시간", action: .text("{{datetime}}")),
    ]

    /// Everything the / menu can list, in default order, each marked with the default section divider above it.
    /// The templates group is always here (even when empty) so the settings editor can place it.
    static func rootItems() -> [SlashCommand] {
        formats
            + [.init(title: "글쓰기 도구", icon: "wand.and.stars", keywords: "writing tools ai", action: .group(writingTools), dividerBefore: true),
               .init(title: "템플릿", icon: "doc.text", keywords: "template", action: .group(Templates.tree()))]
            + insertions
    }

    /// Titles and separators in display order: the saved layout completed, or the default when never customized.
    static func order(_ saved: [String], _ roots: [SlashCommand]) -> [String] {
        let fallback = roots.flatMap { ($0.dividerBefore ? [LayoutKeys.separator] : []) + [$0.title] }
        return LayoutKeys.order(saved, known: roots.map(\.title), fallback: fallback)
    }

    /// Roots in the user's order without hidden ones. Separators become `dividerBefore`, never leading or doubled.
    static func arrange(_ roots: [SlashCommand], layout: [String], hidden: Set<String>) -> [SlashCommand] {
        let byTitle = Dictionary(uniqueKeysWithValues: roots.map { ($0.title, $0) })
        var result: [SlashCommand] = []
        var separatorPending = false
        for key in order(layout, roots) {
            if key == LayoutKeys.separator { separatorPending = !result.isEmpty; continue }
            guard !hidden.contains(key), var item = byTitle[key] else { continue }
            item.dividerBefore = separatorPending
            separatorPending = false
            result.append(item)
        }
        return result
    }

    static func tree(inTable: Bool = false) -> [SlashCommand] {
        // An empty templates group would be a dead row.
        let roots = rootItems().filter { !($0.isGroup && $0.leaves.isEmpty) }
        var items = arrange(roots, layout: Settings.slashLayout, hidden: Settings.hiddenSlashItems)
        // Separator between the table commands and the rest.
        if inTable, !items.isEmpty { items[0].dividerBefore = true }
        return (inTable ? tableCommands : []) + items
    }

    var isGroup: Bool { if case .group = action { true } else { false } }

    /// Selectable commands under this one, for flat search.
    var leaves: [SlashCommand] {
        if case .group(let children) = action { children.flatMap(\.leaves) } else { [self] }
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

    /// Fills `{{date}}`, `{{weekday}}`, `{{time}}` and `{{datetime}}` with the current moment.
    static func render(_ text: String, now: Date = Date()) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.calendar = Calendar(identifier: .gregorian)
        func format(_ pattern: String) -> String {
            formatter.dateFormat = pattern
            return formatter.string(from: now)
        }
        return text
            .replacingOccurrences(of: "{{datetime}}", with: format("yyyy년 M월 d일 a h:mm"))
            .replacingOccurrences(of: "{{date}}", with: format("yyyy년 M월 d일"))
            .replacingOccurrences(of: "{{weekday}}", with: format("EEEE"))
            .replacingOccurrences(of: "{{time}}", with: format("a h:mm"))
    }

    /// Subfolders become submenus, `.md`/`.txt` files become templates.
    static func tree(at dir: URL = directory) -> [SlashCommand] {
        let urls = (try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: [.isDirectoryKey], options: .skipsHiddenFiles)) ?? []
        let sorted = urls.sorted { $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending }
        let folders: [SlashCommand] = sorted.filter { (try? $0.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true }.compactMap {
            let children = tree(at: $0)
            return children.isEmpty ? nil : .init(title: $0.lastPathComponent, icon: "folder", keywords: "", action: .group(children))
        }
        let files: [SlashCommand] = sorted.filter { ["md", "txt"].contains($0.pathExtension) }.map {
            .init(title: $0.deletingPathExtension().lastPathComponent, icon: "doc.text", keywords: "template 템플릿", action: .template($0))
        }
        return folders + files
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

        // / menu layout: default order and dividers, hidden rows, separators that never lead or double up.
        let roots = SlashCommand.rootItems()
        precondition(Set(roots.map(\.title)).count == roots.count, "root titles must be unique")
        let standard = SlashCommand.arrange(roots, layout: [], hidden: [])
        precondition(standard.map(\.title) == roots.map(\.title) && !standard[0].dividerBefore)
        precondition(standard.filter(\.dividerBefore).map(\.title) == ["구분점 목록", "블록 인용", "글쓰기 도구", "구분선"])
        let custom = SlashCommand.arrange(roots, layout: ["|", "표", "|", "|", "제목"], hidden: ["본문"])
        precondition(custom.prefix(2).map(\.title) == ["표", "제목"] && !custom[0].dividerBefore && custom[1].dividerBefore)
        precondition(!custom.contains { $0.title == "본문" })

        // Templates: folders become submenus, empty folders and other file types are skipped, search sees only leaves.
        let dir = FileManager.default.temporaryDirectory.appending(path: "notesplus-selftest-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: dir) }
        let fm = FileManager.default
        try! fm.createDirectory(at: dir.appending(path: "work"), withIntermediateDirectories: true)
        try! fm.createDirectory(at: dir.appending(path: "empty"), withIntermediateDirectories: true)
        try! "a".write(to: dir.appending(path: "top.md"), atomically: true, encoding: .utf8)
        try! "b".write(to: dir.appending(path: "work/inner.txt"), atomically: true, encoding: .utf8)
        try! "c".write(to: dir.appending(path: "ignored.png"), atomically: true, encoding: .utf8)
        let tree = Templates.tree(at: dir)
        precondition(tree.map(\.title) == ["work", "top"], "tree = \(tree.map(\.title))")
        precondition(tree.flatMap(\.leaves).map(\.title) == ["inner", "top"])
        let moment = Calendar(identifier: .gregorian).date(from: DateComponents(year: 2026, month: 11, day: 5, hour: 15, minute: 5))!
        precondition(Templates.render("{{date}} {{weekday}} {{time}}", now: moment) == "2026년 11월 5일 목요일 오후 3:05")
        precondition(Templates.render("{{datetime}}|{{unknown}}", now: moment) == "2026년 11월 5일 오후 3:05|{{unknown}}")
        precondition(SlashCommand.tree().contains { $0.isGroup && $0.title == "글쓰기 도구" })
    }
}
