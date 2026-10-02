import AppKit
import Combine
import Foundation
import Sparkle

struct ReleaseVersion: Comparable {
    let components: [Int]

    init?(_ value: String) {
        let text = value.hasPrefix("v") ? String(value.dropFirst()) : value
        let parts = text.split(separator: ".", omittingEmptySubsequences: false)
        guard parts.count == 3, parts.allSatisfy({ !$0.isEmpty && $0.allSatisfy(\.isNumber) }),
              parts.compactMap({ Int($0) }).count == 3 else { return nil }
        components = parts.compactMap { Int($0) }
    }

    static func < (lhs: Self, rhs: Self) -> Bool {
        lhs.components.lexicographicallyPrecedes(rhs.components)
    }
}

struct AppVersion {
    let version: String
    let build: String

    static let current: Self = {
        // CLI runs and native capture tools use the repository's same Info.plist.
        let sourceRoot = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
            .deletingLastPathComponent().deletingLastPathComponent()
        let sourceInfo = NSDictionary(contentsOf: sourceRoot.appendingPathComponent("Info.plist")) as? [String: Any]
        let info = Bundle.main.bundleURL.pathExtension == "app" ? Bundle.main.infoDictionary : sourceInfo
        return Self(version: info?["CFBundleShortVersionString"] as? String ?? "—",
                    build: info?["CFBundleVersion"] as? String ?? "—")
    }()
}

struct LatestRelease: Equatable {
    let version: String
    let pageURL: URL

    static func decode(_ data: Data) throws -> Self {
        struct Asset: Decodable { let name: String; let browser_download_url: URL }
        struct Release: Decodable {
            let tag_name: String
            let html_url: URL
            let draft: Bool
            let prerelease: Bool
            let assets: [Asset]
        }
        let release = try JSONDecoder().decode(Release.self, from: data)
        guard !release.draft, !release.prerelease,
              ReleaseVersion(release.tag_name) != nil else { throw UpdateFailure.invalidRelease }
        let version = release.tag_name.hasPrefix("v") ? String(release.tag_name.dropFirst()) : release.tag_name
        let prefix = "https://github.com/yurseria/mactamatone/"
        guard release.html_url.absoluteString.hasPrefix(prefix + "releases/tag/"),
              release.assets.contains(where: {
                  $0.name == "Mactamatone_\(version)_aarch64.dmg" &&
                  $0.browser_download_url.absoluteString == prefix + "releases/download/v\(version)/\($0.name)"
              }) else { throw UpdateFailure.invalidRelease }
        return Self(version: version, pageURL: release.html_url)
    }

    static func fetch(session: URLSession = .shared) async throws -> Self {
        var request = URLRequest(url: URL(string: "https://api.github.com/repos/yurseria/mactamatone/releases/latest")!,
                                 cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 20)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("2022-11-28", forHTTPHeaderField: "X-GitHub-Api-Version")
        request.setValue("Mactamatone/\(AppVersion.current.version)", forHTTPHeaderField: "User-Agent")
        let (data, response) = try await session.data(for: request)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else { throw UpdateFailure.checkFailed }
        return try decode(data)
    }
}

enum UpdateFailure: Error {
    case invalidRelease, checkFailed, brewUnavailable, brewFailed, tapPending, developmentBuild, relaunchFailed
}

enum UpdateStatus: Equatable {
    case idle, checking, current, available, installing, checkFailed, installFailed

    var isBusy: Bool { self == .checking || self == .installing }
}

final class AppUpdater: NSObject, ObservableObject, SPUUpdaterDelegate {
    @Published private(set) var status: UpdateStatus = .idle
    @Published private(set) var release: LatestRelease?
    let current: AppVersion
    let appURL: URL
    private let fetchRelease: () async throws -> LatestRelease
    private var sparkle: SPUStandardUpdaterController?

    init(current: AppVersion = .current, appURL: URL = Bundle.main.bundleURL,
         fetchRelease: @escaping () async throws -> LatestRelease = { try await LatestRelease.fetch() }) {
        self.current = current
        self.appURL = appURL
        self.fetchRelease = fetchRelease
        super.init()
    }

    var canInstall: Bool { appURL.pathExtension == "app" && release != nil && !status.isBusy }

