import SwiftUI

/// Settings window: the same switches as the menu bar panel, plus the format bar editor.
struct SettingsView: View {
    let actions: MenuActions
    let onBarChange: () -> Void

    var body: some View {
        TabView {
            GeneralSettings(actions: actions)
                .tabItem { Label("일반", systemImage: "gearshape") }
            BarSettingsView(onChange: onBarChange)
                .tabItem { Label("서식 바", systemImage: "textformat") }
        }
        .frame(width: 440, height: 640)
    }
}

private struct GeneralSettings: View {
    let actions: MenuActions
    @State private var features = Dictionary(uniqueKeysWithValues: Settings.Feature.allCases.map { ($0, Settings.isOn($0)) })
    @State private var login = false
    @State private var orderReset = false

    var body: some View {
        Form {
            Section("기능") {
                ForEach(MenuEntry.allCases.filter { $0.feature != nil }) { entry in
                    if let feature = entry.feature {
                        row(entry, Binding(get: { features[feature] ?? true }, set: { features[feature] = $0; actions.setFeature(feature, $0) }))
                    }
                }
            }
            Section("시작") {
                row(.login, Binding(get: { login }, set: { login = actions.setLogin($0) }))
            }
            Section("메뉴 막대 패널") {
                HStack {
                    Text("행 순서는 패널에서 끌어서 바꿉니다.").font(.caption).foregroundStyle(.secondary)
                    Spacer()
                    Button(orderReset ? "초기화됨" : "순서 초기화") {
                        Settings.menuOrder = []
                        orderReset = true
                    }
                    .disabled(orderReset)
                }
            }
        }
        .formStyle(.grouped)
        .onAppear { login = actions.loginEnabled() }
    }

    private func row(_ entry: MenuEntry, _ isOn: Binding<Bool>) -> some View {
        Toggle(isOn: isOn) {
            Label {
                VStack(alignment: .leading, spacing: 1) {
                    Text(entry.title)
                    Text(entry.subtitle).font(.caption).foregroundStyle(.secondary)
                }
            } icon: {
                Image(systemName: entry.symbol)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 24, height: 24)
                    .background(entry.color.gradient, in: RoundedRectangle(cornerRadius: 6))
            }
        }
        .toggleStyle(.switch)
    }
}
