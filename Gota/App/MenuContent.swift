import SwiftUI

/// The menu shown when clicking the drop icon in the menu bar.
struct MenuContent: View {
    @ObservedObject private var jobs = JobRunner.shared
    @Environment(\.openSettings) private var openSettings

    var body: some View {
        if jobs.running > 0 {
            Text("Procesando \(jobs.running)…")
        }

        // One short line per key: a single long hint was hard to read in the menu.
        Section("Al arrastrar un archivo, mantén") {
            ForEach(WheelMode.allCases, id: \.self) { mode in
                Text("\(mode.key)  \(mode.title)")
            }
        }

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
            showSettings()
        }
        .keyboardShortcut(",")

        Button("Salir de Gota") {
            NSApp.terminate(nil)
        }
        .keyboardShortcut("q")
    }

    /// Gota has no Dock icon, so it isn't the active app and its Settings window opened behind the
    /// app in front. It's brought forward once it exists (it's created on a later run loop turn);
    /// after that it's an ordinary window, not one that stays on top.
    private func showSettings() {
        openSettings()
        Task { @MainActor in
            for _ in 0..<20 {
                if let window = NSApp.windows.first(where: SettingsWindow.matches) {
                    NSApp.activate()
                    window.makeKeyAndOrderFront(nil)
                    window.orderFrontRegardless()
                    return
                }
                try? await Task.sleep(for: .milliseconds(25))
            }
        }
    }
}

enum SettingsWindow {
    /// SwiftUI's identifier for the window of the `Settings` scene, or failing that (should SwiftUI
    /// rename it) Gota's only ordinary window: the wheel panels and the menu bar item aren't key windows.
    static func matches(_ window: NSWindow) -> Bool {
        if window.identifier?.rawValue == "com_apple_SwiftUI_Settings_window" { return true }
        return window.isVisible && window.canBecomeKey && !(window is NSPanel)
    }
}
