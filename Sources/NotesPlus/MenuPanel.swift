import SwiftUI

/// Every row of the menu bar panel. All of them can be reordered by dragging.
enum MenuEntry: String, CaseIterable, Identifiable {
    case slash, markdown, formatBar, backlinks, login, settings, templates, update, quit

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
        case .templates: "템플릿 폴더 열기"
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
        case .templates: "템플릿 파일을 추가하고 정리"
        case .update: "새 버전이 있는지 확인"
        case .quit: "메뉴 막대에서 내려요"
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
        case .templates: "folder.fill"
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
        case .templates: .brown
        case .update: .cyan
        case .quit: .red
        }
    }

    /// Saved order made complete: unknown or repeated rows dropped, rows added since the order was saved appended.
    static func ordered(_ saved: [String]) -> [MenuEntry] {
        var seen = Set<MenuEntry>()
        // "barSettings" is the pre-0.1.3 name of the settings row.
        let known = saved.map { $0 == "barSettings" ? "settings" : $0 }.compactMap(MenuEntry.init(rawValue:)).filter { seen.insert($0).inserted }
        return known + allCases.filter { !seen.contains($0) }
    }

    static func selfTest() {
        precondition(ordered([]) == allCases)
        precondition(ordered(["quit", "nope", "slash", "quit"]).prefix(2) == [.quit, .slash])
        precondition(ordered(["quit"]).count == allCases.count)
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
    static let size = NSSize(width: 320, height: 540)

    let actions: MenuActions
    @State private var order = MenuEntry.ordered(Settings.menuOrder)
    @State private var features = Dictionary(uniqueKeysWithValues: Settings.Feature.allCases.map { ($0, Settings.isOn($0)) })
    @State private var login = false

    var body: some View {
        VStack(spacing: 0) {
            header
            List {
                ForEach(order) { entry in
                    MenuRow(entry: entry, isOn: binding(for: entry)) { actions.run(entry) }
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                        .listRowInsets(EdgeInsets(top: 1, leading: 8, bottom: 1, trailing: 8))
                }
                .onMove { order.move(fromOffsets: $0, toOffset: $1); Settings.menuOrder = order.map(\.rawValue) }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            Text("행을 끌어서 순서를 바꿀 수 있어요")
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .padding(.vertical, 8)
        }
        .frame(width: Self.size.width, height: Self.size.height)
        .onAppear { login = actions.loginEnabled() }
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

    /// Switch rows get a binding; plain action rows get nil.
    private func binding(for entry: MenuEntry) -> Binding<Bool>? {
        if let feature = entry.feature {
            return Binding(get: { features[feature] ?? true }, set: { features[feature] = $0; actions.setFeature(feature, $0) })
        }
        if entry == .login {
            return Binding(get: { login }, set: { login = actions.setLogin($0) })
        }
        return nil
    }
}

private struct MenuRow: View {
    let entry: MenuEntry
    let isOn: Binding<Bool>?
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
            VStack(alignment: .leading, spacing: 1) {
                Text(entry.title).font(.system(size: 13, weight: .medium))
                Text(entry.subtitle).font(.caption2).foregroundStyle(.secondary).lineLimit(1)
            }
            Spacer(minLength: 4)
            Image(systemName: "line.3.horizontal")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .opacity(hovering ? 1 : 0)
            if let isOn {
                Toggle("", isOn: isOn).toggleStyle(.switch).controlSize(.small).labelsHidden()
            } else {
                Image(systemName: "chevron.right").font(.caption).foregroundStyle(.tertiary)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(RoundedRectangle(cornerRadius: 9).fill(Color.primary.opacity(hovering ? 0.08 : 0)))
        .contentShape(Rectangle())
        .onHover { hovering = $0 }
        .onTapGesture {
            if let isOn { isOn.wrappedValue.toggle() } else { action() }
        }
        .animation(.snappy(duration: 0.18), value: hovering)
    }
}
