import AppKit
import SwiftUI

extension Bundle {
    static let module = Bundle(path: CommandLine.arguments[1])!
}

/// Capture the app's own views with isolated preferences and silent offline audio.
@main
struct ReadmeScreenshots {
    static func main() throws {
        let app = NSApplication.shared
        app.setActivationPolicy(.regular)
        app.appearance = NSAppearance(named: .aqua)
        let suite = "app.mactamatone.readme-capture.\(UUID().uuidString)"
        let preferences = UserDefaults(suiteName: suite)!
        defer { preferences.removePersistentDomain(forName: suite) }
        let model = InstrumentModel(preferences: preferences)
        model.theme = .galaxy
        model.inputMode = .manual
        model.manualAngle = 100
        model.sensorStatus = .unavailable
        model.isPlaying = true
        let synth = OtamatoneSynth()
        try synth.startOfflineForChecks()
        defer { synth.stop() }
        synth.set(frequency: model.frequency, mouth: model.mouth, playing: true)
        for step in 0..<30 {
            _ = try synth.renderOfflineForChecks()
            model.audioActivity.accept(synth.outputSample, at: Double(step) / 30)
        }
        let output = URL(fileURLWithPath: CommandLine.arguments[2])
        try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
        for language in AppLanguage.allCases {
            model.language = language
            let suffix = language == .english ? "" : "-ko"
            let size = NSSize(width: 320, height: 476)
            let widget = NSPanel(contentRect: NSRect(origin: .zero, size: size),
                                 styleMask: [.borderless, .nonactivatingPanel],
                                 backing: .buffered, defer: false)
            widget.isReleasedWhenClosed = false
            widget.isOpaque = false
            widget.backgroundColor = .clear
            widget.hasShadow = false
            widget.contentView = NSHostingView(rootView: FloatingWidgetView(
                model: model, openSettings: {}, quit: {}
            ).frame(width: size.width, height: size.height)
                .background(Color(red: 0.10, green: 0.12, blue: 0.15)))
            try capture(widget, to: output.appendingPathComponent("widget\(suffix).png"))
            let settings = SettingsWindow(model: model)
            settings.setContentSize(NSSize(width: 962, height: 700))
            try capture(settings, to: output.appendingPathComponent("settings\(suffix).png"))
        }
    }

    static func capture(_ window: NSWindow, to output: URL) throws {
        window.center()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        RunLoop.current.run(until: Date().addingTimeInterval(0.20))
        let frame = window.contentView!.superview ?? window.contentView!
        frame.layoutSubtreeIfNeeded()
        frame.displayIfNeeded()
        // Prefer a WindowServer screenshot, retaining native glass and controls.
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
        process.arguments = ["-x", "-o", "-l", String(window.windowNumber), output.path]
        try process.run()
        process.waitUntilExit()
        if process.terminationStatus == 0 && FileManager.default.fileExists(atPath: output.path) {
            print("Window screenshot: \(output.lastPathComponent)")
        } else {
            // Headless environments can still export the actual native view tree.
            guard let bitmap = frame.bitmapImageRepForCachingDisplay(in: frame.bounds) else {
                fatalError("Cannot render \(output.lastPathComponent)")
            }
            frame.cacheDisplay(in: frame.bounds, to: bitmap)
            try bitmap.representation(using: .png, properties: [:])!.write(to: output)
            print("Native view snapshot: \(output.lastPathComponent)")
        }
        window.close()
    }
}
