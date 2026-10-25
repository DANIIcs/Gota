import AppKit
import SwiftUI

/// A borderless, transparent panel that floats above everything (even full-screen apps)
/// without stealing focus from Finder, so the drag keeps going.
final class WheelPanel: NSPanel {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }

    static func make(content: NSView) -> WheelPanel {
        let panel = WheelPanel(
            contentRect: .zero,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: true
        )
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false // the glass draws its own depth
        panel.level = .popUpMenu
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient, .ignoresCycle]
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        panel.animationBehavior = .none
        panel.contentView = content
        return panel
    }
}

/// Shows and hides the wheel around the cursor.
@MainActor
final class WheelController {
    private let model: WheelModel
    private var panel: WheelPanel?
    private var pendingHide: Task<Void, Never>?
    private var hideDeadline: ContinuousClock.Instant?
    /// Until then the wheel stays centered under the cursor: the user keeps moving while it opens.
    private var settleDeadline: ContinuousClock.Instant?

    init(model: WheelModel) {
        self.model = model
        model.onDismiss = { [weak self] in
            self?.hide()
        }
    }

    func show(mode: WheelMode, at point: NSPoint, files: [URL]) {
        pendingHide?.cancel()
        hideDeadline = nil
        model.prepare(mode: mode, files: files)

        let panel = self.panel ?? makePanel()
        panel.setFrame(frame(centeredOn: point), display: false)
        settleDeadline = .now + WheelLayout.settleDuration
        panel.orderFrontRegardless()

        // Let SwiftUI draw the closed drop first, then animate it open.
        Task { @MainActor [weak self] in
            await Task.yield()
            self?.model.open()
        }
    }

    /// While the wheel is still opening, keep it centered on the cursor; after that it stays put,
    /// so moving towards a bubble reaches it instead of dragging the wheel along.
    func follow(_ point: NSPoint) {
        guard let settleDeadline, ContinuousClock.now < settleDeadline, let panel, panel.isVisible else { return }
        panel.setFrameOrigin(frame(centeredOn: point).origin)
    }

    func switchMode(_ mode: WheelMode) {
        model.setMode(mode)
    }

    /// The mouse was released. If it was over a bubble, the drop already ran the action;
    /// wait a moment so the drop is delivered before the panel disappears.
    func dragEnded() {
        hide(after: .milliseconds(350))
    }

    func hide(after delay: Duration = .zero) {
        // A drop hides right away and the mouse-up right after asks for a later hide:
        // keep whichever comes first, so the wheel never lingers after a drop.
        let deadline = ContinuousClock.now + delay
        if let hideDeadline, hideDeadline <= deadline { return }
        hideDeadline = deadline
        pendingHide?.cancel()
        pendingHide = Task { @MainActor [weak self] in
            try? await Task.sleep(until: deadline, clock: .continuous)
            guard let self, !Task.isCancelled else { return }
            self.model.close()
            // Give the "bubbles back into the drop" animation time to play.
            try? await Task.sleep(for: .milliseconds(260))
            guard !Task.isCancelled else { return }
            self.panel?.orderOut(nil)
            self.hideDeadline = nil
        }
    }

    // MARK: - Helpers

    private func makePanel() -> WheelPanel {
        let host = NSHostingView(rootView: WheelView(model: model))
        host.sizingOptions = []
        let panel = WheelPanel.make(content: host)
        self.panel = panel
        return panel
    }

    /// The wheel's frame, centered on the cursor and kept inside the screen.
    private func frame(centeredOn point: NSPoint) -> NSRect {
        let side = WheelLayout.panelSize
        var rect = NSRect(x: point.x - side / 2, y: point.y - side / 2, width: side, height: side)
        let screen = NSScreen.screens.first { NSMouseInRect(point, $0.frame, false) } ?? NSScreen.main
        if let visible = screen?.visibleFrame {
            rect.origin.x = min(max(rect.minX, visible.minX), visible.maxX - side)
            rect.origin.y = min(max(rect.minY, visible.minY), visible.maxY - side)
        }
        return rect
    }
}
