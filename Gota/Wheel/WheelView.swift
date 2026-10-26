import SwiftUI
import UniformTypeIdentifiers

/// The wheel itself: a central Liquid Glass drop that splits into one bubble per option.
///
/// All shapes live in one `GlassEffectContainer`, so the system blends them like liquid:
/// closed, the bubbles sit on the center and read as a single drop; opening animates their
/// offsets and the glass pulls apart into separate bubbles. Because this is the system's own
/// material, it follows macOS (light/dark, accessibility settings, future Liquid Glass updates).
struct WheelView: View {
    @ObservedObject var model: WheelModel
    @Namespace private var glassNamespace
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AppStorage(WheelMaterial.key) private var material = WheelMaterial.glass
    @AppStorage(WheelMaterial.opacityKey) private var opacity = 0.0
    @AppStorage(WheelColor.key) private var colorChoice = WheelColor.automatic

    private let size = CGSize(width: WheelLayout.panelSize, height: WheelLayout.panelSize)

    var body: some View {
        // Redraws every frame only for the RGB rainbow; otherwise it's paused and costs nothing.
        TimelineView(.animation(paused: colorChoice != .rgb || reduceMotion)) { context in
            wheel(at: context.date)
        }
        .frame(width: size.width, height: size.height)
    }

    /// The animations live here, inside the timeline's content: attached outside `TimelineView`
    /// they no longer reached the bubbles, and the wheel stopped bursting open.
    private func wheel(at date: Date) -> some View {
        GlassEffectContainer(spacing: 34) {
            ZStack {
                ForEach(Array(model.items.enumerated()), id: \.element.id) { index, item in
                    bubble(for: item, at: index, date: date)
                }
                centerDrop(date: date)
            }
        }
        .scaleEffect(model.isVisible ? 1 : 0.6)
        .opacity(model.isVisible ? 1 : 0)
        .animation(openAnimation, value: model.isOpen)
        .animation(.easeOut(duration: 0.2), value: model.isVisible)
        .animation(.spring(duration: 0.22, bounce: 0.25), value: model.hovered)
    }

    private var openAnimation: Animation {
        reduceMotion ? .easeOut(duration: 0.15) : .spring(duration: 0.45, bounce: 0.32)
    }

    // MARK: - Pieces

    private func bubble(for item: WheelAction, at index: Int, date: Date) -> some View {
        let isHovered = model.hovered == item.id
        let offset = model.isOpen ? WheelLayout.offset(for: index, count: model.items.count) : .zero
        // Grow through the frame, not `scaleEffect`: the glass scaled from its corner while the icon
        // scaled from its center, so a hovered bubble's icon slid up and to the left of its glass.
        let side = WheelLayout.bubbleSize * (isHovered ? 1.18 : 1)
        let tint = colorChoice.fill(phase: Double(index) / Double(max(model.items.count, 1)), at: date)

        return ActionIcon(action: item, size: isHovered ? 38 : 32)
            .foregroundStyle(isHovered || colorChoice.isDark ? Color.white : Color.primary)
            .frame(width: side, height: side)
            .bubbleSurface(material: material, opacity: opacity, tint: tint,
                           strength: isHovered ? WheelColor.hoveredTint : colorChoice.restingTint,
                           rim: colorChoice.hasMetalRim, id: item.id, namespace: glassNamespace)
            .offset(offset)
            .accessibilityLabel(item.title)
    }

    /// What dropping would do: the hovered bubble's icon and name, or the mode and the file count.
    /// The visual panel floats above the drag image (see `WheelPanel`), so Finder's file names don't hide it.
    private func centerDrop(date: Date) -> some View {
        let hovered = model.hoveredItem

        return VStack(spacing: 3) {
            Group {
                if let hovered {
                    ActionIcon(action: hovered, size: 30).id(hovered.id)
                } else {
                    Image(systemName: model.mode.symbol).font(.system(size: 19, weight: .semibold))
                }
            }
            .frame(height: 30)
            .transition(.scale(scale: 0.6).combined(with: .opacity))

            Text(hovered?.title ?? model.mode.title)
                .font(.system(size: 12, weight: .semibold))
                .lineLimit(2)
                .minimumScaleFactor(0.75)
                .multilineTextAlignment(.center)
                .contentTransition(.interpolate)
            Text(subtitle)
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
        }
        .foregroundStyle(colorChoice.isDark ? Color.white : Color.primary)
        .padding(10)
        .frame(width: WheelLayout.centerSize, height: WheelLayout.centerSize)
        .bubbleSurface(material: material, opacity: opacity, tint: colorChoice.fill(at: date),
                       strength: colorChoice.restingTint, rim: colorChoice.hasMetalRim,
                       id: "center", namespace: glassNamespace)
    }

