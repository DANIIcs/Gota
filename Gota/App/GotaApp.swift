import SwiftUI

/// Gota lives in the menu bar. The real work starts in `AppDelegate`, which listens for file drags
/// and opens the Liquid Glass wheel next to the cursor.
@main
struct GotaApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        MenuBarExtra {
            MenuContent()
        } label: {
            Image(systemName: "drop.fill")
        }

        Settings {
            SettingsView()
        }
    }
}
