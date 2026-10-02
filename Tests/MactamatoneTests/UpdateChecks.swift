import AppKit
import Foundation

extension Bundle {
    static let module = Bundle(path: CommandLine.arguments[1])!
}

@main
struct UpdateChecks {
    @MainActor static func main() async throws {
        NSApplication.shared.setActivationPolicy(.prohibited)
        precondition(ReleaseVersion("0.10.0")! > ReleaseVersion("0.9.9")!)
        precondition(ReleaseVersion("v0.4.0") == ReleaseVersion("0.4.0"))
        for value in ["0.4", "0.4.0-beta", "-1.0.0", "0..4", "latest", "0.4.0.1"] {
            precondition(ReleaseVersion(value) == nil)
        }
        let fixture = try payload(version: "0.5.0")
        let latest = try LatestRelease.decode(fixture)
        precondition(latest.version == "0.5.0")
        for data in [try payload(version: "0.5.0", draft: true),
                     try payload(version: "0.5.0", prerelease: true),
                     try payload(version: "0.5.0", asset: false),
                     try payload(version: "0.5.0", domain: "https://example.com/"),
                     Data("{}".utf8)] {
            do { _ = try LatestRelease.decode(data); preconditionFailure("Unsafe or incomplete release accepted") }
            catch {}
        }
        let appURL = URL(fileURLWithPath: "/private/tmp/Mactamatone.app")
        let updater = AppUpdater(current: AppVersion(version: "0.4.0", build: "6"), appURL: appURL,
                                 fetchRelease: { latest })
        await updater.checkForUpdates()
        precondition(updater.status == .available && updater.release == latest && updater.canInstall)
        let equal = AppUpdater(current: AppVersion(version: "0.5.0", build: "7"), fetchRelease: { latest })
        await equal.checkForUpdates()
        precondition(equal.status == .current && equal.release == nil && !equal.canInstall)
        let newer = AppUpdater(current: AppVersion(version: "0.6.0", build: "8"), fetchRelease: { latest })
        await newer.checkForUpdates()
        precondition(newer.status == .current && newer.release == nil)
        let failure = AppUpdater(fetchRelease: { throw URLError(.notConnectedToInternet) })
        await failure.checkForUpdates()
        precondition(failure.status == .checkFailed && failure.release == nil && !failure.canInstall)
        let development = AppUpdater(current: AppVersion(version: "0.4.0", build: "6"),
                                     appURL: URL(fileURLWithPath: "/tmp/check-updates"), fetchRelease: { latest })
        await development.checkForUpdates()
        precondition(development.release != nil && !development.canInstall)
        let gate = FetchGate(release: latest)
        let delayed = AppUpdater(current: AppVersion(version: "0.4.0", build: "6"), fetchRelease: { await gate.fetch() })
        let first = Task { await delayed.checkForUpdates() }
        while delayed.status != .checking { await Task.yield() }
        await delayed.checkForUpdates()
        precondition(delayed.status == .checking && !delayed.canInstall)
        await gate.finish()
        await first.value
        let fetchCount = await gate.count()
        precondition(fetchCount == 1)
        precondition(delayed.status == .available)
        precondition(!AppUpdater.isHomebrewApp(URL(fileURLWithPath: "/private/tmp/direct-install/Mactamatone.app")))
        let temp = FileManager.default.temporaryDirectory.appendingPathComponent("update-checks-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: temp, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: temp) }
        let target = temp.appendingPathComponent("Caskroom/mactamatone/0.4.0/Mactamatone.app")
        try FileManager.default.createDirectory(at: target, withIntermediateDirectories: true)
        let link = temp.appendingPathComponent("Mactamatone.app")
        try FileManager.default.createSymbolicLink(at: link, withDestinationURL: target)
        precondition(AppUpdater.isHomebrewApp(link))
        let movedApp = temp.appendingPathComponent("Applications/Mactamatone.app")
        try FileManager.default.createDirectory(at: movedApp, withIntermediateDirectories: true)
        let receipt = temp.appendingPathComponent("brew/Caskroom/mactamatone/0.5.0")
        try FileManager.default.createDirectory(at: receipt, withIntermediateDirectories: true)
        try FileManager.default.createSymbolicLink(at: receipt.appendingPathComponent("Mactamatone.app"),
                                                   withDestinationURL: movedApp)
        precondition(AppUpdater.isHomebrewApp(movedApp, caskRoots: [receipt.deletingLastPathComponent()]))
        precondition(!AppUpdater.isHomebrewApp(movedApp, caskRoots: []))
        try await BrewUpdateRunner.run("/usr/bin/true", arguments: [])
        do { try await BrewUpdateRunner.run("/usr/bin/false", arguments: []); preconditionFailure("Process failure was ignored") }
        catch UpdateFailure.brewFailed {}
        try await BrewUpdateRunner.run("/usr/bin/python3", arguments: ["-c", "import sys; sys.stdout.write('x' * 300000); sys.stderr.write('y' * 300000)"])
        for language in AppLanguage.allCases {
            for key in LocalizedText.allCases { precondition(language.text(key) != key.rawValue) }
        }
        FileHandle.standardError.write(Data("All offline updater checks passed.\n".utf8))
        if CommandLine.arguments.contains("--live") {
            do {
                let release = try await LatestRelease.fetch()
                print("Live GitHub latest release: \(release.version)")
            } catch {
                FileHandle.standardError.write(Data("Live check error: \(error)\n".utf8))
                throw error
            }
        }
        print("Version ordering, stable-release validation, update states, duplicate checks, Homebrew symlinks, and nonblocking subprocesses verified.")
    }

    static func payload(version: String, draft: Bool = false, prerelease: Bool = false,
                        asset: Bool = true, domain: String = "https://github.com/yurseria/mactamatone/") throws -> Data {
        try JSONSerialization.data(withJSONObject: [
            "tag_name": "v\(version)", "html_url": "\(domain)releases/tag/v\(version)",
            "draft": draft, "prerelease": prerelease,
            "assets": asset ? [["name": "Mactamatone_\(version)_aarch64.dmg",
                                  "browser_download_url": "\(domain)releases/download/v\(version)/Mactamatone_\(version)_aarch64.dmg"]] : []
        ])
    }
}

actor FetchGate {
    private let release: LatestRelease
    private var continuation: CheckedContinuation<LatestRelease, Never>?
    private var finished = false
    private var calls = 0
    init(release: LatestRelease) { self.release = release }
    func fetch() async -> LatestRelease {
        calls += 1
        if finished { return release }
        return await withCheckedContinuation { continuation = $0 }
    }
    func finish() { finished = true; continuation?.resume(returning: release); continuation = nil }
    func count() -> Int { calls }
}
