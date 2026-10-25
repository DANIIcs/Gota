import SwiftUI

/// The menu shown when clicking the drop icon in the menu bar.
struct MenuContent: View {
    @ObservedObject private var jobs = JobRunner.shared
    @Environment(\.openSettings) private var openSettings

    var body: some View {
        if jobs.running > 0 {
            Text("Procesando \(jobs.running)…")
        }

        Text("Arrastra un archivo y presiona ⇧ convertir · ⌥ herramientas · ⌃ acciones")

        if !jobs.recent.isEmpty {
            Divider()
            Section("Recientes") {
                ForEach(jobs.recent) { result in
                    Button {
                        jobs.reveal(result)
                    } label: {
                        Label(result.title, systemImage: result.failed ? "exclamationmark.triangle" : "checkmark.circle")
                    }
                }
            }
        }

        Divider()

        Button("Ajustes…") {
            NSApp.activate()
            openSettings()
        }
        .keyboardShortcut(",")

        Button("Salir de Gota") {
            NSApp.terminate(nil)
        }
        .keyboardShortcut("q")
    }
}
