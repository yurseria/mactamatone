import AppKit

/// Decode each theme once; pitch updates only change CALayer contents.
enum Art {
    private static let widgetImages: [InstrumentTheme: [NSImage]] = Dictionary(
        uniqueKeysWithValues: InstrumentTheme.allCases.map { theme in
            (theme, (0..<5).map { load(theme.widgetResourceName(level: $0)) })
        }
    )
    private static let widgetCGImages: [InstrumentTheme: [CGImage]] = widgetImages.mapValues { images in
        images.map { image in
            guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
                preconditionFailure("Cannot decode widget image")
            }
            return cgImage
        }
    }
    private static let previews: [InstrumentTheme: NSImage] = Dictionary(
        uniqueKeysWithValues: InstrumentTheme.allCases.map { theme in
            let image = widgetCGImage(theme: theme, level: 0)
            let width = Double(image.width), height = Double(image.height)
            let face = image.cropping(to: CGRect(x: width * 0.24, y: height * 0.58,
                                                width: width * 0.52, height: height * 0.40))!
            return (theme, NSImage(cgImage: face, size: .zero))
        }
    )
    private static let backgrounds: [InstrumentTheme: NSImage] = Dictionary(
        uniqueKeysWithValues: InstrumentTheme.allCases.compactMap { theme in
            theme.backgroundResourceName.map { (theme, load($0)) }
        }
    )
    private static let classicStageImages = (0..<5).map { load("OtamatoneLevel\($0)") }

    static func previewImage(theme: InstrumentTheme) -> NSImage {
        previews[theme]!
    }

    static func widgetImage(theme: InstrumentTheme, level: Int) -> NSImage {
        widgetImages[theme]![min(max(level, 0), 4)]
    }

    static func widgetCGImage(theme: InstrumentTheme, level: Int) -> CGImage {
        widgetCGImages[theme]![min(max(level, 0), 4)]
    }

    static func backgroundImage(theme: InstrumentTheme) -> NSImage? {
        backgrounds[theme]
    }

    static func stageImage(theme: InstrumentTheme, level: Int) -> NSImage {
        theme == .classic ? classicStageImages[min(max(level, 0), 4)] : widgetImage(theme: theme, level: level)
    }

    private static func load(_ name: String) -> NSImage {
        guard let url = Bundle.module.url(forResource: name, withExtension: "png"),
              let image = NSImage(contentsOf: url) else {
            preconditionFailure("Missing bundled image: \(name)")
        }
        return image
    }
}
