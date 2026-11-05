import SwiftUI

extension Templates {
    /// A template file or a folder of them, as shown in the settings tree.
    struct Entry: Identifiable, Hashable {
        let url: URL
        /// nil for a file.
        let children: [Entry]?

        var id: URL { url }
        var isFolder: Bool { children != nil }
        var name: String { isFolder ? url.lastPathComponent : url.deletingPathExtension().lastPathComponent }
    }

    /// Folders first, then `.md`/`.txt` files, each sorted naturally. Empty folders are kept so they can be filled.
    static func entries(at dir: URL = directory) -> [Entry] {
        let urls = (try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: [.isDirectoryKey], options: .skipsHiddenFiles)) ?? []
        let sorted = urls.sorted { $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending }
        let isFolder = { (url: URL) in (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true }
        return sorted.filter(isFolder).map { Entry(url: $0, children: entries(at: $0)) }
            + sorted.filter { !isFolder($0) && ["md", "txt"].contains($0.pathExtension) }.map { Entry(url: $0, children: nil) }
    }

    /// File-system safe name: no separators, no leading dot, nil when nothing is left.
    static func sanitized(_ name: String) -> String? {
        var clean = name.replacingOccurrences(of: "/", with: "-").replacingOccurrences(of: ":", with: "-")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        while clean.hasPrefix(".") { clean.removeFirst() }
        return clean.isEmpty ? nil : clean
    }

    /// `dir/name.ext`, or `dir/name 2.ext` and so on when taken.
    static func uniqueURL(in dir: URL, name: String, ext: String?) -> URL {
        func candidate(_ n: String) -> URL {
            let file = dir.appending(path: n)
            return ext.map { file.appendingPathExtension($0) } ?? file
        }
        var url = candidate(name)
        var number = 2
        while FileManager.default.fileExists(atPath: url.path) {
            url = candidate("\(name) \(number)")
            number += 1
        }
        return url
    }

    static func create(in dir: URL) -> URL? {
        let url = uniqueURL(in: dir, name: "새 템플릿", ext: "md")
        return (try? "".write(to: url, atomically: true, encoding: .utf8)) != nil ? url : nil
    }

    static func createFolder(in dir: URL) -> URL? {
        let url = uniqueURL(in: dir, name: "새 폴더", ext: nil)
        return (try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: false)) != nil ? url : nil
    }

    /// Renames keeping the extension. nil when the name is unusable or already taken.
    static func rename(_ url: URL, to newName: String) -> URL? {
        guard let clean = sanitized(newName) else { return nil }
        let ext = url.pathExtension
        let target = url.deletingLastPathComponent().appending(path: ext.isEmpty ? clean : "\(clean).\(ext)")
        if target == url { return url }
        guard !FileManager.default.fileExists(atPath: target.path), (try? FileManager.default.moveItem(at: url, to: target)) != nil else { return nil }
        return target
    }

    static func setExtension(_ url: URL, _ ext: String) -> URL? {
        let target = url.deletingPathExtension().appendingPathExtension(ext)
        if target == url { return url }
        guard !FileManager.default.fileExists(atPath: target.path), (try? FileManager.default.moveItem(at: url, to: target)) != nil else { return nil }
        return target
    }

    static func selfTest() {
        precondition(sanitized(" ../a/b: c ") == "-a-b- c" && sanitized("...") == nil && sanitized("  ") == nil)
        let dir = FileManager.default.temporaryDirectory.appending(path: "notesplus-templates-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: dir) }
        try! FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let first = create(in: dir)!, second = create(in: dir)!
        precondition(first.lastPathComponent == "새 템플릿.md" && second.lastPathComponent == "새 템플릿 2.md")
        let folder = createFolder(in: dir)!
        let moved = rename(first, to: "회의록")!
        precondition(moved.lastPathComponent == "회의록.md" && rename(second, to: "회의록") == nil)
        precondition(setExtension(moved, "txt")?.lastPathComponent == "회의록.txt")
        let names = entries(at: dir).map { $0.isFolder ? "[\($0.name)]" : $0.name }
        precondition(names == ["[새 폴더]", "새 템플릿 2", "회의록"], "entries = \(names)")
        precondition(entries(at: dir).first?.url.lastPathComponent == folder.lastPathComponent)
    }
}

/// Settings pane for creating, editing, renaming and deleting templates, which the / menu lists.
struct TemplatesPane: View {
    @State private var entries = Templates.entries()
    @State private var selection: URL?
    /// The file shown in the editor, and the text it was last loaded or saved with.
    @State private var loaded: URL?
    @State private var savedText = ""
    @State private var text = ""
    @State private var name = ""
    @FocusState private var nameFocused: Bool

    private var selected: Templates.Entry? { selection.flatMap { find($0, in: entries) } }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            PaneHeader(title: "템플릿", subtitle: "/ 메뉴의 \"템플릿\"에 나타납니다. 폴더는 하위 메뉴가 돼요.")
            HStack(alignment: .top, spacing: 12) {
                listCard.frame(width: 210)
                editorCard
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear { reload() }
        .onChange(of: selection) {
            commitRename()
            load()
        }
        .onChange(of: nameFocused) { if !nameFocused { commitRename() } }
        .onChange(of: text) { save() }
    }

    // MARK: List

