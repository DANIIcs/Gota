import AppKit
import Combine

/// One finished job, listed under "Recientes" in the menu.
struct JobResult: Identifiable {
    let id = UUID()
    let title: String
    let outputs: [URL]
    let failed: Bool
}

/// Runs actions in the background and reports the result.
@MainActor
final class JobRunner: ObservableObject {
    static let shared = JobRunner()

    @Published private(set) var running = 0
    @Published private(set) var recent: [JobResult] = []

    func run(_ action: WheelAction, on files: [URL]) {
        running += 1
        let label = files.count == 1 ? files[0].lastPathComponent : String(localized: "\(files.count) archivos")

        Task {
            defer { running -= 1 }
            do {
                // `perform` is not tied to the main actor, so the heavy work runs off the UI thread.
                let outputs = try await action.perform(files)
                remember(JobResult(title: "\(action.title) · \(label)", outputs: outputs, failed: false))
                Self.playSound(failed: false)
                if !outputs.isEmpty {
                    Notifier.post(title: String(localized: "Listo: \(action.title)"), body: outputs.map(\.lastPathComponent).joined(separator: ", "))
                    if Preferences.revealInFinder {
                        NSWorkspace.shared.activateFileViewerSelecting(outputs)
                    }
                }
            } catch {
                remember(JobResult(title: "\(action.title) · \(label)", outputs: [], failed: true))
                Self.playSound(failed: true)
                Notifier.post(title: String(localized: "No se pudo: \(action.title)"), body: error.localizedDescription,
                              opening: (error as? ConversionError)?.helpURL)
            }
        }
    }

    /// The alert sound chosen in System Settings → Sound, at its alert volume, so it fits whatever
    /// the user already hears from their Mac instead of a sound of Gota's own.
    private static func playSound(failed: Bool) {
        guard Preferences.playSound else { return }
        NSSound.beep()
    }

    func reveal(_ result: JobResult) {
        guard !result.outputs.isEmpty else { return }
        NSWorkspace.shared.activateFileViewerSelecting(result.outputs)
    }

    private func remember(_ result: JobResult) {
        recent.insert(result, at: 0)
        if recent.count > 8 {
            recent.removeLast(recent.count - 8)
        }
    }
}
