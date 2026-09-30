// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Mactamatone",
    platforms: [.macOS(.v14)],
    products: [.executable(name: "Mactamatone", targets: ["Mactamatone"])],
    targets: [
        .target(name: "AudioControls", publicHeadersPath: "include"),
        .executableTarget(
            name: "Mactamatone",
            dependencies: ["AudioControls"],
            resources: [.process("Resources")],
            linkerSettings: [.linkedFramework("AVFoundation"), .linkedFramework("IOKit")]
        )
    ],
    swiftLanguageVersions: [.v5]
)
