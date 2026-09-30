import Foundation

/// The app language is chosen explicitly, independently of the system language.
enum AppLanguage: String, CaseIterable, Identifiable {
    case english = "en"
    case korean = "ko"

    static let preferenceKey = "appLanguage"
    var id: Self { self }
    var title: String { self == .english ? "English" : "한국어" }
    var locale: Locale { Locale(identifier: rawValue) }

    static func saved(in preferences: UserDefaults) -> Self {
        preferences.string(forKey: preferenceKey).flatMap(Self.init(rawValue:)) ?? .english
    }

    private static let bundles: [Self: Bundle] = Dictionary(uniqueKeysWithValues: allCases.map {
        ($0, Bundle.module.url(forResource: $0.rawValue, withExtension: "lproj")
            .flatMap { Bundle(url: $0) } ?? Bundle.module)
    })

    func text(_ key: LocalizedText) -> String {
        Self.bundles[self]!.localizedString(forKey: key.rawValue, value: nil, table: nil)
    }

    func format(_ key: LocalizedText, _ arguments: CVarArg...) -> String {
        String(format: text(key), locale: locale, arguments: arguments)
    }
}

enum LocalizedText: String, CaseIterable {
    case appTitle
    case settingsTitle
    case language
    case theme
    case themeClassic
    case themePink
    case themeCat
    case themeChick
    case themeGalaxy
    case themeShiba
    case instrumentSubtitle
    case playInstruction
    case quit
    case startPlaying
    case stopPlaying
    case currentNote
    case openSettings
    case artDescription
    case moveLidSlowly
    case adjustPitch
    case openLid
    case playHint
    case inputMode
    case lidInput
    case manualInput
    case pitch
    case openLidMore
    case mouthTimbre
    case sensorConnected
    case manualAvailable
    case liveBadge
    case lidAngleValue
    case singing
    case ready
    case sensorChecking
    case sensorAccessFailed
    case sensorReady
    case sensorUnavailable
    case sensorDisconnected
    case sensorReconnected
    case audioStartFailed
}

/// Store the sensor state, so existing messages update when the language changes.
enum SensorStatus {
    case checking, connected, unavailable, disconnected, reconnected
    case accessFailed(String)

    func text(in language: AppLanguage) -> String {
        switch self {
        case .checking: return language.text(.sensorChecking)
        case .connected: return language.text(.sensorReady)
        case .unavailable: return language.text(.sensorUnavailable)
        case .disconnected: return language.text(.sensorDisconnected)
        case .reconnected: return language.text(.sensorReconnected)
        case .accessFailed(let code): return language.format(.sensorAccessFailed, code)
        }
    }
}
