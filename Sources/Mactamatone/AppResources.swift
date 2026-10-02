import AppKit

/// Packaged apps use their own resources, independent of SwiftPM's build paths.
enum AppResources {
    static let bundle: Bundle = {
        if Bundle.main.bundleURL.pathExtension == "app" {
            let url = Bundle.main.resourceURL?.appendingPathComponent("Mactamatone_Mactamatone.bundle")
            guard let bundle = url.flatMap(Bundle.init(url:)) else {
                preconditionFailure("Missing resources inside the installed Mactamatone app")
            }
            return bundle
        }
        // SwiftPM executables and the standalone capture/check tools.
        return Bundle.module
    }()

    /// Exercise the installed production binary without starting audio or windows.
    static func verifyPackagedResources() {
        precondition(Bundle.main.bundleURL.pathExtension == "app")
        precondition(bundle.bundleURL.deletingLastPathComponent().standardizedFileURL.path ==
                     Bundle.main.resourceURL?.standardizedFileURL.path)
        guard let icon = bundle.url(forResource: "AppIcon", withExtension: "icns"),
              NSImage(contentsOf: icon)?.isValid == true else {
            preconditionFailure("Missing or invalid packaged app icon")
        }
        for language in AppLanguage.allCases {
            precondition(bundle.url(forResource: language.rawValue, withExtension: "lproj") != nil)
            for key in LocalizedText.allCases {
                let text = language.text(key)
                precondition(!text.isEmpty && text != key.rawValue, "Missing packaged translation: \(key.rawValue)")
            }
        }
        for theme in InstrumentTheme.allCases {
            for level in 0..<5 {
                precondition(Art.widgetImage(theme: theme, level: level).isValid)
                precondition(Art.stageImage(theme: theme, level: level).isValid)
            }
            precondition(Art.previewImage(theme: theme).isValid)
            if theme.backgroundResourceName != nil {
                precondition(Art.backgroundImage(theme: theme)?.isValid == true)
            }
        }
        print("Packaged resources verified: icon, both languages, and all six themes.")
    }
}
