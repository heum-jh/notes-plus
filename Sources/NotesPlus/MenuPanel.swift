import SwiftUI

/// Settings rows and menu bar panel rows. The panel only lists `panelEntries`; the switches live in the settings window.
enum MenuEntry: String, CaseIterable, Identifiable {
    case slash, markdown, formatBar, backlinks, login, settings, update, quit

    var id: String { rawValue }

    var feature: Settings.Feature? {
        switch self {
        case .slash: .slash
        case .markdown: .markdown
        case .formatBar: .formatBar
        case .backlinks: .backlinks
        default: nil
        }
    }

    var title: String {
        if let feature { return feature.title }
        return switch self {
        case .login: "로그인 시 자동 실행"
        case .settings: "설정…"
        case .update: "업데이트 확인…"
        default: "NotesPlus 종료"
        }
    }

    var subtitle: String {
        switch self {
        case .slash: "/ 로 서식·템플릿·글쓰기 도구 삽입"
        case .markdown: "# , **굵게** 를 바로 서식으로"
        case .formatBar: "캐럿을 따라다니는 도구 모음"
        case .backlinks: "이 메모를 링크한 메모 보기"
        case .login: "Mac을 켤 때 함께 시작"
        case .settings: "기능 켜기·끄기, 서식 바 구성"
        case .update: "새 버전이 있는지 확인"
        case .quit: "NotesPlus를 종료합니다"
        }
    }

    var symbol: String {
        switch self {
        case .slash: "slash.circle.fill"
        case .markdown: "number.square.fill"
        case .formatBar: "textformat"
        case .backlinks: "arrow.uturn.backward.circle.fill"
        case .login: "power"
        case .settings: "gearshape.fill"
        case .update: "arrow.triangle.2.circlepath"
        case .quit: "xmark"
        }
    }

    var color: Color {
        switch self {
        case .slash: .blue
        case .markdown: .purple
        case .formatBar: .orange
        case .backlinks: .teal
        case .login: .green
        case .settings: .indigo
        case .update: .cyan
        case .quit: .red
        }
    }

    /// Rows of the menu bar panel, which can be reordered by dragging.
    static let panelEntries: [MenuEntry] = [.settings, .update, .quit]

    /// Saved order made complete: unknown or repeated rows dropped, rows added since the order was saved appended.
    static func ordered(_ saved: [String]) -> [MenuEntry] {
        var seen = Set<MenuEntry>()
        // "barSettings" is the pre-0.1.3 name of the settings row.
        let known = saved.map { $0 == "barSettings" ? "settings" : $0 }.compactMap(MenuEntry.init(rawValue:))
            .filter { panelEntries.contains($0) && seen.insert($0).inserted }
        return known + panelEntries.filter { !seen.contains($0) }
    }

    static func selfTest() {
        precondition(ordered([]) == panelEntries)
        // Rows that moved to the settings window (old saved orders include them) are dropped.
        precondition(ordered(["quit", "nope", "slash", "templates", "quit", "update"]) == [.quit, .update, .settings])
        precondition(ordered(["quit"]).count == panelEntries.count)
        precondition(ordered(["barSettings"]).first == .settings)
    }
}

/// What the panel can ask the app to do. Toggles return the state that actually took effect.
struct MenuActions {
    let version: String
    let setFeature: (Settings.Feature, Bool) -> Void
    let setLogin: (Bool) -> Bool
    let loginEnabled: () -> Bool
    let run: (MenuEntry) -> Void
}

struct MenuPanelView: View {
    static let size = NSSize(width: 280, height: 200)

    let actions: MenuActions
    @State private var order = MenuEntry.ordered(Settings.menuOrder)

    var body: some View {
        VStack(spacing: 0) {
            header
            List {
                ForEach(order) { entry in
                    MenuRow(entry: entry) { actions.run(entry) }
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                        .listRowInsets(EdgeInsets(top: 1, leading: 8, bottom: 1, trailing: 8))
                }
                .onMove { order.move(fromOffsets: $0, toOffset: $1); Settings.menuOrder = order.map(\.rawValue) }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
        }
        .frame(width: Self.size.width, height: Self.size.height)
    }

    private var header: some View {
        HStack(spacing: 12) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .frame(width: 40, height: 40)
                .shadow(color: .black.opacity(0.2), radius: 3, y: 1)
            VStack(alignment: .leading, spacing: 2) {
                Text("NotesPlus").font(.headline)
                Text("버전 \(actions.version)").font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(LinearGradient(colors: [Color.accentColor.opacity(0.18), .clear], startPoint: .top, endPoint: .bottom))
    }
}

private struct MenuRow: View {
    let entry: MenuEntry
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: entry.symbol)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 28, height: 28)
                .background(LinearGradient(colors: [entry.color.opacity(0.95), entry.color.opacity(0.7)], startPoint: .top, endPoint: .bottom),
                            in: RoundedRectangle(cornerRadius: 7))
                .shadow(color: entry.color.opacity(hovering ? 0.45 : 0.2), radius: hovering ? 5 : 2, y: 1)
            Text(entry.title).font(.system(size: 13, weight: .medium))
            Spacer(minLength: 4)
            Image(systemName: "line.3.horizontal")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .opacity(hovering ? 1 : 0)
            Image(systemName: "chevron.right").font(.caption).foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(RoundedRectangle(cornerRadius: 9).fill(Color.primary.opacity(hovering ? 0.08 : 0)))
        .contentShape(Rectangle())
        .onHover { hovering = $0 }
        .onTapGesture(perform: action)
        .animation(.snappy(duration: 0.18), value: hovering)
    }
}
