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

    @State private var pane: SettingsPane? = .general
    @State private var search = ""

    /// Laid out like System Settings: a searchable sidebar of colored icons, the pane on the right.
    var body: some View {
        NavigationSplitView {
            List(SettingsPane.matching(search), selection: $pane) { pane in
                Label { Text(pane.title) } icon: { SettingsIcon(pane: pane) }
                    .tag(pane)
            }
            .searchable(text: $search, placement: .sidebar, prompt: "Buscar")
            .navigationSplitViewColumnWidth(215)
            .toolbar(removing: .sidebarToggle)
        } detail: {
            detail(for: pane ?? .general)
                .navigationTitle((pane ?? .general).title)
        }
        .frame(width: 720, height: 480)
    }

    @ViewBuilder
    private func detail(for pane: SettingsPane) -> some View {
        switch pane {
        case .general: general
        case .appearance: appearance
        case .keys: keys
        case .engines: engines
        case .about: about
        }
    }

    private var general: some View {
        Form {
            Section {
                Toggle("Abrir Gota al iniciar sesión", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { _, enabled in
                        setLaunchAtLogin(enabled)
                    }
            } footer: {
                if let loginError {
                    Text(loginError).foregroundStyle(.red)
                }
            }
            Section {
                Toggle("Mostrar el resultado en Finder", isOn: $revealInFinder)
                Toggle("Reproducir sonido", isOn: $playSound)
            } header: {
                Text("Al terminar una conversión")
            } footer: {
                Text("El sonido es el de alerta que elegiste en Ajustes del Sistema → Sonido.")
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
            } footer: {
                Text("Liquid Glass sigue el material del sistema. Con 100 % de opacidad las burbujas son sólidas.")
            }
        }
        .formStyle(.grouped)
    }

    private var keys: some View {
        Form {
            Section {
                ForEach(WheelMode.allCases, id: \.self) { mode in
                    LabeledContent {
                        Text(mode.title)
                    } label: {
                        Label("\(mode.key)  \(mode.keyName)", systemImage: mode.symbol)
                    }
                }
            } header: {
                Text("Mientras arrastras un archivo, mantén")
            } footer: {
                Text("Empieza a arrastrar desde Finder o el Escritorio y luego pulsa la tecla. Suelta en el centro de la rueda para cancelar.")
            }
        }
        .formStyle(.grouped)
    }

    private var engines: some View {
        Form {
            Section {
                LabeledContent("LibreOffice") {
                    EngineStatus(installed: LibreOfficeEngine().isAvailable)
                }
                LabeledContent("Keynote (presentaciones)") {
                    EngineStatus(installed: KeynoteEngine().isAvailable)
                }
                LabeledContent("macOS (integrado)") {
                    EngineStatus(installed: true)
                }
            } header: {
                Text("Documentos y presentaciones → PDF")
            } footer: {
                Text("Gota usa el primero disponible, sin abrir ventanas. LibreOffice es el más fiel a Word y PowerPoint.")
            }
            Section {
                Toggle("Usar Microsoft Office", isOn: $useMicrosoftOffice)
                    .disabled(!MicrosoftWordEngine.isInstalled && !MicrosoftPowerPointEngine.isInstalled)
            } header: {
                Text("Avanzado")
            } footer: {
                Text("Formato exacto con Word y PowerPoint, pero se abren al convertir y piden acceso a cada carpeta.")
            }
        }
        .formStyle(.grouped)
    }

    private var about: some View {
        Form {
            Section {
                VStack(spacing: 8) {
                    Image(nsImage: NSApp.applicationIconImage)
                        .resizable()
                        .frame(width: 72, height: 72)
                    Text("Gota").font(.title2.bold())
                    Text("Versión \(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "–")")
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
            }
            Section {
                LabeledContent("Privacidad", value: "Todo pasa en tu Mac, sin internet")
                LabeledContent("Licencia", value: "MIT, código abierto")
                Link(destination: URL(string: "https://github.com/DANIIcs/Gota")!) {
                    Label("Código fuente en GitHub", systemImage: "arrow.up.right.square")
                }
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

/// The panes of the settings window, in sidebar order.
private enum SettingsPane: String, CaseIterable, Identifiable {
    case general, appearance, keys, engines, about

    var id: Self { self }

    var title: String {
        switch self {
        case .general: "General"
        case .appearance: "Apariencia"
        case .keys: "Teclas"
        case .engines: "Motores"
        case .about: "Acerca de"
        }
    }

    var symbol: String {
        switch self {
        case .general: "gearshape.fill"
        case .appearance: "paintpalette.fill"
        case .keys: "keyboard.fill"
        case .engines: "doc.richtext.fill"
        case .about: "info.circle.fill"
        }
    }

    /// Icon tile colors, the way System Settings colors its panes.
    var color: Color {
        switch self {
        case .general: .gray
        case .appearance: .blue
        case .keys: .indigo
        case .engines: .orange
        case .about: .teal
        }
    }

    /// Words a search should find this pane by, besides its title.
    private var keywords: [String] {
        switch self {
        case .general: ["iniciar", "sesión", "sonido", "finder", "terminar"]
        case .appearance: ["color", "opacidad", "liquid", "glass", "transparente", "negro", "rgb", "rueda"]
        case .keys: ["shift", "option", "control", "convertir", "herramientas", "acciones", "atajo"]
        case .engines: ["pdf", "word", "powerpoint", "office", "libreoffice", "keynote", "documento"]
        case .about: ["versión", "licencia", "github", "privacidad"]
        }
    }

    static func matching(_ search: String) -> [SettingsPane] {
        let query = search.trimmingCharacters(in: .whitespaces).lowercased()
        guard !query.isEmpty else { return allCases }
        return allCases.filter { pane in
            pane.title.lowercased().contains(query) || pane.keywords.contains { $0.contains(query) }
        }
    }
}

/// A white symbol on a colored rounded square, like the icons in System Settings' sidebar.
private struct SettingsIcon: View {
    let pane: SettingsPane

    var body: some View {
        Image(systemName: pane.symbol)
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(.white)
            .frame(width: 20, height: 20)
            .background(pane.color.gradient, in: RoundedRectangle(cornerRadius: 5, style: .continuous))
    }
}

private struct EngineStatus: View {
    let installed: Bool

    var body: some View {
        Label(installed ? "Disponible" : "No instalado", systemImage: installed ? "checkmark.circle.fill" : "minus.circle")
            .foregroundStyle(installed ? Color.green : Color.secondary)
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
