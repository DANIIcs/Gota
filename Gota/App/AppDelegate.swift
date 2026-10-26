import AppKit

/// Wires the global drag monitor to the wheel.
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var dragMonitor: DragMonitor?
    private var wheel: WheelController?
    private var updateTimer: Timer?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let wheel = WheelController(model: WheelModel(runner: JobRunner.shared))
        let monitor = DragMonitor()

        monitor.onWheelRequest = { mode, point, files in
            wheel.show(mode: mode, at: point, files: files)
        }
        monitor.onModeChange = { mode in
            wheel.switchMode(mode)
        }
        monitor.onMove = { point in
            wheel.follow(point)
        }
        monitor.onDragEnd = {
            wheel.dragEnded()
        }
        monitor.start()

        self.wheel = wheel
        self.dragMonitor = monitor
        Notifier.requestAuthorization()
        scheduleUpdateChecks()
    }

    func applicationWillTerminate(_ notification: Notification) {
        dragMonitor?.stop()
    }

    /// Gota stays open for weeks in the menu bar, so besides launch it looks every few hours whether
    /// a daily check is due. Does nothing unless the user turned automatic checks on.
    private func scheduleUpdateChecks() {
        Task { await UpdateChecker.checkInBackgroundIfDue() }
        updateTimer = Timer.scheduledTimer(withTimeInterval: 6 * 60 * 60, repeats: true) { _ in
            Task { @MainActor in await UpdateChecker.checkInBackgroundIfDue() }
        }
    }
}