    static func isHomebrewApp(_ url: URL, caskRoots: [URL] = [
        URL(fileURLWithPath: "/opt/homebrew/Caskroom/mactamatone"),
        URL(fileURLWithPath: "/usr/local/Caskroom/mactamatone")
    ]) -> Bool {
        let resolved = url.resolvingSymlinksInPath()
        let components = resolved.pathComponents
        if let index = components.firstIndex(of: "Caskroom"),
           components.indices.contains(index + 1), components[index + 1] == "mactamatone" {
            return true
        }
        // Casks commonly move the app into /Applications and retain a link
        // pointing BACK to it in Caskroom, not the other way around.
        return caskRoots.contains { root in
            let versions = (try? FileManager.default.contentsOfDirectory(at: root,
                includingPropertiesForKeys: nil, options: .skipsHiddenFiles)) ?? []
            return versions.contains { version in
                let receiptApp = version.appendingPathComponent("Mactamatone.app")
                return FileManager.default.fileExists(atPath: receiptApp.path) &&
                    receiptApp.resolvingSymlinksInPath() == resolved
            }
        }
    }

    @MainActor func checkForUpdates() async {
        guard !status.isBusy else { return }
        status = .checking
        release = nil
        do {
            let latest = try await fetchRelease()
            guard let installed = ReleaseVersion(current.version), let candidate = ReleaseVersion(latest.version) else {
                throw UpdateFailure.invalidRelease
            }
            if candidate > installed {
                release = latest
                status = .available
            } else {
                status = .current
            }
        } catch {
            status = .checkFailed
        }
    }

    @MainActor func installUpdate() async {
        guard canInstall, let release else { return }
        status = .installing
        do {
            if Self.isHomebrewApp(appURL) {
                try await installWithHomebrew(expectedVersion: release.version)
            } else {
                if sparkle == nil {
                    sparkle = SPUStandardUpdaterController(startingUpdater: false, updaterDelegate: self,
                                                          userDriverDelegate: nil)
                    try sparkle!.updater.start()
                }
                guard sparkle!.updater.canCheckForUpdates else { throw UpdateFailure.checkFailed }
                sparkle!.checkForUpdates(nil)
            }
        } catch {
            status = .installFailed
        }
    }

    @MainActor func updater(_ updater: SPUUpdater, didFinishUpdateCycleFor updateCheck: SPUUpdateCheck, error: Error?) {
        let canceled = (error as NSError?)?.domain == SUSparkleErrorDomain &&
            (error as NSError?)?.code == Int(SUError.installationCanceledError.rawValue)
        status = error == nil || canceled ? (release == nil ? .current : .available) : .installFailed
    }

    @MainActor private func installWithHomebrew(expectedVersion: String) async throws {
        guard let brew = ["/opt/homebrew/bin/brew", "/usr/local/bin/brew"].first(where: {
            FileManager.default.isExecutableFile(atPath: $0)
        }) else { throw UpdateFailure.brewUnavailable }
        try await BrewUpdateRunner.run(brew, arguments: ["update"])
        try await BrewUpdateRunner.run(brew, arguments: ["upgrade", "--cask", "yurseria/tap/mactamatone"])
        let installedURL = URL(fileURLWithPath: "/Applications/Mactamatone.app")
        // Read fresh metadata; Bundle.main can cache the pre-upgrade Info.plist.
        guard let info = NSDictionary(contentsOf: installedURL.appendingPathComponent("Contents/Info.plist")),
              let version = info["CFBundleShortVersionString"] as? String,
              let installed = ReleaseVersion(version), let expected = ReleaseVersion(expectedVersion),
              installed >= expected else { throw UpdateFailure.tapPending }
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.createsNewApplicationInstance = true
        _ = try await NSWorkspace.shared.openApplication(at: installedURL, configuration: configuration)
        NSApp.terminate(nil)
    }
}

/// Process arguments are passed directly, never through a shell. File output
/// avoids pipe-buffer deadlocks while Homebrew runs outside the UI thread.
enum BrewUpdateRunner {
    static func run(_ executable: String, arguments: [String]) async throws {
        let log = FileManager.default.temporaryDirectory.appendingPathComponent("mactamatone-update-\(UUID().uuidString).log")
        FileManager.default.createFile(atPath: log.path, contents: nil, attributes: [.posixPermissions: 0o600])
        let output = try FileHandle(forWritingTo: log)
        defer { try? output.close(); try? FileManager.default.removeItem(at: log) }
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        process.standardOutput = output
        process.standardError = output
        var environment = ProcessInfo.processInfo.environment
        environment["HOMEBREW_NO_AUTO_UPDATE"] = "1"
        environment["HOMEBREW_NO_ANALYTICS"] = "1"
        environment["NONINTERACTIVE"] = "1"
        environment["PATH"] = "/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"
        process.environment = environment
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            process.terminationHandler = { task in
                if task.terminationStatus == 0 { continuation.resume() }
                else { continuation.resume(throwing: UpdateFailure.brewFailed) }
            }
            do { try process.run() }
            catch { continuation.resume(throwing: error) }
        }
    }
}
