import AppKit

/// Notices when the user is dragging files (from Finder, the Desktop…) and holds a mode key.
///
/// How it works, without needing Accessibility permission:
/// 1. A global monitor sees every left mouse-down in other apps.
/// 2. While the button stays pressed, a 60 Hz timer watches the system *drag pasteboard*.
///    When a drag starts, the dragging app writes the files there, so its change count moves.
/// 3. If it holds file URLs and a mode key (⇧ ⌥ ⌃) is down, we ask for the wheel at the cursor.
/// 4. When the button is released, the drag is over.
@MainActor
final class DragMonitor {
    var onWheelRequest: ((WheelMode, NSPoint, [URL]) -> Void)?
    var onModeChange: ((WheelMode) -> Void)?
    var onDragEnd: (() -> Void)?

    private let dragPasteboard = NSPasteboard(name: .drag)
    private var mouseDownMonitor: Any?
    private var timer: Timer?
    private var changeCountAtMouseDown = 0
    private var dragFiles: [URL] = []
    private var currentMode: WheelMode?

    func start() {
        guard mouseDownMonitor == nil else { return }
        // Global monitors call back on the main thread.
        mouseDownMonitor = NSEvent.addGlobalMonitorForEvents(matching: .leftMouseDown) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.mouseDown()
            }
        }
    }

    func stop() {
        if let mouseDownMonitor {
            NSEvent.removeMonitor(mouseDownMonitor)
        }
        mouseDownMonitor = nil
        reset()
    }

    // MARK: - Drag tracking

    private func mouseDown() {
        reset()
        changeCountAtMouseDown = dragPasteboard.changeCount
        let timer = Timer(timeInterval: 1.0 / 60.0, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.tick()
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    private func tick() {
        // Button released → the drag (if any) is over.
        guard NSEvent.pressedMouseButtons & 1 != 0 else {
            finish()
            return
        }

        if dragFiles.isEmpty {
            let changeCount = dragPasteboard.changeCount
            guard changeCount != changeCountAtMouseDown else { return } // no drag yet
            dragFiles = Self.fileURLs(in: dragPasteboard)
            if dragFiles.isEmpty {
                // A drag of something else (text, a link…): ignore it until the next click.
                changeCountAtMouseDown = changeCount
                return
            }
        }

        guard let mode = WheelMode.from(NSEvent.modifierFlags), mode != currentMode else { return }
        if currentMode == nil {
            onWheelRequest?(mode, NSEvent.mouseLocation, dragFiles)
        } else {
            onModeChange?(mode)
        }
        currentMode = mode
    }

    private func finish() {
        let wheelWasOpen = currentMode != nil
        reset()
        if wheelWasOpen {
            onDragEnd?()
        }
    }

    private func reset() {
        timer?.invalidate()
        timer = nil
        dragFiles = []
        currentMode = nil
    }

    static func fileURLs(in pasteboard: NSPasteboard) -> [URL] {
        let objects = pasteboard.readObjects(forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true])
        return (objects as? [URL]) ?? []
    }
}
