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
        app.appearance = NSAppearance(named: .aqua)
        try checkAudioMeter()
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
        checkPitchMapping(preferences: preferences)
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
                model.manualAngle = 25 + 105 * (Double(level) + 0.5) / 5
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
            model.isPlaying = true
            // A play-button state alone cannot produce a glow.
            precondition(model.audioActivity.level == 0)
            for step in 0..<20 {
                model.audioActivity.accept(AudioOutputSample(rms: 0.14, sequence: UInt64(step + 1)),
                                           at: Double(step) / 30)
            }
            try snapshotSettings(model: model, size: NSSize(width: 962, height: 700),
                                 to: previews.appendingPathComponent("\(theme.rawValue)-settings-glow.png"))
            try snapshot(FloatingWidgetView(model: model, openSettings: {}, quit: {}),
                         size: NSSize(width: 320, height: 476),
                         to: previews.appendingPathComponent("\(theme.rawValue)-widget-glow.png"))
            for (appearance, surface) in [("light", Color(red: 0.93, green: 0.94, blue: 0.96)),
                                          ("dark", Color(red: 0.10, green: 0.12, blue: 0.15))] {
                try snapshot(FloatingWidgetView(model: model, openSettings: {}, quit: {}).background(surface),
                             size: NSSize(width: 320, height: 476),
                             to: previews.appendingPathComponent("\(theme.rawValue)-widget-glow-\(appearance).png"))
            }
            if theme == .galaxy {
                for (name, phase) in [("contracted", 1.5 * Double.pi), ("expanded", 0.5 * Double.pi)] {
                    try snapshot(AudioGlowFrame(theme: theme, level: 1, breath: sin(phase))
                        .frame(width: 320, height: 360)
                        .background(Color(red: 0.10, green: 0.12, blue: 0.15)),
                        size: NSSize(width: 320, height: 360),
                        to: previews.appendingPathComponent("glow-motion-\(name).png"))
                }
            }
            model.audioActivity.stop()
            model.isPlaying = false
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
        app.appearance = NSAppearance(named: .darkAqua)
        precondition(app.effectiveAppearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua)
        for language in AppLanguage.allCases {
            model.language = language
            for theme in [InstrumentTheme.classic, .shiba] {
                model.theme = theme
                try snapshotSettings(model: model, size: NSSize(width: 962, height: 700),
                             colorScheme: .dark,
                             to: previews.appendingPathComponent("\(theme.rawValue)-settings-dark-\(language.rawValue).png"))
            }
        }
        print("All six themes, automatic mouth animation, both languages, and dark-mode settings rendered.")
    }

    static func checkPitchMapping(preferences: UserDefaults) {
        let model = InstrumentModel(preferences: preferences)
        model.sensorConnected = true
        for (angle, midi) in [(25.0, 48.0), (77.5, 66.0), (130.0, 84.0)] {
            model.lidAngle = angle
            precondition(model.safeToPlay)
            precondition(abs(model.midiPitch - midi) < 0.000001)
        }
        model.lidAngle = 24.99
        precondition(!model.safeToPlay && model.midiPitch == 48)
        model.lidAngle = 25
        precondition(model.safeToPlay && model.noteName == "C3" && model.pitchLevel == 0)
        model.lidAngle = 26
        precondition(model.midiPitch > 48, "Pitch must rise immediately above 25 degrees")
        model.lidAngle = 129
        precondition(model.normalizedPitch > 0.99 && model.noteName == "C6" && model.pitchLevel == 4)
        model.lidAngle = 180
        precondition(model.midiPitch == 84)
        model.sensorConnected = false
        precondition(!model.safeToPlay)
        model.inputMode = .manual
        precondition(model.safeToPlay)
        model.manualAngle = 25
        precondition(model.midiPitch == 48)
        model.manualAngle = 130
        precondition(model.midiPitch == 84)
        precondition(InstrumentModel.pitchAngleRange == 25...130)
        print("25–130 degree pitch mapping, mute boundary, 129 degree maximum, and manual input verified.")
    }

    static func checkAudioMeter() throws {
        let synth = OtamatoneSynth()
        precondition(synth.outputSample.rms == 0)
        try synth.startOfflineForChecks()
        _ = try synth.renderOfflineForChecks()
        precondition(synth.outputSample.rms == 0, "Silent audio must not light the widget")
        synth.set(frequency: 440, mouth: 0.5, playing: true)
        var rendered = [Float]()
        for _ in 0..<12 { rendered = try synth.renderOfflineForChecks() }
        let measured = sqrt(rendered.reduce(0) { $0 + Double($1) * Double($1) } / Double(rendered.count))
        let sample = synth.outputSample
        precondition(sample.sequence > 0 && sample.rms > 0.03 && sample.rms < 0.22)
        precondition(abs(sample.rms - measured) < 0.02, "Meter must match rendered PCM")
        synth.set(frequency: 440, mouth: 0.5, playing: false)
        for _ in 0..<30 { _ = try synth.renderOfflineForChecks() }
        precondition(synth.outputSample.rms < 0.00001, "Meter must decay with the actual release tail")
        synth.stop()
        precondition(synth.outputSample.rms == 0)

        var quietEnvelope = AudioLevelEnvelope()
        var loudEnvelope = AudioLevelEnvelope()
        for step in 1...30 {
            let time = Double(step) / 30
            let quiet = quietEnvelope.update(AudioOutputSample(rms: 0.001, sequence: UInt64(step)), at: time)
            let loud = loudEnvelope.update(AudioOutputSample(rms: 0.2, sequence: UInt64(step)), at: time)
            precondition(quiet == loud, "Glow strength must be independent of audio volume")
        }
        precondition(quietEnvelope.level > 0.99)

        var envelope = AudioLevelEnvelope()
        precondition(envelope.update(.silent, at: 0) == 0)
        for step in 1...20 {
            let level = envelope.update(AudioOutputSample(rms: 0.14, sequence: UInt64(step)), at: Double(step) / 30)
            precondition(level > 0 && level <= 1)
        }
        precondition(envelope.level > 0.8)
        let lit = envelope.level
        for step in 21...90 {
            _ = envelope.update(AudioOutputSample(rms: 0.14, sequence: 20), at: Double(step) / 30)
        }
        precondition(envelope.level == 0, "A stalled callback must fade a previously positive meter")
        _ = envelope.update(AudioOutputSample(rms: 0.14, sequence: 21), at: 3.1)
        precondition(envelope.level > 0 && envelope.level < lit)
        for step in 22...90 {
            _ = envelope.update(AudioOutputSample(rms: 0, sequence: UInt64(step)), at: 3.1 + Double(step - 21) / 30)
        }
        precondition(envelope.level == 0)
        _ = envelope.update(AudioOutputSample(rms: .nan, sequence: 91), at: 6)
        precondition(envelope.level == 0 && envelope.level.isFinite)
        print("Rendered PCM metering, silent output, audio release, stalled callbacks, fixed glow strength, and smooth fades verified.")
    }

    static func snapshotSettings(model: InstrumentModel, size: NSSize,
                                 colorScheme: ColorScheme? = nil, to url: URL) throws {
        let window = SettingsWindow(model: model)
        if let colorScheme {
            // Simulate the inherited SwiftUI scheme as well as AppKit's dark appearance.
            window.contentView = NSHostingView(rootView: SettingsView(model: model)
                .environment(\.colorScheme, colorScheme)
                .frame(minWidth: 840, minHeight: 620))
        }
        precondition(window.effectiveAppearance.bestMatch(from: [.aqua, .darkAqua]) == .aqua,
                     "Native settings controls must match the light theme palette")
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
