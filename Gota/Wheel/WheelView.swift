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

    private let size = CGSize(width: WheelLayout.panelSize, height: WheelLayout.panelSize)

    var body: some View {
        ZStack {
            // Fully transparent pixels let clicks and drops fall through to the window below
            // (that could move the file in Finder!). An almost invisible disc keeps the whole
            // wheel a drop target.
            Circle()
                .fill(Color.black.opacity(0.01))
                .frame(width: size.width - 8, height: size.height - 8)

            GlassEffectContainer(spacing: 34) {
                ZStack {
                    ForEach(Array(model.items.enumerated()), id: \.element.id) { index, item in
                        bubble(for: item, at: index)
                    }
                    centerDrop
                }
            }
            .scaleEffect(model.isVisible ? 1 : 0.6)
            .opacity(model.isVisible ? 1 : 0)

            label
                .offset(y: WheelLayout.labelOffset)
                .opacity(model.isVisible ? 1 : 0)
        }
        .frame(width: size.width, height: size.height)
        .contentShape(Circle())
        .onDrop(of: [UTType.fileURL], delegate: WheelDropDelegate(model: model, size: size))
        .animation(openAnimation, value: model.isOpen)
        .animation(.easeOut(duration: 0.2), value: model.isVisible)
        .animation(.spring(duration: 0.22, bounce: 0.25), value: model.hovered)
    }

    private var openAnimation: Animation {
        reduceMotion ? .easeOut(duration: 0.15) : .spring(duration: 0.45, bounce: 0.32)
    }

    // MARK: - Pieces

    private func bubble(for item: WheelAction, at index: Int) -> some View {
        let isHovered = model.hovered == item.id
        let offset = model.isOpen ? WheelLayout.offset(for: index, count: model.items.count) : .zero

        return Image(systemName: item.symbol)
            .font(.system(size: 20, weight: .semibold))
            .foregroundStyle(isHovered ? Color.white : Color.primary)
            .frame(width: WheelLayout.bubbleSize, height: WheelLayout.bubbleSize)
            .glassEffect(glass(highlighted: isHovered), in: .circle)
            .glassEffectID(item.id, in: glassNamespace)
            .scaleEffect(isHovered ? 1.18 : 1)
            .offset(offset)
            .accessibilityLabel(item.title)
    }

    /// Not `.interactive()`: interactive glass leans towards the pointer, which pulled each bubble's glass
    /// off its icon while hovering. The hover highlight is the tint and the scale instead.
    private func glass(highlighted: Bool) -> Glass {
        highlighted ? Glass.regular.tint(.accentColor) : Glass.regular
    }

    /// Only the mode's icon: the cursor sits on the center, and Finder draws the dragged files' names
    /// (and the count badge) right there, so text in the center would be hidden.
    /// It doesn't copy the hovered bubble's icon: that read as the icon sliding out of its bubble.
    private var centerDrop: some View {
        Image(systemName: model.mode.symbol)
            .font(.system(size: 26, weight: .semibold))
            .contentTransition(.symbolEffect(.replace))
            .frame(width: WheelLayout.centerSize, height: WheelLayout.centerSize)
            .glassEffect(.regular, in: .circle)
            .glassEffectID("center", in: glassNamespace)
    }

    /// What dropping here would do, above the wheel: the one place the drag image never covers.
    /// Outside the container so it doesn't melt into the top bubble.
    private var label: some View {
        HStack(spacing: 6) {
            Text(model.hoveredItem?.title ?? model.mode.title)
                .font(.system(size: 13, weight: .semibold))
            Text(subtitle)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
        }
        .lineLimit(1)
        .padding(.horizontal, 14)
        .padding(.vertical, 6)
        .glassEffect(.regular, in: .capsule)
        .contentTransition(.numericText())
    }

    private var subtitle: String {
        if model.items.isEmpty { return "Sin opciones" }
        return model.files.count == 1 ? "1 archivo" : "\(model.files.count) archivos"
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
