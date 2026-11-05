import SwiftUI

/// Shared helpers for ordered lists that mix item keys with separator lines (`|`).
enum LayoutKeys {
    static let separator = "|"

    /// Saved order made complete: unknown or repeated keys dropped, keys added since it was saved appended.
    /// An empty save means "never customized" and yields `fallback`.
    static func order(_ saved: [String], known: [String], fallback: [String]) -> [String] {
        if saved.isEmpty { return fallback }
        let knownSet = Set(known)
        var seen = Set<String>()
        var result = saved.filter { $0 == separator || (knownSet.contains($0) && seen.insert($0).inserted) }
        result += known.filter { !seen.contains($0) }
        return result
    }
}

struct LayoutItem {
    let key: String
    let title: String
    let symbol: String
}

/// Editor for a customizable list (format bar buttons, `/` menu rows): what shows, in which order, and where separators go.
struct LayoutEditor<Preview: View>: View {
    typealias Item = LayoutItem

    enum PreviewPlacement { case top, side }

    private struct Row: Identifiable {
        let id = UUID()
        let key: String
        var isSeparator: Bool { key == LayoutKeys.separator }
    }

    let title: String
    let subtitle: String
    let items: [Item]
    let defaultLayout: [String]
    let keepOneShown: Bool
    let placement: PreviewPlacement
    let onSave: ([String], Set<String>) -> Void
    let preview: (_ layout: [String], _ hidden: Set<String>, _ highlighted: String?) -> Preview

    @State private var rows: [Row]
    @State private var hidden: Set<String>
    @State private var highlighted: String?
    @State private var shownExpanded = true
    /// Collapsed by default: hidden items are rarely touched.
    @State private var hiddenExpanded = false

    init(title: String, subtitle: String, items: [Item], layout: [String], hidden: Set<String>, defaultLayout: [String],
         keepOneShown: Bool, placement: PreviewPlacement = .top, onSave: @escaping ([String], Set<String>) -> Void,
         @ViewBuilder preview: @escaping (_ layout: [String], _ hidden: Set<String>, _ highlighted: String?) -> Preview) {
        self.title = title
        self.subtitle = subtitle
        self.items = items
        self.defaultLayout = defaultLayout
        self.keepOneShown = keepOneShown
        self.placement = placement
        self.onSave = onSave
        self.preview = preview
        _rows = State(initialValue: layout.map { Row(key: $0) })
        _hidden = State(initialValue: hidden)
    }

