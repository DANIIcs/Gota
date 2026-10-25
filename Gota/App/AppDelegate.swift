import AppKit

/// Wires the global drag monitor to the wheel.
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var dragMonitor: DragMonitor?
    private var wheel: WheelController?

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
    }

    func applicationWillTerminate(_ notification: Notification) {
        dragMonitor?.stop()
    }
}
