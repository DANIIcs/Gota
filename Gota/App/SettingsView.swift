import ServiceManagement
import SwiftUI

struct SettingsView: View {
    @AppStorage(Preferences.revealInFinderKey) private var revealInFinder = false
    @AppStorage(Preferences.useMicrosoftWordKey) private var useMicrosoftWord = false
    @AppStorage(Preferences.playSoundKey) private var playSound = true
    @AppStorage(WheelMaterial.key) private var material = WheelMaterial.glass
    @AppStorage(WheelColor.key) private var wheelColor = WheelColor.automatic
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
                Toggle("Sonido al terminar", isOn: $playSound)
            }

            Section("Apariencia de la rueda") {
                Picker("Material", selection: $material) {
                    ForEach(WheelMaterial.allCases) { Text($0.title).tag($0) }
                }
                .pickerStyle(.segmented)
                LabeledContent("Color") {
                    ColorSwatches(selection: $wheelColor)
                }
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

/// A row of colored dots, like the accent color picker in System Settings.
private struct ColorSwatches: View {
    @Binding var selection: WheelColor

    var body: some View {
        HStack(spacing: 7) {
            ForEach(WheelColor.allCases) { color in
                Button {
                    selection = color
                } label: {
                    Circle()
                        .fill(swatch(color))
                        .frame(width: 16, height: 16)
                        .overlay(Circle().strokeBorder(.black.opacity(0.15), lineWidth: 0.5))
                        .padding(2)
                        .overlay(Circle().strokeBorder(Color.primary.opacity(selection == color ? 0.6 : 0), lineWidth: 1.5))
                }
                .buttonStyle(.plain)
                .help(color.title)
                .accessibilityLabel(color.title)
            }
        }
    }

    private func swatch(_ color: WheelColor) -> AnyShapeStyle {
        if color == .rgb {
            return AnyShapeStyle(AngularGradient(colors: [.red, .yellow, .green, .cyan, .blue, .purple, .red], center: .center))
        }
        return AnyShapeStyle(color.color())
    }
}

enum Preferences {
    static let revealInFinderKey = "revealInFinder"
    static let playSoundKey = "playSound"

    /// On unless turned off: a fresh install has no value stored yet.
    static var playSound: Bool {
        UserDefaults.standard.object(forKey: playSoundKey) as? Bool ?? true
    }
    static let useMicrosoftWordKey = "useMicrosoftWord"

    static var useMicrosoftWord: Bool {
        UserDefaults.standard.bool(forKey: useMicrosoftWordKey)
    }

    static var revealInFinder: Bool {
        UserDefaults.standard.bool(forKey: revealInFinderKey)
    }
}
