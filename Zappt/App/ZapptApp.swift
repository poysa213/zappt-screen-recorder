import SwiftUI

@main
struct ZapptApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        MenuBarExtra {
            RecordingPanel(appState: appDelegate.appState)
                .preferredColorScheme(.light)
        } label: {
            Image("MenuBarIcon")
                .renderingMode(.template)
        }
        .menuBarExtraStyle(.window)
    }
}
