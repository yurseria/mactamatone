import SwiftUI

struct UpdatePanel: View {
    @ObservedObject var updater: AppUpdater
    let language: AppLanguage
    let accent: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(language.text(.updates))
                .font(.system(size: 12, weight: .semibold))
            if let message {
                Text(message)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            HStack {
                if updater.status.isBusy {
                    ProgressView().controlSize(.small)
                }
                Button {
                    Task { await updater.checkForUpdates() }
                } label: {
                    Text(language.text(updater.status == .checking ? .checkingUpdates : .checkForUpdates))
                        .font(.system(size: 12, weight: .semibold))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 7)
                        .foregroundStyle(.white)
                        .background(Color(red: 0.32, green: 0.50, blue: 0.93),
                                    in: RoundedRectangle(cornerRadius: 7))
                }
                .buttonStyle(.plain)
                .opacity(updater.status.isBusy ? 0.6 : 1)
                .disabled(updater.status.isBusy)
            }
            if updater.release != nil {
                Button(language.text(updater.status == .installing ? .installingUpdate : .installUpdate)) {
                    Task { await updater.installUpdate() }
                }
                .buttonStyle(.borderedProminent)
                .tint(accent)
                .disabled(!updater.canInstall)
                if let release = updater.release {
                    Link(language.text(.viewRelease), destination: release.pageURL)
                        .font(.system(size: 11))
                }
                if updater.appURL.pathExtension != "app" {
                    Text(language.text(.updateDevelopment))
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
    }

    private var message: String? {
        switch updater.status {
        case .idle: return nil
        case .checking: return language.text(.checkingUpdates)
        case .current: return language.text(.upToDate)
        case .available: return updater.release.map { language.format(.updateAvailable, $0.version) }
        case .installing: return language.text(.installingUpdate)
        case .checkFailed: return language.text(.updateCheckFailed)
        case .installFailed: return language.text(.updateInstallFailed)
        }
    }
}
