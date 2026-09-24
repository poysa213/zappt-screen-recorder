import AppKit
import SwiftUI
import Combine

/// Small observable model driving the countdown number.
final class CountdownModel: ObservableObject {
    @Published var count: Int = 3
}

private struct CountdownHost: View {
    @ObservedObject var model: CountdownModel
    var body: some View { CountdownView(count: model.count) }
}

/// Creates and manages the floating NSPanels: camera bubble, control bar,
/// countdown, and the area-selection overlay.
@MainActor
final class PanelController {
    private unowned let appState: AppState

    private var bubblePanel: NSPanel?
    private var controlBarPanel: NSPanel?
    private var countdownPanel: NSPanel?
    private var areaController: AreaSelectionController?
    private let countdownModel = CountdownModel()

    private var cancellables = Set<AnyCancellable>()

    init(appState: AppState) {
        self.appState = appState
        // Relayout the bubble live when its size or shape changes.
        appState.$bubbleSize
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.relayoutBubble() }
            .store(in: &cancellables)
        appState.$bubbleShape
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.relayoutBubble() }
            .store(in: &cancellables)
    }

    // MARK: - Camera bubble

    func showBubble() {
        if bubblePanel == nil {
            let panel = makeBorderlessPanel(size: bubbleFrameSize())
            panel.isMovableByWindowBackground = true
            panel.contentView = NSHostingView(rootView: CameraBubbleView(appState: appState))
            positionBubble(panel)
            bubblePanel = panel
        }
        bubblePanel?.orderFrontRegardless()
    }

    func hideBubble() {
        bubblePanel?.orderOut(nil)
        bubblePanel = nil
    }

    private func bubbleFrameSize() -> NSSize {
        let d = appState.bubbleSize.diameter
        let width = appState.bubbleShape == .roundedRect ? d * 1.35 : d
        return NSSize(width: width, height: d)
    }

    private func relayoutBubble() {
        guard let panel = bubblePanel else { return }
        let newSize = bubbleFrameSize()
        var frame = panel.frame
        // Keep the top-left corner anchored while the size changes.
        frame.origin.y -= (newSize.height - frame.height)
        frame.size = newSize
        // Clamp so the bubble stays fully on screen.
        if let screen = panel.screen ?? NSScreen.main {
            let vf = screen.visibleFrame
            frame.origin.x = min(max(frame.origin.x, vf.minX), max(vf.minX, vf.maxX - frame.width))
            frame.origin.y = min(max(frame.origin.y, vf.minY), max(vf.minY, vf.maxY - frame.height))
        }
        panel.setFrame(frame, display: true, animate: true)
    }

    private func positionBubble(_ panel: NSPanel) {
        guard let screen = NSScreen.main else { return }
        let margin: CGFloat = 40
        let size = panel.frame.size
        let origin = NSPoint(x: screen.visibleFrame.maxX - size.width - margin,
                             y: screen.visibleFrame.minY + margin)
        panel.setFrameOrigin(origin)
    }

    // MARK: - Control bar

    func showControlBar() {
        if controlBarPanel == nil {
            let panel = makeBorderlessPanel(size: NSSize(width: 520, height: 64))
            panel.isMovableByWindowBackground = true
            let hosting = NSHostingView(rootView: ControlBarView(appState: appState))
            hosting.frame = NSRect(origin: .zero, size: NSSize(width: 520, height: 64))
            panel.contentView = hosting
            if let screen = NSScreen.main {
                let origin = NSPoint(x: screen.visibleFrame.midX - 260,
                                     y: screen.visibleFrame.minY + 30)
                panel.setFrameOrigin(origin)
            }
            controlBarPanel = panel
        }
        controlBarPanel?.orderFrontRegardless()
    }

    func hideControlBar() {
        controlBarPanel?.orderOut(nil)
        controlBarPanel = nil
    }

    // MARK: - Countdown

    func runCountdown(from start: Int) async {
        countdownModel.count = start
        let panel = makeBorderlessPanel(size: NSSize(width: 260, height: 260))
        panel.contentView = NSHostingView(rootView: CountdownHost(model: countdownModel))
        if let screen = NSScreen.main {
            panel.setFrameOrigin(NSPoint(x: screen.frame.midX - 130,
                                         y: screen.frame.midY - 130))
        }
        panel.orderFrontRegardless()
        countdownPanel = panel

        for n in stride(from: start, through: 1, by: -1) {
            countdownModel.count = n
            try? await Task.sleep(nanoseconds: 900_000_000)
        }
        panel.orderOut(nil)
        countdownPanel = nil
    }

    // MARK: - Area selection

    func presentAreaSelection() async -> AreaSelectionResult? {
        await withCheckedContinuation { continuation in
            let controller = AreaSelectionController()
            self.areaController = controller
            controller.present { [weak self] result in
                self?.areaController = nil
                continuation.resume(returning: result)
            }
        }
    }

    // MARK: - Capture exclusion

    /// All Zappt window IDs except the camera bubble (which should be captured).
    func excludedWindowIDs() -> [CGWindowID] {
        let bubbleNumber = bubblePanel?.windowNumber
        return NSApp.windows.compactMap { window -> CGWindowID? in
            let number = window.windowNumber
            guard number > 0 else { return nil }
            if let bubbleNumber, number == bubbleNumber { return nil }
            // windowNumber is an Int and can exceed UInt32 on modern macOS for
            // off-screen/system helper windows; `exactly:` skips those safely
            // instead of trapping.
            return CGWindowID(exactly: number)
        }
    }

    // MARK: - Factory

    private func makeBorderlessPanel(size: NSSize) -> NSPanel {
        let panel = NSPanel(contentRect: NSRect(origin: .zero, size: size),
                            styleMask: [.borderless, .nonactivatingPanel],
                            backing: .buffered,
                            defer: false)
        panel.isFloatingPanel = true
        panel.level = .floating
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = false
        panel.hidesOnDeactivate = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        return panel
    }
}
