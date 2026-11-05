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
    @State private var shownExpanded = true
    /// Collapsed by default: hidden buttons are rarely touched.
    @State private var hiddenExpanded = false

    private var shownCount: Int { FormatBar.buttons.filter { !hidden.contains($0.icon) }.count }
    /// The ON area: shown buttons and separators, in bar order. Hidden buttons trail in the saved layout.
    private var shownRows: [Row] { rows.filter { $0.isSeparator || !hidden.contains($0.key) } }
    private var hiddenRows: [Row] { rows.filter { !$0.isSeparator && hidden.contains($0.key) } }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            PaneHeader(title: "서식 바", subtitle: "표시할 버튼과 순서, 구분선을 정합니다.")
            previewCard
            // Two separate cards so the ON and OFF areas stay visible side by side without scrolling.
            areaCard(header: areaHeader("표시 중", symbol: "eye.fill", count: shownCount, tint: .accentColor, expanded: $shownExpanded), expanded: shownExpanded, fillsSpace: true) {
                List {
                    ForEach(shownRows) { row in barRow(row, shown: true) }
                        .onMove { source, destination in
                            var moved = shownRows
                            moved.move(fromOffsets: source, toOffset: destination)
                            rows = moved + hiddenRows
                            save()
                        }
                }
                .areaListStyle()
            }
            areaCard(header: areaHeader("숨김", symbol: "eye.slash.fill", count: hiddenRows.count, tint: .secondary, expanded: $hiddenExpanded), expanded: hiddenExpanded, fillsSpace: false) {
                if hiddenRows.isEmpty {
                    Text("숨긴 항목이 없어요")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .frame(maxWidth: .infinity, minHeight: 60)
                } else {
                    List {
                        ForEach(hiddenRows) { row in barRow(row, shown: false) }
                    }
                    .areaListStyle()
                    .frame(height: min(CGFloat(hiddenRows.count) * 38 + 8, 150))
                }
            }
            if !shownExpanded { Spacer(minLength: 0) }
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
        .padding(20)
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
        .background(RoundedRectangle(cornerRadius: 14).fill(Color.accentColor.opacity(0.1)))
        .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Color.accentColor.opacity(0.2)))
    }

    private func barRow(_ row: Row, shown: Bool) -> some View {
        BarRow(
            button: FormatBar.buttons.first { $0.icon == row.key },
            shown: shown,
            isLastShown: shownCount == 1,
            onToggle: { setShown(row.key, $0) },
            onInsertSeparator: {
                guard let index = rows.firstIndex(where: { $0.id == row.id }) else { return }
                withAnimation(.snappy) { rows.insert(Row(key: FormatBar.separatorKey), at: index + 1) }
                save()
            },
            onDelete: { withAnimation(.snappy) { rows.removeAll { $0.id == row.id } }; save() },
            onHover: { preview.highlighted = $0 ? row.key : nil }
        )
        .listRowSeparator(.hidden)
        .listRowBackground(Color.clear)
        .listRowInsets(EdgeInsets(top: 1, leading: 4, bottom: 1, trailing: 4))
    }

    private func areaCard<Content: View>(header: some View, expanded: Bool, fillsSpace: Bool, @ViewBuilder content: () -> Content) -> some View {
        VStack(spacing: 0) {
            header
            if expanded { content() }
        }
        .padding(.bottom, expanded ? 4 : 0)
        .frame(maxHeight: expanded && fillsSpace ? .infinity : nil)
        .background(RoundedRectangle(cornerRadius: 12).fill(.quaternary.opacity(0.35)))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func areaHeader(_ title: String, symbol: String, count: Int, tint: Color, expanded: Binding<Bool>) -> some View {
        Button { withAnimation(.snappy(duration: 0.25)) { expanded.wrappedValue.toggle() } } label: {
        HStack(spacing: 6) {
            Image(systemName: symbol).foregroundStyle(tint)
            Text(title).font(.subheadline.weight(.semibold))
            Text("\(count)")
                .font(.caption2.weight(.semibold))
                .padding(.horizontal, 7)
                .padding(.vertical, 2)
                .background(Capsule().fill(tint.opacity(0.18)))
                .contentTransition(.numericText())
            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .rotationEffect(.degrees(expanded.wrappedValue ? 90 : 0))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    /// Showing a button puts it at the end of the ON area; hiding sends it to the OFF area.
    private func setShown(_ key: String, _ show: Bool) {
        guard let row = rows.first(where: { $0.key == key }) else { return }
        withAnimation(.snappy(duration: 0.28)) {
            if show { hidden.remove(key) } else { hidden.insert(key) }
            let others = rows.filter { $0.id != row.id }
            let shown = others.filter { $0.isSeparator || !hidden.contains($0.key) }
            let hiddenOthers = others.filter { !$0.isSeparator && hidden.contains($0.key) }
            rows = show ? shown + [row] + hiddenOthers : shown + hiddenOthers + [row]
        }
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
            // Only the ON area can be reordered.
            Image(systemName: shown ? "line.3.horizontal" : "eye.slash")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .opacity(shown ? (hovering ? 1 : 0.35) : 0.5)
                .frame(width: 14)
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
            .opacity(shown && hovering ? 1 : 0)
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

private extension View {
    func areaListStyle() -> some View {
        listStyle(.plain).scrollContentBackground(.hidden)
    }
}
