import AppKit
import SwiftUI

/// Forces light appearance app-wide and shows onboarding on first launch.
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, ObservableObject {
    let appState = AppState()

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Light mode only, everywhere.
        NSApp.appearance = NSAppearance(named: .aqua)
        NSApp.setActivationPolicy(.regular)

        appState.settings.ensureSaveFolderExists()
        appState.showOnboardingIfNeeded()
    }

    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool { true }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        // Keep running as a menu-bar app after windows close.
        false
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        // Finalize any in-progress recording before quitting so we never leave a
        // corrupt or zero-byte file behind.
        guard appState.isRecording else { return .terminateNow }
        Task { @MainActor in
            await appState.finalizeForTermination()
            NSApp.reply(toApplicationShouldTerminate: true)
        }
        return .terminateLater
    }
}
