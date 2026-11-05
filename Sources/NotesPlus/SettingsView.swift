import SwiftUI

/// Settings window: sidebar of panes on the left, the selected pane on the right.
struct SettingsView: View {
    private enum Pane: CaseIterable, Identifiable {
        case general, slash, templates, bar

        var id: Self { self }
        var title: String {
            switch self {
            case .general: "일반"
            case .slash: "/ 명령"
            case .templates: "템플릿"
            case .bar: "서식 바"
            }
        }
        var symbol: String {
            switch self {
            case .general: "gearshape.fill"
            case .slash: "slash.circle.fill"
            case .templates: "doc.text.fill"
            case .bar: "textformat"
            }
        }
        var color: Color {
            switch self {
            case .general: .gray
            case .slash: .blue
            case .templates: .brown
            case .bar: .orange
            }
        }
    }

    let actions: MenuActions
    let onBarChange: () -> Void
    @State private var pane = Pane.general

    var body: some View {
        HStack(spacing: 0) {
            sidebar
            Divider()
            Group {
                switch pane {
                case .general: GeneralSettings(actions: actions)
                case .slash: SlashSettingsView()
                case .templates: TemplatesPane()
                case .bar: BarSettingsView(onChange: onBarChange)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(width: 820, height: 740)
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 10) {
                Image(nsImage: NSApp.applicationIconImage).resizable().frame(width: 32, height: 32)
                VStack(alignment: .leading, spacing: 0) {
                    Text("NotesPlus").font(.headline)
                    Text("버전 \(actions.version)").font(.caption2).foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 8)
            .padding(.bottom, 14)
            ForEach(Pane.allCases) { item in
                SidebarItem(title: item.title, symbol: item.symbol, color: item.color, selected: pane == item) {
                    withAnimation(.snappy(duration: 0.2)) { pane = item }
                }
            }
            Spacer()
        }
        .padding(12)
        .padding(.top, 8)
        .frame(width: 190)
        .background(Color.primary.opacity(0.04))
    }
}

private struct SidebarItem: View {
    let title: String
    let symbol: String
    let color: Color
    let selected: Bool
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: symbol)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 24, height: 24)
                .background(color.gradient, in: RoundedRectangle(cornerRadius: 6))
            Text(title).font(.system(size: 13, weight: selected ? .semibold : .regular))
            Spacer()
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(RoundedRectangle(cornerRadius: 8).fill(selected ? Color.accentColor.opacity(0.22) : Color.primary.opacity(hovering ? 0.07 : 0)))
        .contentShape(Rectangle())
        .onHover { hovering = $0 }
        .onTapGesture(perform: action)
        .animation(.snappy(duration: 0.15), value: hovering)
    }
}

/// Title block at the top of a pane.
struct PaneHeader: View {
    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).font(.title2.weight(.bold))
            Text(subtitle).font(.callout).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct GeneralSettings: View {
    let actions: MenuActions
    @State private var features = Dictionary(uniqueKeysWithValues: Settings.Feature.allCases.map { ($0, Settings.isOn($0)) })
    @State private var login = false
    @State private var orderReset = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                PaneHeader(title: "일반", subtitle: "Notes에 더해지는 기능을 켜고 끕니다.")
                card("기능") {
                    let entries = MenuEntry.allCases.filter { $0.feature != nil }
                    ForEach(entries) { entry in
                        if let feature = entry.feature {
                            toggleRow(entry, Binding(get: { features[feature] ?? true }, set: { features[feature] = $0; actions.setFeature(feature, $0) }))
                            if entry != entries.last { Divider().padding(.leading, 52) }
                        }
                    }
                }
                card("시작") {
                    toggleRow(.login, Binding(get: { login }, set: { login = actions.setLogin($0) }))
                }
                card("메뉴 막대 패널") {
                    HStack {
                        VStack(alignment: .leading, spacing: 1) {
                            Text("행 순서").font(.system(size: 13, weight: .medium))
                            Text("패널에서 행을 끌어서 바꾼 순서를 되돌립니다.").font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button(orderReset ? "초기화됨" : "초기화") {
                            Settings.menuOrder = []
                            orderReset = true
                        }
                        .disabled(orderReset)
                    }
                    .padding(12)
                }
                card("앱") {
                    settingRow(.update) { Button("확인") { actions.run(.update) } }
                    Divider().padding(.leading, 52)
                    settingRow(.quit) { Button("종료", role: .destructive) { actions.run(.quit) } }
                }
            }
            .padding(20)
        }
        .onAppear { login = actions.loginEnabled() }
    }

    private func card<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.caption.weight(.semibold)).foregroundStyle(.secondary).padding(.leading, 4)
            VStack(spacing: 0, content: content)
                .background(RoundedRectangle(cornerRadius: 12).fill(.quaternary.opacity(0.35)))
        }
    }

    private func toggleRow(_ entry: MenuEntry, _ isOn: Binding<Bool>) -> some View {
        settingRow(entry) { Toggle("", isOn: isOn).toggleStyle(.switch).labelsHidden() }
            .contentShape(Rectangle())
            .onTapGesture { isOn.wrappedValue.toggle() }
    }

    private func settingRow(_ entry: MenuEntry, @ViewBuilder trailing: () -> some View) -> some View {
        HStack(spacing: 12) {
            Image(systemName: entry.symbol)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 28, height: 28)
                .background(entry.color.gradient, in: RoundedRectangle(cornerRadius: 7))
            VStack(alignment: .leading, spacing: 1) {
                Text(entry.title).font(.system(size: 13, weight: .medium))
                Text(entry.subtitle).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            trailing()
        }
        .padding(12)
    }
}
