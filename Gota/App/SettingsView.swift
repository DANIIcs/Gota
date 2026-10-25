import ServiceManagement
import SwiftUI

struct SettingsView: View {
    @AppStorage(Preferences.revealInFinderKey) private var revealInFinder = false
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled
    @State private var loginError: String?

    var body: some View {
        Form {
            Section("General") {
                Toggle("Abrir Gota al iniciar sesión", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { _, enabled in
                        setLaunchAtLogin(enabled)
                    }
                if let loginError {
                    Text(loginError).font(.caption).foregroundStyle(.red)
                }
                Toggle("Mostrar el resultado en Finder al terminar", isOn: $revealInFinder)
            }

            Section("Teclas (mientras arrastras un archivo)") {
                LabeledContent("⇧ Shift", value: WheelMode.convert.title)
                LabeledContent("⌥ Option", value: WheelMode.tools.title)
                LabeledContent("⌃ Control", value: WheelMode.actions.title)
            }

            Section("Motor para Word → PDF") {
                ForEach(DocumentEngines.all, id: \.name) { engine in
                    LabeledContent(engine.name) {
                        Text(engine.isAvailable ? "Instalado" : "No encontrado")
                            .foregroundStyle(engine.isAvailable ? Color.green : Color.secondary)
                    }
                }
                Text("Gota usa el primero disponible, en este orden. Word da el formato exacto.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .frame(width: 440)
        .fixedSize(horizontal: false, vertical: true)
    }

    private func setLaunchAtLogin(_ enabled: Bool) {
        // Reverting the toggle after an error fires onChange again: nothing to do then.
        guard enabled != (SMAppService.mainApp.status == .enabled) else { return }
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
            loginError = nil
        } catch {
            loginError = error.localizedDescription
            launchAtLogin = SMAppService.mainApp.status == .enabled
        }
    }
}

enum Preferences {
    static let revealInFinderKey = "revealInFinder"

    static var revealInFinder: Bool {
        UserDefaults.standard.bool(forKey: revealInFinderKey)
    }
}
