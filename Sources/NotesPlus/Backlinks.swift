import AppKit
import Observation
import SQLite3
import SwiftUI

/// Shows which notes link to the current note, read from the Notes database.
final class Backlinks {
    private let model = BacklinksModel()
    private lazy var panel = FloatingPanel(BacklinksView(model: model))
    private var lastIdentifier: String?

    func update() {
        guard let el = NotesAX.focusedTextArea(), let id = NotesAX.noteIdentifier(el), let window = NotesAX.focusedWindowFrame() else {
            if NotesAX.frontmostNotes == nil { panel.orderOut(nil) }
            return
        }
        // ponytail: re-queried only when switching notes; links added to other notes show up on the next switch.
        if id != lastIdentifier {
            lastIdentifier = id
            switch NotesDB.backlinks(to: id) {
            case .success(let notes): model.state = notes.isEmpty ? .empty : .notes(notes)
            case .failure(.noAccess):
                model.state = .noAccess
                lastIdentifier = nil  // Retry on the next change, so granting access takes effect without switching notes.
            case .failure(.failed(let message)): NSLog("NotesPlus: backlinks query failed: \(message)"); model.state = .empty
            }
        }
        guard model.state != .empty else { panel.orderOut(nil); return }
        panel.show(bottomRight: NSPoint(x: window.maxX - 16, y: window.minY + 16))
    }

    /// `[[` opens Notes' own note-link picker, which is triggered by typing `>>`.
    static func convertWikiLinkTrigger() {
        guard let el = NotesAX.focusedTextArea(), let text = NotesAX.value(el),
              let sel = NotesAX.selectedRange(el), sel.length == 0, sel.location >= 2,
              (text as NSString).substring(with: NSRange(location: sel.location - 2, length: 2)) == "[[" else { return }
        NotesAX.setSelectedRange(el, NSRange(location: sel.location - 2, length: 2))
        NotesAX.insert(el, "")
        NotesAX.type(">>")
    }
}

enum NotesDB {
    struct Note: Equatable {
        let identifier: String
        let title: String
    }

    enum Failure: Error {
        case noAccess
        case failed(String)
    }

    static let path = FileManager.default.homeDirectoryForCurrentUser
        .appending(path: "Library/Group Containers/group.com.apple.notes/NoteStore.sqlite").path

    /// Notes containing a note-link attachment that points at `identifier`.
    static func backlinks(to identifier: String) -> Result<[Note], Failure> {
        var db: OpaquePointer?
        defer { sqlite3_close(db) }
        guard sqlite3_open_v2(path, &db, SQLITE_OPEN_READONLY, nil) == SQLITE_OK else { return .failure(failure(db)) }
        let sql = """
            SELECT DISTINCT note.ZIDENTIFIER, note.ZTITLE1
            FROM ZICCLOUDSYNCINGOBJECT AS link
            JOIN ZICCLOUDSYNCINGOBJECT AS note ON note.Z_PK = link.ZNOTE1
            WHERE link.ZTYPEUTI1 = 'com.apple.notes.inlinetextattachment.link'
              AND link.ZTOKENCONTENTIDENTIFIER LIKE ?
              AND note.ZIDENTIFIER != ?
              AND IFNULL(note.ZMARKEDFORDELETION, 0) != 1
            ORDER BY note.ZMODIFICATIONDATE1 DESC
            """
        var stmt: OpaquePointer?
        defer { sqlite3_finalize(stmt) }
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return .failure(failure(db)) }
        let transient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
        sqlite3_bind_text(stmt, 1, "applenotes:note/\(identifier)%", -1, transient)
        sqlite3_bind_text(stmt, 2, identifier, -1, transient)
        var notes: [Note] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            guard let id = sqlite3_column_text(stmt, 0) else { continue }
            let title = sqlite3_column_text(stmt, 1).map { String(cString: $0) } ?? "제목 없음"
            notes.append(Note(identifier: String(cString: id), title: title))
        }
        return .success(notes)
    }

    /// Without Full Disk Access the Group Container is unreadable (SQLITE_AUTH / SQLITE_CANTOPEN).
    private static func failure(_ db: OpaquePointer?) -> Failure {
        let code = sqlite3_errcode(db)
        if code == SQLITE_AUTH || code == SQLITE_CANTOPEN || code == SQLITE_PERM { return .noAccess }
        return .failed(String(cString: sqlite3_errmsg(db)))
    }
}

@Observable
final class BacklinksModel {
    enum State: Equatable {
        case empty
        case noAccess
        case notes([NotesDB.Note])
    }

    var state = State.empty
}

struct BacklinksView: View {
    let model: BacklinksModel

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            switch model.state {
            case .empty:
                EmptyView()
            case .noAccess:
                Button("백링크: 전체 디스크 접근 권한 필요") {
                    NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles")!)
                }
                .buttonStyle(.link)
            case .notes(let notes):
                Text("백링크 \(notes.count)").font(.caption).foregroundStyle(.secondary)
                // ponytail: first 8 only; add scrolling for heavily linked notes.
                ForEach(notes.prefix(8), id: \.identifier) { note in
                    Button {
                        NSWorkspace.shared.open(URL(string: "applenotes://showNote?identifier=\(note.identifier)")!)
                    } label: {
                        Label(note.title, systemImage: "arrow.uturn.backward").lineLimit(1)
                    }
                    .buttonStyle(.borderless)
                }
            }
        }
        .padding(10)
        .frame(width: 240, alignment: .leading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10))
    }
}