    private var itemKeys: [String] { items.map(\.key) }
    private var shownCount: Int { items.filter { !hidden.contains($0.key) }.count }
    /// The ON area: shown items and separators, in order. Hidden items trail in the saved layout.
    private var shownRows: [Row] { rows.filter { $0.isSeparator || !hidden.contains($0.key) } }
    private var hiddenRows: [Row] { rows.filter { !$0.isSeparator && hidden.contains($0.key) } }
    private var layoutKeys: [String] { rows.map(\.key) }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            PaneHeader(title: title, subtitle: subtitle)
            switch placement {
            case .top:
                previewCard
                editor
            case .side:
                HStack(alignment: .top, spacing: 14) {
                    editor
                    previewCard.frame(width: 270)
                }
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var editor: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Two separate cards so the ON and OFF areas stay visible together without scrolling.
            areaCard(header: areaHeader("표시 중", symbol: "eye.fill", count: shownCount, tint: .accentColor, expanded: $shownExpanded), expanded: shownExpanded, fillsSpace: true) {
                List {
                    ForEach(shownRows) { row in itemRow(row, shown: true) }
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
                        ForEach(hiddenRows) { row in itemRow(row, shown: false) }
                    }
                    .areaListStyle()
                    .frame(height: min(CGFloat(hiddenRows.count) * 38 + 8, 150))
                }
            }
            if !shownExpanded { Spacer(minLength: 0) }
            HStack {
                Button { rows.append(Row(key: LayoutKeys.separator)); save() } label: {
                    Label("구분선 추가", systemImage: "plus")
                }
                Spacer()
                Text("행을 끌어서 순서를 바꿔요").font(.caption).foregroundStyle(.tertiary)
                Spacer()
                Button("기본값으로") {
                    withAnimation(.snappy) {
                        rows = defaultLayout.map { Row(key: $0) }
                        hidden = []
                    }
                    save()
                }
            }
        }
    }

    private var previewCard: some View {
        VStack(spacing: 8) {
            Text("미리보기").font(.caption).foregroundStyle(.secondary).frame(maxWidth: .infinity, alignment: .leading)
            preview(layoutKeys, hidden, highlighted)
                .animation(.snappy(duration: 0.25), value: layoutKeys)
                .animation(.snappy(duration: 0.25), value: hidden)
                .frame(maxWidth: .infinity, maxHeight: placement == .side ? .infinity : nil, alignment: .top)
        }
        .padding(12)
        .frame(maxHeight: placement == .side ? .infinity : nil, alignment: .top)
        .background(RoundedRectangle(cornerRadius: 14).fill(Color.accentColor.opacity(0.1)))
        .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Color.accentColor.opacity(0.2)))
    }

    private func itemRow(_ row: Row, shown: Bool) -> some View {
        EditorRow(
            item: items.first { $0.key == row.key },
            shown: shown,
            isLastShown: keepOneShown && shownCount == 1,
            onToggle: { setShown(row.key, $0) },
            onInsertSeparator: {
                guard let index = rows.firstIndex(where: { $0.id == row.id }) else { return }
                withAnimation(.snappy) { rows.insert(Row(key: LayoutKeys.separator), at: index + 1) }
                save()
            },
            onDelete: { withAnimation(.snappy) { rows.removeAll { $0.id == row.id } }; save() },
            onHover: { highlighted = $0 ? row.key : nil }
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

    /// Showing an item puts it at the end of the ON area; hiding sends it to the OFF area.
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

    private func save() { onSave(layoutKeys, hidden) }
}

private struct EditorRow: View {
    /// nil for a separator row.
    let item: LayoutItem?
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
            if let item {
                itemContent(item)
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

    private func itemContent(_ item: LayoutItem) -> some View {
        HStack(spacing: 10) {
            Image(systemName: item.symbol)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(shown ? .white : .secondary)
                .frame(width: 28, height: 28)
                .background(
                    RoundedRectangle(cornerRadius: 7)
                        .fill(shown ? AnyShapeStyle(Color.accentColor.gradient) : AnyShapeStyle(.quaternary))
                )
            Text(item.title)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(shown ? .primary : .secondary)
                .strikethrough(!shown, color: .secondary)
                .lineLimit(1)
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
                // The last visible bar button stays on; an empty bar would be a blank pill.
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

// MARK: - Format bar

struct BarSettingsView: View {
    let onChange: () -> Void

    var body: some View {
        LayoutEditor(
            title: "서식 바",
            subtitle: "표시할 버튼과 순서, 구분선을 정합니다.",
            items: FormatBar.buttons.map { .init(key: $0.icon, title: $0.help, symbol: $0.icon) },
            layout: FormatBar.order(Settings.barLayout),
            hidden: Settings.hiddenBarItems,
            defaultLayout: FormatBar.order([]),
            keepOneShown: true,
            onSave: { layout, hidden in
                Settings.barLayout = layout
                Settings.hiddenBarItems = hidden
                onChange()
            },
            preview: { layout, hidden, highlighted in
                // The bar can be wider than the window, so it scrolls instead of clipping.
                ScrollView(.horizontal, showsIndicators: false) {
                    FormatBarView(model: FormatBarModel(layout: layout, hidden: hidden, highlighted: highlighted)) { _ in }
                        .fixedSize()
                        .padding(.vertical, 6)
                        .padding(.horizontal, 2)
                }
            }
        )
    }
}

// MARK: - Slash menu

struct SlashSettingsView: View {
    var body: some View {
        let roots = SlashCommand.rootItems()
        LayoutEditor(
            title: "/ 명령",
            subtitle: "/ 를 눌렀을 때 나오는 메뉴의 항목과 순서, 구분선을 정합니다.",
            items: roots.map { .init(key: $0.title, title: $0.title, symbol: $0.icon) },
            layout: SlashCommand.order(Settings.slashLayout, roots),
            hidden: Settings.hiddenSlashItems,
            defaultLayout: SlashCommand.order([], roots),
            keepOneShown: false,
            placement: .side,
            onSave: { layout, hidden in
                Settings.slashLayout = layout
                Settings.hiddenSlashItems = hidden
            },
            preview: { layout, hidden, highlighted in
                SlashPreview(items: SlashCommand.arrange(roots, layout: layout, hidden: hidden), highlighted: highlighted)
            }
        )
    }
}

/// The real menu view, frozen: no selection, only the row under the pointer in the editor is marked.
private struct SlashPreview: View {
    let items: [SlashCommand]
    let highlighted: String?

    var body: some View {
        let model = SlashMenuModel()
        let _ = (model.items = items, model.selected = items.firstIndex { $0.title == highlighted } ?? -1)
        SlashMenuView(model: model) { _ in }
            .allowsHitTesting(false)
            .frame(maxWidth: .infinity)
    }
}