    private var listCard: some View {
        VStack(spacing: 0) {
            if entries.isEmpty {
                Text("템플릿이 없어요.\n아래 + 로 만들어 보세요.")
                    .font(.caption)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(entries, children: \.children, selection: $selection) { entry in
                    Label(entry.name, systemImage: entry.isFolder ? "folder.fill" : "doc.text")
                        .lineLimit(1)
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
            }
            Divider()
            HStack(spacing: 4) {
                Button { add(folder: false) } label: { Label("템플릿", systemImage: "plus") }
                Button { add(folder: true) } label: { Label("폴더", systemImage: "folder.badge.plus") }
                Spacer()
                Button(role: .destructive) { deleteSelected() } label: { Image(systemName: "trash") }
                    .disabled(selected == nil)
                    .help("휴지통으로 이동")
            }
            .buttonStyle(.borderless)
            .padding(8)
        }
        .background(RoundedRectangle(cornerRadius: 12).fill(.quaternary.opacity(0.35)))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: Editor

    @ViewBuilder
    private var editorCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let selected {
                HStack(spacing: 8) {
                    Image(systemName: selected.isFolder ? "folder.fill" : "doc.text.fill")
                        .foregroundStyle(.brown)
                    TextField("이름", text: $name)
                        .textFieldStyle(.roundedBorder)
                        .focused($nameFocused)
                        .onSubmit { commitRename() }
                    if !selected.isFolder {
                        Picker("", selection: extensionBinding(selected)) {
                            Text("Markdown").tag("md")
                            Text("텍스트").tag("txt")
                        }
                        .pickerStyle(.segmented)
                        .labelsHidden()
                        .frame(width: 150)
                        .help("Markdown은 제목·체크리스트 같은 서식이 살아 있는 채로 삽입돼요")
                    }
                }
                if selected.isFolder {
                    Text("이 폴더 안의 템플릿은 / 메뉴에서 하위 메뉴로 나타나요.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                    Spacer()
                } else {
                    TextEditor(text: $text)
                        .font(.system(size: 13, design: .monospaced))
                        .scrollContentBackground(.hidden)
                        .padding(6)
                        .background(RoundedRectangle(cornerRadius: 8).fill(.background.opacity(0.6)))
                        .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(.quaternary))
                    variableBar
                }
            } else {
                Text("템플릿을 선택하거나 새로 만들어 보세요")
                    .font(.callout)
                    .foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(RoundedRectangle(cornerRadius: 12).fill(.quaternary.opacity(0.35)))
    }

    private var variableBar: some View {
        HStack(spacing: 6) {
            Text("변수").font(.caption).foregroundStyle(.secondary)
            ForEach([("날짜", "{{date}}"), ("요일", "{{weekday}}"), ("시간", "{{time}}"), ("날짜+시간", "{{datetime}}")], id: \.1) { label, token in
                Button(label) { text += token }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .help("\(token) 를 끝에 추가 — 삽입할 때 현재 값으로 바뀌어요")
            }
            Spacer()
        }
    }

    // MARK: Actions

    private func reload() { entries = Templates.entries() }

    private func find(_ url: URL, in list: [Templates.Entry]) -> Templates.Entry? {
        for entry in list {
            if entry.url == url { return entry }
            if let hit = entry.children.flatMap({ find(url, in: $0) }) { return hit }
        }
        return nil
    }

    private func load() {
        guard let selected else { loaded = nil; name = ""; text = ""; savedText = ""; return }
        name = selected.name
        if selected.isFolder {
            loaded = nil
            text = ""
            savedText = ""
        } else {
            let content = (try? String(contentsOf: selected.url, encoding: .utf8)) ?? ""
            savedText = content  // Set first so the text change below is not saved back.
            text = content
            loaded = selected.url
        }
    }

    /// Writes edits right away; templates are small and there is no save button.
    private func save() {
        guard let loaded, text != savedText else { return }
        do {
            try text.write(to: loaded, atomically: true, encoding: .utf8)
            savedText = text
        } catch {
            NSLog("NotesPlus: saving template failed: \(error)")
            NSSound.beep()
        }
    }

    /// Applies the typed name to the file or folder that was open when typing started.
    private func commitRename() {
        guard let current = loaded ?? selected?.url, let old = find(current, in: entries) ?? selected else { return }
        guard let clean = Templates.sanitized(name), clean != old.name else { name = old.name; return }
        if let renamed = Templates.rename(old.url, to: clean) {
            reload()
            if selection == old.url { selection = renamed }
            if loaded == old.url { loaded = renamed }
        } else {
            NSSound.beep()  // Taken or unusable: put the old name back.
            name = old.name
        }
    }

    private func extensionBinding(_ entry: Templates.Entry) -> Binding<String> {
        Binding(get: { entry.url.pathExtension }, set: { ext in
            guard let renamed = Templates.setExtension(entry.url, ext) else { NSSound.beep(); return }
            reload()
            selection = renamed
            loaded = renamed
        })
    }

    private func add(folder: Bool) {
        commitRename()
        let parent: URL
        if let selected, selected.isFolder { parent = selected.url } else if let selected { parent = selected.url.deletingLastPathComponent() } else { parent = Templates.directory }
        guard let url = folder ? Templates.createFolder(in: parent) : Templates.create(in: parent) else { NSSound.beep(); return }
        reload()
        selection = url
        // Let the editor appear, then focus the name so the new item can be named right away.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { nameFocused = true }
    }

    private func deleteSelected() {
        guard let selected else { return }
        try? FileManager.default.trashItem(at: selected.url, resultingItemURL: nil)
        selection = nil
        reload()
    }
}
