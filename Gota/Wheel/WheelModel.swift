import AppKit
import Combine

/// State of the wheel shared by the panel, the drop handling and the SwiftUI view.
@MainActor
final class WheelModel: ObservableObject {
    @Published private(set) var mode: WheelMode = .convert
    @Published private(set) var items: [WheelAction] = []
    @Published private(set) var hovered: WheelAction.ID?
    /// Drives the "drop splits into bubbles" animation.
    @Published private(set) var isOpen = false
    /// Fades the whole wheel in and out (mode switches keep it visible).
    @Published private(set) var isVisible = false
    @Published private(set) var files: [URL] = []

    /// Called when the wheel should go away (after a drop or a cancel).
    var onDismiss: (() -> Void)?

    private let runner: JobRunner
    private var reopenTask: Task<Void, Never>?

    init(runner: JobRunner) {
        self.runner = runner
    }

    var hoveredItem: WheelAction? {
        items.first { $0.id == hovered }
    }

    // MARK: - Lifecycle

    func prepare(mode: WheelMode, files: [URL]) {
        self.files = FileKind.convertible(files)
        self.mode = mode
        self.items = Catalog.actions(for: self.files, mode: mode)
        self.hovered = nil
        self.isOpen = false
        self.isVisible = false
        reopenTask?.cancel()
    }

    func open() {
        isVisible = true
        isOpen = true
    }

    func close() {
        reopenTask?.cancel()
        hovered = nil
        isOpen = false
        isVisible = false
    }

    /// Switching keys mid-drag: the bubbles fall back into the drop and burst out again with the new set.
    func setMode(_ newMode: WheelMode) {
        guard newMode != mode else { return }
        isOpen = false
        hovered = nil
        mode = newMode
        items = Catalog.actions(for: files, mode: newMode)
        reopenTask?.cancel()
        reopenTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .milliseconds(70))
            guard !Task.isCancelled else { return }
            self?.isOpen = true
        }
    }

    // MARK: - Drop

    func updateHover(at point: CGPoint, in size: CGSize) {
        let center = CGPoint(x: size.width / 2, y: size.height / 2)
        let newID = WheelLayout.index(at: point, center: center, count: items.count).map { items[$0].id }
        guard newID != hovered else { return }
        hovered = newID
        if newID != nil {
            // A light tick on the trackpad, like native pickers.
            NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .now)
        }
    }

    func clearHover() {
        hovered = nil
    }

    /// Runs the hovered action on the dragged files. Returns false if nothing was selected.
    func performHovered() -> Bool {
        guard let item = hoveredItem, !files.isEmpty else { return false }
        runner.run(item, on: files)
        onDismiss?()
        return true
    }
}
