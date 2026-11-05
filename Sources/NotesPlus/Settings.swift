import Foundation

/// Per-feature switches in the menu bar menu. All on by default.
enum Settings {
    enum Feature: String, CaseIterable {
        case slash, markdown, formatBar, backlinks

        var title: String {
            switch self {
            case .slash: "/ 명령"
            case .markdown: "마크다운 단축 입력"
            case .formatBar: "서식 바"
            case .backlinks: "백링크"
            }
        }
    }

    static func isOn(_ feature: Feature) -> Bool {
        UserDefaults.standard.object(forKey: feature.rawValue) as? Bool ?? true
    }

    /// Icons (the buttons' ids) of format bar buttons the user switched off.
    static var hiddenBarItems: Set<String> {
        get { Set(UserDefaults.standard.stringArray(forKey: "hiddenBarItems") ?? []) }
        set { UserDefaults.standard.set(Array(newValue), forKey: "hiddenBarItems") }
    }

    /// Menu bar panel rows in display order (`MenuEntry` raw values). Empty = default order.
    static var menuOrder: [String] {
        get { UserDefaults.standard.stringArray(forKey: "menuOrder") ?? [] }
        set { UserDefaults.standard.set(newValue, forKey: "menuOrder") }
    }

    /// `/` menu rows (by title) in display order, with `LayoutKeys.separator` entries. Empty = default order.
    static var slashLayout: [String] {
        get { UserDefaults.standard.stringArray(forKey: "slashLayout") ?? [] }
        set { UserDefaults.standard.set(newValue, forKey: "slashLayout") }
    }

    static var hiddenSlashItems: Set<String> {
        get { Set(UserDefaults.standard.stringArray(forKey: "hiddenSlashItems") ?? []) }
        set { UserDefaults.standard.set(Array(newValue), forKey: "hiddenSlashItems") }
    }

    /// Button icons in display order, with `FormatBar.separatorKey` entries for separator lines. Empty = default order.
    static var barLayout: [String] {
        get { UserDefaults.standard.stringArray(forKey: "barLayout") ?? [] }
        set { UserDefaults.standard.set(newValue, forKey: "barLayout") }
    }

    static func set(_ feature: Feature, _ on: Bool) {
        UserDefaults.standard.set(on, forKey: feature.rawValue)
    }
}
