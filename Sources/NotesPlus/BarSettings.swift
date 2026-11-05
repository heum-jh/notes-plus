import SwiftUI

/// Editor for the format bar: which buttons show, their order, and where separator lines go.
struct BarSettingsView: View {
    private struct Row: Identifiable {
        let id = UUID()
        let key: String
        var isSeparator: Bool { key == FormatBar.separatorKey }
    }

    let onChange: () -> Void
    @State private var rows = FormatBar.order(Settings.barLayout).map { Row(key: $0) }
    @State private var hidden = Settings.hiddenBarItems
    @State private var preview = FormatBarModel()

    private var shownCount: Int { FormatBar.buttons.filter { !hidden.contains($0.icon) }.count }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            previewCard
            HStack {
                Text("항목").font(.headline)
                Spacer()
                Text("\(shownCount)/\(FormatBar.buttons.count) 표시 중").font(.caption).foregroundStyle(.secondary)
                    .contentTransition(.numericText())
            }
            List {
                ForEach(Array(rows.enumerated()), id: \.element.id) { index, row in
                    BarRow(
                        button: FormatBar.buttons.first { $0.icon == row.key },
                        shown: !hidden.contains(row.key),
                        isLastShown: shownCount == 1,
                        onToggle: { setShown(row.key, $0) },
                        onInsertSeparator: { rows.insert(Row(key: FormatBar.separatorKey), at: index + 1); save() },
                        onDelete: { rows.removeAll { $0.id == row.id }; save() },
                        onHover: { preview.highlighted = $0 ? row.key : nil }
                    )
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets(top: 1, leading: 4, bottom: 1, trailing: 4))
                }
                .onMove { rows.move(fromOffsets: $0, toOffset: $1); save() }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(RoundedRectangle(cornerRadius: 12).fill(.quaternary.opacity(0.35)))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            HStack {
                Button { rows.append(Row(key: FormatBar.separatorKey)); save() } label: {
                    Label("구분선 추가", systemImage: "plus")
                }
                Spacer()
                Text("행을 끌어서 순서를 바꿔요").font(.caption).foregroundStyle(.tertiary)
                Spacer()
                Button("기본값으로") {
                    withAnimation(.snappy) {
                        rows = FormatBar.order([]).map { Row(key: $0) }
                        hidden = []
                    }
                    save()
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear { refreshPreview() }
    }

    private var previewCard: some View {
        VStack(spacing: 8) {
            Text("미리보기").font(.caption).foregroundStyle(.secondary).frame(maxWidth: .infinity, alignment: .leading)
            // The bar can be wider than the window, so it scrolls instead of clipping.
            ScrollView(.horizontal, showsIndicators: false) {
                FormatBarView(model: preview) { _ in }
                    .fixedSize()
                    .padding(.vertical, 6)
                    .padding(.horizontal, 2)
            }
            .animation(.snappy(duration: 0.25), value: preview.hidden)
            .animation(.snappy(duration: 0.25), value: preview.layout)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(LinearGradient(colors: [Color.accentColor.opacity(0.16), Color.accentColor.opacity(0.04)], startPoint: .topLeading, endPoint: .bottomTrailing))
        )
        .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Color.accentColor.opacity(0.2)))
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

private struct BarRow: View {
    /// nil for a separator row.
    let button: FormatBar.Button?
    let shown: Bool
    let isLastShown: Bool
    let onToggle: (Bool) -> Void
    let onInsertSeparator: () -> Void
    let onDelete: () -> Void
    let onHover: (Bool) -> Void
    @State private var hovering = false

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "line.3.horizontal")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .opacity(hovering ? 1 : 0.35)
            if let button {
                buttonContent(button)
            } else {
                separatorContent
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(RoundedRectangle(cornerRadius: 9).fill(Color.primary.opacity(hovering ? 0.08 : 0)))
        .contentShape(Rectangle())
        .onHover { hovering = $0; onHover($0) }
        .animation(.snappy(duration: 0.18), value: hovering)
    }

    private func buttonContent(_ button: FormatBar.Button) -> some View {
        HStack(spacing: 10) {
            Image(systemName: button.icon)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(shown ? .white : .secondary)
                .frame(width: 28, height: 28)
                .background(
                    RoundedRectangle(cornerRadius: 7)
                        .fill(shown ? AnyShapeStyle(Color.accentColor.gradient) : AnyShapeStyle(.quaternary))
                )
            Text(button.help)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(shown ? .primary : .secondary)
                .strikethrough(!shown, color: .secondary)
            Spacer(minLength: 4)
            Button(action: onInsertSeparator) {
                Label("아래에 구분선", systemImage: "rectangle.split.1x2")
                    .labelStyle(.iconOnly)
            }
            .buttonStyle(.borderless)
            .help("이 아래에 구분선 추가")
            .opacity(hovering ? 1 : 0)
            Toggle("", isOn: Binding(get: { shown }, set: onToggle))
                .toggleStyle(.switch)
                .controlSize(.small)
                .labelsHidden()
                // The last visible button stays on; an empty bar would be a blank pill.
                .disabled(shown && isLastShown)
        }
    }

    private var separatorContent: some View {
        HStack(spacing: 8) {
            Capsule().fill(.secondary.opacity(0.35)).frame(height: 1.5)
            Text("구분선")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(Capsule().fill(.quaternary))
            Capsule().fill(.secondary.opacity(0.35)).frame(height: 1.5)
            Button(action: onDelete) { Image(systemName: "trash") }
                .buttonStyle(.borderless)
                .help("구분선 삭제")
                .opacity(hovering ? 1 : 0.4)
        }
        .frame(height: 28)
    }
}
