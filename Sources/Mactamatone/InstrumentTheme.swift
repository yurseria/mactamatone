import SwiftUI

/// Stable identifiers are persisted, independently of the labels shown in settings.
enum InstrumentTheme: String, CaseIterable, Identifiable {
    case classic, pink, cat, chick, galaxy, shiba

    static let preferenceKey = "instrumentTheme"
    var id: Self { self }

    func title(in language: AppLanguage) -> String {
        let key: LocalizedText
        switch self {
        case .classic: key = .themeClassic
        case .pink: key = .themePink
        case .cat: key = .themeCat
        case .chick: key = .themeChick
        case .galaxy: key = .themeGalaxy
        case .shiba: key = .themeShiba
        }
        return language.text(key)
    }

    var accent: Color {
        switch self {
        case .classic: return Color(red: 0.32, green: 0.50, blue: 0.93)
        case .pink: return Color(red: 0.83, green: 0.32, blue: 0.49)
        case .cat: return Color(red: 0.37, green: 0.34, blue: 0.45)
        case .chick: return Color(red: 0.85, green: 0.48, blue: 0.05)
        case .galaxy: return Color(red: 0.46, green: 0.34, blue: 0.86)
        case .shiba: return Color(red: 0.69, green: 0.41, blue: 0.17)
        }
    }

    var backdrop: Color {
        switch self {
        case .classic: return Color(red: 0.80, green: 0.82, blue: 0.86)
        case .pink: return Color(red: 0.96, green: 0.85, blue: 0.88)
        case .cat: return Color(red: 0.78, green: 0.77, blue: 0.81)
        case .chick: return Color(red: 0.98, green: 0.92, blue: 0.76)
        case .galaxy: return Color(red: 0.84, green: 0.83, blue: 0.96)
        case .shiba: return Color(red: 0.94, green: 0.86, blue: 0.75)
        }
    }

    var backgroundOpacity: Double {
        switch self {
        case .classic: return 1
        case .pink: return 0.50
        case .cat: return 0.50
        case .chick: return 0.56
        case .galaxy: return 0.44
        case .shiba: return 0.50
        }
    }

    var backgroundResourceName: String? {
        self == .classic ? nil : "Otamatone\(rawValue.capitalized)Background"
    }

    func widgetResourceName(level: Int) -> String {
        let level = min(max(level, 0), 4)
        return self == .classic ? "OtamatoneWidgetLevel\(level)" : "Otamatone\(rawValue.capitalized)Level\(level)"
    }

    static func saved(in preferences: UserDefaults) -> Self {
        preferences.string(forKey: preferenceKey).flatMap(Self.init(rawValue:)) ?? .classic
    }
}
