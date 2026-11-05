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

    static func set(_ feature: Feature, _ on: Bool) {
        UserDefaults.standard.set(on, forKey: feature.rawValue)
    }
}
