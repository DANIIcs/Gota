import AppKit
import UserNotifications

/// System notifications ("Listo: PNG · foto.heic").
enum Notifier {
    static func requestAuthorization() {
        UNUserNotificationCenter.current().delegate = ForegroundPresenter.shared
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    static let urlKey = "url"

    /// - Parameter url: opened in the browser when the user clicks the notification.
    static func post(title: String, body: String, opening url: URL? = nil) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        if let url {
            content.userInfo = [urlKey: url.absoluteString]
        }
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }
}

/// macOS hides notifications from the frontmost app unless a delegate asks for them.
/// Gota becomes frontmost with Settings open or after AirDrop, and results must still show.
private final class ForegroundPresenter: NSObject, UNUserNotificationCenterDelegate {
    static let shared = ForegroundPresenter()

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .sound]
    }

    /// Clicking a notification that carries a link (e.g. "instala LibreOffice") opens it.
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        guard let link = response.notification.request.content.userInfo[Notifier.urlKey] as? String,
              let url = URL(string: link), url.scheme == "https" else { return }
        await MainActor.run { _ = NSWorkspace.shared.open(url) }
    }
}
