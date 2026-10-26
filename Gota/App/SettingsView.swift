import ServiceManagement
import SwiftUI

struct SettingsView: View {
    @AppStorage(Preferences.revealInFinderKey) private var revealInFinder = false
    @AppStorage(Preferences.useMicrosoftOfficeKey) private var useMicrosoftOffice = false
    @AppStorage(Preferences.playSoundKey) private var playSound = true
    @AppStorage(WheelMaterial.key) private var material = WheelMaterial.glass
    @AppStorage(WheelMaterial.opacityKey) private var opacity = 0.0
    @AppStorage(WheelColor.key) private var wheelColor = WheelColor.automatic
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled
    @State private var loginError: String?

    /// Tabs, like the system's own settings windows: one long form grew taller than the screen.
    var body: some View {
        TabView {
            Tab("General", systemImage: "gearshape") { general }
            Tab("Apariencia", systemImage: "paintpalette") { appearance }
            Tab("Motores", systemImage: "doc.richtext") { engines }
        }
        .frame(width: 460)
        .fixedSize(horizontal: false, vertical: true)
    }

    private var general: some View {
        Form {
            Section {
                Toggle("Abrir Gota al iniciar sesión", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { _, enabled in
                        setLaunchAtLogin(enabled)
                    }
                if let loginError {
                    Text(loginError).font(.caption).foregroundStyle(.red)
                }
                Toggle("Mostrar el resultado en Finder al terminar", isOn: $revealInFinder)
                Toggle("Sonido al terminar (el de alerta de tu Mac)", isOn: $playSound)
            }

            Section("Teclas (mientras arrastras un archivo)") {
                ForEach(WheelMode.allCases, id: \.self) { mode in
                    LabeledContent("\(mode.key) \(mode.keyName)", value: mode.title)
                }
            }
        }
        .formStyle(.grouped)
    }

    private var appearance: some View {
        Form {
            Section {
                WheelPreview(material: material, opacity: opacity, color: wheelColor)
            }
            Section {
                Picker("Material", selection: $material) {
                    ForEach(WheelMaterial.allCases) { Text($0.title).tag($0) }
                }
                .pickerStyle(.segmented)
                LabeledContent("Opacidad") {
                    HStack {
                        Slider(value: $opacity, in: 0...1)
                        Text(opacity, format: .percent.precision(.fractionLength(0)))
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                            .frame(width: 40, alignment: .trailing)
                    }
                }
                LabeledContent("Color") {
                    ColorSwatches(selection: $wheelColor)
                }
            }
        }
        .formStyle(.grouped)
    }

    private var engines: some View {
        Form {
            Section("Documentos y presentaciones → PDF") {
                Toggle("Usar Microsoft Office (Word y PowerPoint)", isOn: $useMicrosoftOffice)
                    .disabled(!MicrosoftWordEngine.isInstalled && !MicrosoftPowerPointEngine.isInstalled)
                LabeledContent("LibreOffice") {
                    let installed = LibreOfficeEngine().isAvailable
                    Text(installed ? "Instalado" : "No encontrado")
                        .foregroundStyle(installed ? Color.green : Color.secondary)
                }
                LabeledContent("Keynote (presentaciones)") {
                    let installed = KeynoteEngine().isAvailable
                    Text(installed ? "Instalado" : "No encontrado")
                        .foregroundStyle(installed ? Color.green : Color.secondary)
                }
                LabeledContent("macOS (integrado)") {
                    Text("Siempre disponible").foregroundStyle(Color.green)
                }
            }
            Section {
                Text("Gota usa el primero disponible. Office da el formato exacto; si no, LibreOffice es el más fiel (medido contra Word y PowerPoint). Office y Keynote piden permiso la primera vez.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
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

/// Three bubbles drawn exactly like the wheel's (the middle one hovered), so changes show live.
private struct WheelPreview: View {
    let material: WheelMaterial
    let opacity: Double
    let color: WheelColor

    private let symbols = ["doc.richtext", "photo", "text.alignleft"]

    var body: some View {
        TimelineView(.animation(paused: color != .rgb)) { context in
            GlassEffectContainer {
                HStack(spacing: 22) {
                    ForEach(symbols.indices, id: \.self) { index in
                        let hovered = index == 1
                        Image(systemName: symbols[index])
                            .font(.system(size: hovered ? 20 : 17, weight: .semibold))
                            .foregroundStyle(hovered || color.isDark ? Color.white : Color.primary)
                            .frame(width: hovered ? 54 : 46, height: hovered ? 54 : 46)
                            .bubbleSurface(material: material, opacity: opacity,
                                           tint: color.fill(phase: Double(index) / 3, at: context.date),
                                           strength: hovered ? WheelColor.hoveredTint : color.restingTint,
                                           rim: color.hasMetalRim,
                                           id: "\(index)", namespace: nil)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .animation(.easeOut(duration: 0.2), value: opacity)
        .accessibilityHidden(true)
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
        return color.fill()
    }
}

enum Preferences {
    static let revealInFinderKey = "revealInFinder"
    static let playSoundKey = "playSound"

    /// On unless turned off: a fresh install has no value stored yet.
    static var playSound: Bool {
        UserDefaults.standard.object(forKey: playSoundKey) as? Bool ?? true
    }
    /// Stored under its first name, when it only covered Word, so the user's choice carries over.
    static let useMicrosoftOfficeKey = "useMicrosoftWord"

    static var useMicrosoftOffice: Bool {
        UserDefaults.standard.bool(forKey: useMicrosoftOfficeKey)
    }

    static var revealInFinder: Bool {
        UserDefaults.standard.bool(forKey: revealInFinderKey)
    }
}