    private var subtitle: String {
        if model.items.isEmpty { return String(localized: "Sin opciones") }
        return String(localized: "\(model.files.count) archivos")
    }
}

extension View {
    /// A bubble: system glass, with Gota's own color and solidity painted on it.
    ///
    /// The color is drawn by Gota instead of `Glass.tint`: macOS mutes glass tints in windows of
    /// apps that aren't active, and during a drag the active app is Finder, never Gota.
    /// Glass is never `.interactive()`: interactive glass leans towards the pointer and slid off its icon.
    /// - Parameters:
    ///   - opacity: 0 is pure glass, 1 a solid bubble.
    ///   - strength: how much of `tint` shows (0 none).
    ///   - rim: a thin light edge, for the metallic look.
    ///   - namespace: lets the container melt bubbles together; nil for previews.
    func bubbleSurface(
        material: WheelMaterial,
        opacity: Double,
        tint: AnyShapeStyle,
        strength: Double,
        rim: Bool = false,
        id: String,
        namespace: Namespace.ID?
    ) -> some View {
        background {
            Circle()
                .fill(Color(nsColor: .windowBackgroundColor).opacity(opacity))
                .overlay(Circle().fill(tint).opacity(strength))
                .overlay {
                    if rim {
                        Circle().strokeBorder(
                            LinearGradient(colors: [.white.opacity(0.45), .white.opacity(0.05), .white.opacity(0.2)],
                                           startPoint: .topLeading, endPoint: .bottomTrailing),
                            lineWidth: 1
                        )
                    }
                }
        }
        .glassEffect(material.glass, in: .circle)
        .optionalGlassID(id, in: namespace)
    }

    @ViewBuilder
    fileprivate func optionalGlassID(_ id: String, in namespace: Namespace.ID?) -> some View {
        if let namespace {
            glassEffectID(id, in: namespace)
        } else {
            self
        }
    }
}

/// The part of the wheel that receives the drag, in its own panel under the visual one
/// (see `WheelPanel`). Fully transparent pixels let drops fall through to the window below,
/// which could move the user's file in Finder: an almost invisible disc keeps the whole wheel a target.
struct WheelDropTarget: View {
    @ObservedObject var model: WheelModel

    private let size = CGSize(width: WheelLayout.panelSize, height: WheelLayout.panelSize)

    var body: some View {
        Circle()
            .fill(Color.black.opacity(0.01))
            .frame(width: size.width - 8, height: size.height - 8)
            .frame(width: size.width, height: size.height)
            .contentShape(Circle())
            .onDrop(of: [UTType.fileURL], delegate: WheelDropDelegate(model: model, size: size))
    }
}

/// Turns the pointer position during the drag into the hovered bubble, and the drop into an action.
/// The files themselves were already read from the drag pasteboard when the wheel opened.
struct WheelDropDelegate: DropDelegate {
    let model: WheelModel
    let size: CGSize

    func validateDrop(info: DropInfo) -> Bool {
        true
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        let location = info.location
        let pointsAtBubble = MainActor.assumeIsolated {
            model.updateHover(at: location, in: size)
            return model.hovered != nil
        }
        return DropProposal(operation: pointsAtBubble ? .copy : .forbidden)
    }

    func dropExited(info: DropInfo) {
        MainActor.assumeIsolated {
            model.clearHover()
        }
    }

    func performDrop(info: DropInfo) -> Bool {
        MainActor.assumeIsolated {
            model.performHovered()
        }
    }
}

/// A bubble's picture: macOS's own icon for the format the action creates (the PDF, Word or PNG icon
/// Finder shows), drawn as a small stack when several files become one; an SF Symbol for other actions.
struct ActionIcon: View {
    let action: WheelAction
    let size: CGFloat

    var body: some View {
        if let type = action.output {
            let icon = Image(nsImage: NSWorkspace.shared.icon(for: type))
            if action.combined {
                ZStack {
                    icon.resizable()
                        .frame(width: size * 0.85, height: size * 0.85)
                        .rotationEffect(.degrees(-10))
                        .offset(x: -size * 0.12, y: -size * 0.06)
                        .opacity(0.8)
                    icon.resizable()
                        .frame(width: size * 0.85, height: size * 0.85)
                        .offset(x: size * 0.1, y: size * 0.06)
                }
                .frame(width: size, height: size)
            } else {
                icon.resizable().frame(width: size, height: size)
            }
        } else {
            Image(systemName: action.symbol)
                .font(.system(size: size * 0.62, weight: .semibold))
        }
    }
}
