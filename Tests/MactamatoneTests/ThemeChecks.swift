import AppKit
import SwiftUI

extension Bundle {
    static let module = Bundle(path: CommandLine.arguments[1])!
}

@main
struct ThemeChecks {
    static func main() throws {
        let app = NSApplication.shared
        app.setActivationPolicy(.prohibited)
        let suite = "app.mactamatone.theme-checks.\(UUID().uuidString)"
        let preferences = UserDefaults(suiteName: suite)!
        defer { preferences.removePersistentDomain(forName: suite) }
        precondition(InstrumentTheme.saved(in: preferences) == .classic)
        preferences.set("unknown", forKey: InstrumentTheme.preferenceKey)
        precondition(InstrumentTheme.saved(in: preferences) == .classic)
        preferences.removeObject(forKey: InstrumentTheme.preferenceKey)
        precondition(AppLanguage.saved(in: preferences) == .english)
        preferences.set("unknown", forKey: AppLanguage.preferenceKey)
        precondition(AppLanguage.saved(in: preferences) == .english)
        preferences.removeObject(forKey: AppLanguage.preferenceKey)
        for language in AppLanguage.allCases {
            for key in LocalizedText.allCases {
                let text = language.text(key)
                precondition(!text.isEmpty && text != key.rawValue, "Missing \(language.rawValue) translation for \(key.rawValue)")
                let pattern = "%[@df]"
                let englishFormats = AppLanguage.english.text(key).matches(pattern)
                precondition(text.matches(pattern) == englishFormats, "Format placeholders differ for \(key.rawValue)")
            }
        }
        precondition(AppLanguage.english.text(.startPlaying) == "Start playing")
        precondition(AppLanguage.korean.text(.startPlaying) == "연주 시작")
        let model = InstrumentModel(preferences: preferences)
        precondition(model.language == .english)
        model.inputMode = .manual
        let frequency = model.frequency
        let pitchLevel = model.pitchLevel
        model.sensorStatus = .accessFailed("0x12345678")
        model.audioErrorDetail = "test device"
        let liveWindow = SettingsWindow(model: model)
        for language in AppLanguage.allCases.reversed() {
            model.language = language
            precondition(InstrumentModel(preferences: preferences).language == language)
            precondition(model.frequency == frequency && model.pitchLevel == pitchLevel && !model.isPlaying)
            precondition(liveWindow.title == language.text(.settingsTitle))
            precondition(model.statusMessage.contains("0x12345678"))
            precondition(model.audioError!.contains("test device"))
            precondition(model.statusMessage == language.format(.sensorAccessFailed, "0x12345678"))
            precondition(model.audioError == language.format(.audioStartFailed, "test device"))
        }
        liveWindow.close()
        model.sensorStatus = .unavailable
        model.audioErrorDetail = nil
        print("English default, language persistence, translation coverage, live status/error/title switching verified.")
        precondition(InstrumentTheme.allCases.count == 6)
        let previews = URL(fileURLWithPath: CommandLine.arguments[2])
        try FileManager.default.createDirectory(at: previews, withIntermediateDirectories: true)
        for theme in InstrumentTheme.allCases {
            model.theme = theme
            precondition(InstrumentModel(preferences: preferences).theme == theme)
            precondition(model.frequency == frequency && model.pitchLevel == pitchLevel && !model.isPlaying)
            var frames = Set<Data>()
            for level in 0..<5 {
                let image = Art.widgetCGImage(theme: theme, level: level)
                precondition(image.width > 500 && image.width == image.height)
                let bitmap = NSBitmapImageRep(cgImage: image)
                precondition(bitmap.hasAlpha && bitmap.colorAt(x: 0, y: 0)?.alphaComponent == 0)
                frames.insert(bitmap.representation(using: .png, properties: [:])!)
                precondition(Art.stageImage(theme: theme, level: level).tiffRepresentation != nil)
            }
            for level in 0..<5 {
                model.manualAngle = 55 + 90 * (Double(level) + 0.5) / 5
                precondition(model.visualMouthLevel == level && model.pitchLevel == level)
            }
            model.manualAngle = 100
            precondition(model.visualMouthLevel == pitchLevel)
            precondition(Art.previewImage(theme: theme).tiffRepresentation != nil)
            precondition(frames.count == 5, "Mouth positions must be distinct")
            precondition(Art.widgetImage(theme: theme, level: -1) === Art.widgetImage(theme: theme, level: 0))
            precondition(Art.widgetImage(theme: theme, level: 9) === Art.widgetImage(theme: theme, level: 4))
            try snapshotSettings(model: model, size: NSSize(width: 962, height: 700),
                         to: previews.appendingPathComponent("\(theme.rawValue)-settings.png"))
            try snapshot(FloatingWidgetView(model: model, openSettings: {}, quit: {}).frame(width: 320, height: 476),
                         size: NSSize(width: 320, height: 476), to: previews.appendingPathComponent("\(theme.rawValue)-widget.png"))
            if theme == .shiba {
                try snapshotSettings(model: model, size: NSSize(width: 840, height: 620),
                             to: previews.appendingPathComponent("shiba-compact-settings.png"))
                model.isPlaying = true
                try snapshot(FloatingWidgetView(model: model, openSettings: {}, quit: {}),
                             size: NSSize(width: 320, height: 476), to: previews.appendingPathComponent("shiba-widget-sound-on.png"))
                model.isPlaying = false
                model.language = .korean
                try snapshotSettings(model: model, size: NSSize(width: 840, height: 620),
                             to: previews.appendingPathComponent("shiba-compact-settings-ko.png"))
                try snapshot(FloatingWidgetView(model: model, openSettings: {}, quit: {}),
                             size: NSSize(width: 320, height: 476), to: previews.appendingPathComponent("shiba-widget-ko.png"))
                model.language = .english
            }
            print("\(theme.rawValue): saved selection, five transparent frames, pitch unchanged, UI rendered")
        }
        print("All six themes, automatic mouth animation, and both languages verified.")
    }

