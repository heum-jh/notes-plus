import SwiftUI

/// Window for choosing which format bar buttons show, their order, and where separator lines go.
struct BarSettingsView: View {
    private struct Row: Identifiable {
        let id = UUID()
        let key: String
    }

    let onChange: () -> Void
    @State private var rows = FormatBar.order(Settings.barLayout).map { Row(key: $0) }
    @State private var hidden = Settings.hiddenBarItems
    @State private var preview = FormatBarModel()

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("미리보기").font(.caption).foregroundStyle(.secondary)
            FormatBarView(model: preview) { _ in }
            Text("체크로 표시 여부를 정하고, 끌어서 순서를 바꿉니다.").font(.caption).foregroundStyle(.secondary)
            List {
                ForEach(rows) { row in rowView(row) }
                    .onMove { rows.move(fromOffsets: $0, toOffset: $1); save() }
            }
            HStack {
                Button("구분선 추가") { rows.append(Row(key: FormatBar.separatorKey)); save() }
                Spacer()
                Button("기본값으로") {
                    rows = FormatBar.order([]).map { Row(key: $0) }
                    hidden = []
                    save()
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear { refreshPreview() }
    }

    @ViewBuilder
    private func rowView(_ row: Row) -> some View {
        if row.key == FormatBar.separatorKey {
            HStack {
                Image(systemName: "minus")
                Text("구분선")
                Spacer()
                Button { rows.removeAll { $0.id == row.id }; save() } label: { Image(systemName: "trash") }
                    .buttonStyle(.borderless)
            }
        } else if let button = FormatBar.buttons.first(where: { $0.icon == row.key }) {
            let shown = !hidden.contains(row.key)
            Toggle(isOn: Binding(get: { shown }, set: { setShown(row.key, $0) })) {
                Label(button.help, systemImage: button.icon)
            }
            // The last visible button stays on; an empty bar would be a blank pill.
            .disabled(shown && FormatBar.buttons.filter { !hidden.contains($0.icon) }.count == 1)
        }
    }

    private func setShown(_ key: String, _ shown: Bool) {
        if shown { hidden.remove(key) } else { hidden.insert(key) }
        save()
    }

    private func save() {
        Settings.barLayout = rows.map(\.key)
        Settings.hiddenBarItems = hidden
        refreshPreview()
        onChange()
    }

    private func refreshPreview() {
        preview.layout = rows.map(\.key)
        preview.hidden = hidden
    }
}
