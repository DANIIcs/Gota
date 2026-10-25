import AppKit
import SwiftUI

/// A borderless, transparent panel that floats above everything (even full-screen apps)
/// without stealing focus from Finder, so the drag keeps going.
///
/// The wheel uses two of them on top of each other:
/// - the *drop* panel, below the drag image: macOS only delivers a drag to windows under that layer;
/// - the *visual* panel, just above the drag image so Finder's file names don't cover the center.
///   It ignores the mouse, so the drag reaches the drop panel beneath it.
final class WheelPanel: NSPanel {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }

    static let dropLevel = NSWindow.Level.popUpMenu
    static let visualLevel = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.draggingWindow)) + 1)

    static func make(content: NSView, level: NSWindow.Level) -> WheelPanel {
        let panel = WheelPanel(
            contentRect: .zero,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: true
        )
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false // the glass draws its own depth
        panel.level = level
        panel.ignoresMouseEvents = level != dropLevel
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
    private var panels: [WheelPanel] = []
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

        if panels.isEmpty { makePanels() }
        let frame = frame(centeredOn: point)
        for panel in panels {
            panel.setFrame(frame, display: false)
            panel.orderFrontRegardless()
        }
        settleDeadline = .now + WheelLayout.settleDuration

        // Let SwiftUI draw the closed drop first, then animate it open.
        Task { @MainActor [weak self] in
            await Task.yield()
            self?.model.open()
        }
    }

    /// While the wheel is still opening, keep it centered on the cursor; after that it stays put,
    /// so moving towards a bubble reaches it instead of dragging the wheel along.
    func follow(_ point: NSPoint) {
        guard let settleDeadline, ContinuousClock.now < settleDeadline, panels.first?.isVisible == true else { return }
        let origin = frame(centeredOn: point).origin
        panels.forEach { $0.setFrameOrigin(origin) }
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
            self.panels.forEach { $0.orderOut(nil) }
            self.hideDeadline = nil
        }
    }

    // MARK: - Helpers

    private func makePanels() {
        let drop = NSHostingView(rootView: WheelDropTarget(model: model))
        let visual = NSHostingView(rootView: WheelView(model: model))
        drop.sizingOptions = []
        visual.sizingOptions = []
        panels = [
            WheelPanel.make(content: drop, level: WheelPanel.dropLevel),
            WheelPanel.make(content: visual, level: WheelPanel.visualLevel),
        ]
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
