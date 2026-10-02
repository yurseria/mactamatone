// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Mactamatone",
    defaultLocalization: "en",
    platforms: [.macOS(.v14)],
    products: [.executable(name: "Mactamatone", targets: ["Mactamatone"])],
    dependencies: [
        .package(url: "https://github.com/sparkle-project/Sparkle", exact: "2.10.0")
    ],
    targets: [
        .target(name: "AudioControls", publicHeadersPath: "include"),
        .executableTarget(
            name: "Mactamatone",
            dependencies: ["AudioControls", .product(name: "Sparkle", package: "Sparkle")],
            resources: [.process("Resources")],
            linkerSettings: [.linkedFramework("AVFoundation"), .linkedFramework("IOKit"), .unsafeFlags(["-Xlinker", "-rpath", "-Xlinker", "@executable_path/../Frameworks"])]
        )
    ],
    swiftLanguageVersions: [.v5]
)