    static func snapshotSettings(model: InstrumentModel, size: NSSize, to url: URL) throws {
        let window = SettingsWindow(model: model)
        window.setContentSize(size)
        let host = window.contentView!
        host.layoutSubtreeIfNeeded()
        host.displayIfNeeded()
        // Include the native frame so previews show the retained traffic lights.
        let frame = host.superview ?? host
        frame.layoutSubtreeIfNeeded()
        guard let bitmap = frame.bitmapImageRepForCachingDisplay(in: frame.bounds) else {
            fatalError("Cannot render settings window")
        }
        frame.cacheDisplay(in: frame.bounds, to: bitmap)
        try bitmap.representation(using: .png, properties: [:])!.write(to: url)
        window.close()
    }

    static func snapshot<Content: View>(_ content: Content, size: NSSize, to url: URL) throws {
        let window = NSWindow(contentRect: NSRect(origin: .zero, size: size), styleMask: [.borderless],
                              backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.backgroundColor = .clear
        window.isOpaque = false
        let host = NSHostingView(rootView: content)
        window.contentView = host
        host.frame = NSRect(origin: .zero, size: size)
        host.layoutSubtreeIfNeeded()
        host.displayIfNeeded()
        guard let bitmap = host.bitmapImageRepForCachingDisplay(in: host.bounds) else {
            fatalError("Cannot render theme preview")
        }
        host.cacheDisplay(in: host.bounds, to: bitmap)
        try bitmap.representation(using: .png, properties: [:])!.write(to: url)
        window.close()
    }
}

private extension String {
    func matches(_ pattern: String) -> [String] {
        let regex = try! NSRegularExpression(pattern: pattern)
        return regex.matches(in: self, range: NSRange(startIndex..., in: self))
            .map { String(self[Range($0.range, in: self)!]) }
    }
}
