import AppKit

/// "Buscar actualizaciones…": asks GitHub for the latest release, only when the user clicks.
///
/// This is the one place Gota goes online, and never on its own: no check at launch or in the
/// background, nothing sent but the request itself. A newer version opens its release page.
enum UpdateChecker {
    static let repository = "DANIIcs/Gota"
    private static let latestRelease = URL(string: "https://api.github.com/repos/\(repository)/releases/latest")!

    struct Release: Equatable {
        let version: String
        let page: URL
    }

    enum Outcome: Equatable {
        case upToDate(String)
        case available(Release)
    }

    static var currentVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0"
    }

    static var currentBuild: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "0"
    }

    /// Opt-in (off by default): Gota promises not to go online on its own.
    static let automaticKey = "autoCheckUpdates"
    static let lastCheckKey = "lastUpdateCheck"
    static let interval: TimeInterval = 24 * 60 * 60

    /// Whether an automatic check is due: turned on and none in the last day.
    static func isDue(now: Date = .now, defaults: UserDefaults = .standard) -> Bool {
        guard defaults.bool(forKey: automaticKey) else { return false }
        return now.timeIntervalSince1970 - defaults.double(forKey: lastCheckKey) >= interval
    }

    /// The automatic check: silent unless there's a new version, then a notification that opens its page.
    @MainActor
    static func checkInBackgroundIfDue() async {
        guard isDue() else { return }
        UserDefaults.standard.set(Date.now.timeIntervalSince1970, forKey: lastCheckKey)
        guard case .available(let release)? = try? await check() else { return }
        Notifier.post(title: "Gota \(release.version) está disponible", body: "Pulsa para descargarla.", opening: release.page)
    }

    @MainActor
    static func checkAndReport() async {
        UserDefaults.standard.set(Date.now.timeIntervalSince1970, forKey: lastCheckKey)
        let outcome: Result<Outcome, Error>
        do {
            outcome = .success(try await check())
        } catch {
            outcome = .failure(error)
        }
        present(outcome)
    }

    static func check() async throws -> Outcome {
        var request = URLRequest(url: latestRelease, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 15)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("Gota/\(currentVersion)", forHTTPHeaderField: "User-Agent") // GitHub requires one
        // Ephemeral: no cookies, no cache, nothing kept between checks.
        let (data, response) = try await URLSession(configuration: .ephemeral).data(for: request)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else { throw URLError(.badServerResponse) }
        let release = try parse(data)
        return isNewer(release.version, than: currentVersion) ? .available(release) : .upToDate(currentVersion)
    }

    /// Reads GitHub's answer. The page must be one of this repository's releases on github.com, so a
    /// tampered answer can't send the user anywhere else.
    static func parse(_ data: Data) throws -> Release {
        struct Payload: Decodable {
            let tag_name: String
            let html_url: URL
        }
        let payload = try JSONDecoder().decode(Payload.self, from: data)
        guard payload.html_url.scheme == "https",
              payload.html_url.host() == "github.com",
              payload.html_url.path().hasPrefix("/\(repository)/releases/") else {
            throw URLError(.badServerResponse)
        }
        let version = payload.tag_name.hasPrefix("v") ? String(payload.tag_name.dropFirst()) : payload.tag_name
        return Release(version: version, page: payload.html_url)
    }

    /// "0.10.0" is newer than "0.9.1": numeric parts compared one by one, missing parts count as 0.
    static func isNewer(_ candidate: String, than current: String) -> Bool {
        let a = candidate.split(separator: ".").map { Int($0) ?? 0 }
        let b = current.split(separator: ".").map { Int($0) ?? 0 }
        for index in 0..<max(a.count, b.count) {
            let (x, y) = (index < a.count ? a[index] : 0, index < b.count ? b[index] : 0)
            if x != y { return x > y }
        }
        return false
    }

    @MainActor
    private static func present(_ outcome: Result<Outcome, Error>) {
        NSApp.activate() // a menu bar app's alert would otherwise open behind the frontmost app
        let alert = NSAlert()
        switch outcome {
        case .success(.available(let release)):
            alert.messageText = "Gota \(release.version) está disponible"
            alert.informativeText = "Tienes la \(currentVersion). Descarga la nueva, sal de Gota y reemplázala en Aplicaciones."
            alert.addButton(withTitle: "Descargar")
            alert.addButton(withTitle: "Más tarde")
            if alert.runModal() == .alertFirstButtonReturn {
                NSWorkspace.shared.open(release.page)
            }
        case .success(.upToDate(let version)):
            alert.messageText = "Gota está al día"
            alert.informativeText = "Tienes la última versión (\(version))."
            alert.runModal()
        case .failure:
            alert.messageText = "No se pudo buscar actualizaciones"
            alert.informativeText = "Revisa tu conexión a internet e inténtalo de nuevo."
            alert.alertStyle = .warning
            alert.runModal()
        }
    }
}
