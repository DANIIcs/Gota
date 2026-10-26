import ServiceManagement
import SwiftUI

struct SettingsView: View {
    @AppStorage(Preferences.revealInFinderKey) private var revealInFinder = false
    @AppStorage(Preferences.useMicrosoftOfficeKey) private var useMicrosoftOffice = false
    @AppStorage(Preferences.playSoundKey) private var playSound = true
    @AppStorage(WheelMaterial.key) private var material = WheelMaterial.glass
    @AppStorage(WheelMaterial.opacityKey) private var opacity = 0.0
    @AppStorage(WheelColor.key) private var wheelColor = WheelColor.automatic
    @AppStorage(UpdateChecker.automaticKey) private var autoCheckUpdates = false
    @AppStorage(UpdateChecker.lastCheckKey) private var lastUpdateCheck = 0.0
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
            Section { PaneHeader(pane: .general) }
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
            Section { PaneHeader(pane: .appearance) }
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
            Section { PaneHeader(pane: .keys) }
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
            Section { PaneHeader(pane: .engines) }
            Section {
                LabeledContent("Gota (Word .docx)") {
                    if DocxideEngine().isAvailable {
                        Label("Incluido", systemImage: "checkmark.circle.fill").foregroundStyle(Color.green)
                    } else {
                        EngineStatus(installed: false)
                    }
                }
                LabeledContent("LibreOffice") {
                    if LibreOfficeEngine().isAvailable {
                        EngineStatus(installed: true)
                    } else {
                        Link("Instalar (gratis)…", destination: LibreOfficeEngine.downloadPage)
                    }
                }
                LabeledContent("Keynote (.key, si falta LibreOffice)") {
                    EngineStatus(installed: KeynoteEngine().isAvailable)
                }
                LabeledContent("Pages (.pages, si falta LibreOffice)") {
                    EngineStatus(installed: PagesEngine().isAvailable)
                }
                LabeledContent("macOS (integrado)") {
                    EngineStatus(installed: true)
                }
            } header: {
                Text("Documentos y presentaciones → PDF")
            } footer: {
                Text(LibreOfficeEngine().isAvailable
                     ? "Para cada formato Gota usa el motor más fiel según mediciones, sin abrir ventanas: el suyo propio para .docx, LibreOffice para los demás formatos de Office y PowerPoint, macOS para texto plano."
                     : "Sin LibreOffice, Word se convierte con el motor de macOS (menos fiel) y PowerPoint necesita Keynote. LibreOffice es gratis y Gota lo usa en segundo plano, sin abrir ventanas.")
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
                VStack(spacing: 6) {
                    Image(nsImage: AppIcon.image)
                        .resizable()
                        .frame(width: 96, height: 96)
                    Text("Gota").font(.title.bold())
                    Text("Versión \(UpdateChecker.currentVersion) (\(UpdateChecker.currentBuild))")
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                    Text("Conversor de archivos para macOS")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
            }

            Section {
                Toggle("Buscar actualizaciones automáticamente", isOn: $autoCheckUpdates)
                LabeledContent("Última comprobación", value: lastCheckDescription)
                Button("Buscar ahora…") {
                    Task { await UpdateChecker.checkAndReport() }
                }
            } header: {
                Text("Actualizaciones")
            } footer: {
                Text("Gota solo se conecta a internet para esto: pregunta a GitHub por la última versión, como mucho una vez al día si lo activas, y te avisa con una notificación.")
            }

            Section {
                LabeledContent("Privacidad", value: "Tus archivos nunca salen de tu Mac")
                LabeledContent("Licencia", value: "MIT, código abierto")
                LabeledContent("Incluye", value: "docxide-pdf (Apache-2.0), Carlito y Caladea (OFL)")
            }

            Section {
                Link(destination: URL(string: "https://github.com/\(UpdateChecker.repository)")!) {
                    Label("Ver Gota en GitHub", systemImage: "chevron.left.forwardslash.chevron.right")
                        .frame(maxWidth: .infinity)
                }
                Link(destination: URL(string: "https://github.com/\(UpdateChecker.repository)/issues")!) {
                    Label("Reportar un problema", systemImage: "exclamationmark.bubble")
                        .frame(maxWidth: .infinity)
                }
            }
        }
        .formStyle(.grouped)
        // In the unified toolbar, as in other apps' About panes.
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Buscar actualizaciones…") {
                    Task { await UpdateChecker.checkAndReport() }
                }
            }
        }
    }

    private var lastCheckDescription: String {
        guard lastUpdateCheck > 0 else { return "Nunca" }
        let date = Date(timeIntervalSince1970: lastUpdateCheck)
        return date.formatted(.relative(presentation: .named))
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
        // Line symbols, as System Settings uses since macOS 26.
        case .general: "gearshape"
        case .appearance: "paintpalette"
        case .keys: "keyboard"
        case .engines: "doc.richtext"
        case .about: "info.circle"
        }
    }

    /// Glyph colors: neutral ones adapt to Light and Dark Mode, as General's gear does in System Settings.
    var color: Color {
        switch self {
        case .general: .primary
        case .appearance: .primary
        case .keys: .primary
        case .engines: .orange
        case .about: .blue
        }
    }

    /// The System Settings pane whose icon this one borrows.
    private var systemPaneBundle: String? {
        switch self {
        case .general: "GeneralSettings"
        case .appearance: "Appearance"
        case .keys: "KeyboardSettings"
        case .engines: "LoginItems" // "Login Items & Extensions": the add-ons that do the work
        case .about: nil
        }
    }

    var systemIcon: NSImage? {
        guard let name = systemPaneBundle else { return nil }
        let path = "/System/Library/ExtensionKit/Extensions/\(name).appex"
        guard FileManager.default.fileExists(atPath: path) else { return nil }
        return NSWorkspace.shared.icon(forFile: path)
    }

    var summary: String {
        switch self {
        case .general: "Inicio de sesión y qué pasa al terminar cada conversión."
        case .appearance: "El material, la opacidad y el color de la rueda."
        case .keys: "Qué rueda abre cada tecla mientras arrastras archivos."
        case .engines: "Con qué motor convierte Gota cada tipo de documento."
        case .about: "Versión, actualizaciones y licencias."
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
enum AppIcon {
    /// Gota's icon as macOS draws it for the app bundle, so it follows the user's icon style (default,
    /// dark, clear or tinted). `NSApp.applicationIconImage` answered the generic placeholder for this
    /// menu bar app, so the About pane showed an empty grid.
    static var image: NSImage {
        NSWorkspace.shared.icon(forFile: Bundle.main.bundlePath)
    }
}

/// The pane's icon. Where System Settings has a matching pane, it's that pane's real icon, read from
/// macOS at run time (never copied into Gota), so it is identical and follows every macOS redesign.
/// About shows Gota's own icon, as Apple's apps do.
private struct SettingsIcon: View {
    let pane: SettingsPane
    var size: CGFloat = 22

    var body: some View {
        if pane == .about {
            Image(nsImage: AppIcon.image).resizable().frame(width: size, height: size)
        } else if let icon = pane.systemIcon {
            Image(nsImage: icon).resizable().frame(width: size, height: size)
        } else {
            DrawnSettingsIcon(pane: pane, size: size)
        }
    }
}

/// Fallback when a macOS version doesn't have the matching System Settings pane.
private struct DrawnSettingsIcon: View {
    let pane: SettingsPane
    let size: CGFloat
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: size * 0.27, style: .continuous)
        Image(systemName: pane.symbol)
            .font(.system(size: size * 0.55, weight: .medium))
            .symbolRenderingMode(pane == .appearance ? .multicolor : .monochrome)
            .foregroundStyle(pane.color)
            .frame(width: size, height: size)
            .background(tile, in: shape)
            .overlay(shape.strokeBorder(.separator, lineWidth: 0.5))
            .shadow(color: .black.opacity(colorScheme == .dark ? 0.4 : 0.12), radius: size * 0.04, y: size * 0.02)
    }

    private var tile: LinearGradient {
        let colors: [Color] = colorScheme == .dark
            ? [Color(white: 0.22), Color(white: 0.13)]
            : [.white, Color(white: 0.93)]
        return LinearGradient(colors: colors, startPoint: .top, endPoint: .bottom)
    }
}

/// The card at the top of each pane: big icon, title and what the pane is for, as in System Settings.
private struct PaneHeader: View {
    let pane: SettingsPane

    var body: some View {
        VStack(spacing: 8) {
            SettingsIcon(pane: pane, size: 60)
            Text(pane.title).font(.title.bold())
            Text(pane.summary)
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
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
