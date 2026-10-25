import ServiceManagement
import SwiftUI

struct SettingsView: View {
    @AppStorage(Preferences.revealInFinderKey) private var revealInFinder = false
    @AppStorage(Preferences.useMicrosoftWordKey) private var useMicrosoftWord = false
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
                ForEach(WheelMode.allCases, id: \.self) { mode in
                    LabeledContent("\(mode.key) \(mode.keyName)", value: mode.title)
                }
            }

            Section("Documentos → PDF") {
                Toggle("Usar Microsoft Word", isOn: $useMicrosoftWord)
                    .disabled(!MicrosoftWordEngine.isInstalled)
                LabeledContent("LibreOffice") {
                    let installed = LibreOfficeEngine().isAvailable
                    Text(installed ? "Instalado" : "No encontrado")
                        .foregroundStyle(installed ? Color.green : Color.secondary)
                }
                LabeledContent("macOS (integrado)") {
                    Text("Siempre disponible").foregroundStyle(Color.green)
                }
                Text("Gota usa el primero disponible. Word da el formato exacto, pero pide permisos la primera vez.")
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
    static let useMicrosoftWordKey = "useMicrosoftWord"

    static var useMicrosoftWord: Bool {
        UserDefaults.standard.bool(forKey: useMicrosoftWordKey)
    }

    static var revealInFinder: Bool {
        UserDefaults.standard.bool(forKey: revealInFinderKey)
    }
}
