import AppKit

/// Forwards window-close events so AppState can clear its cached window references.
final class WindowCloser: NSObject, NSWindowDelegate {
    private let onClose: (NSWindow) -> Void
    init(onClose: @escaping (NSWindow) -> Void) { self.onClose = onClose }

    func windowWillClose(_ notification: Notification) {
        if let window = notification.object as? NSWindow {
            onClose(window)
        }
    }
}
