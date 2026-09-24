import Foundation
import SwiftUI
import ScreenCaptureKit
import AVFoundation
import Combine

/// The central coordinator for Zappt. Owns all managers and drives the flow.
@MainActor
final class AppState: ObservableObject {
    // Managers
    let settings = AppSettings.shared
    let permissions = PermissionsManager()
    let camera = CameraManager()
    let audio = AudioManager()
    let recorder = ScreenRecorder()
    let cameraOnlyRecorder = CameraOnlyRecorder()
    let library: LibraryStore
    lazy var panels = PanelController(appState: self)

    // Source selection
    @Published var sourceType: CaptureSourceType = .fullScreen
    @Published var availableDisplays: [SCDisplay] = []
    @Published var availableWindows: [SCWindow] = []
    @Published var selectedDisplay: SCDisplay?
    @Published var selectedWindow: SCWindow?
    @Published var selectedAreaRect: CGRect?

    // Toggles
    @Published var systemAudioOn = true
    @Published var micOn = true
    @Published var cameraOn = true

    // Camera bubble
    @Published var bubbleSize: BubbleSize = .medium
    @Published var bubbleShape: BubbleShape = .circle
    @Published var mirrored = true

    // Recording state (mirrors the active recorder)
    @Published var recordingState: RecorderState = .idle
    @Published var elapsed: TimeInterval = 0

    // Library navigation
    @Published var pendingSelection: Recording?

    // AppKit-managed windows (reliable single instances)
    private var libraryWindow: NSWindow?
    private var settingsWindow: NSWindow?
    private var onboardingWindow: NSWindow?

    private var isCameraOnlyActive = false
    private var isHandlingError = false
    private var cameraOnlyTimer: DispatchSourceTimer?
    private var cancellables = Set<AnyCancellable>()

    init() {
        library = LibraryStore(settings: AppSettings.shared)

        // Mirror the screen recorder's state and elapsed time.
        recorder.$state
            .receive(on: RunLoop.main)
            .sink { [weak self] state in
                guard let self, !self.isCameraOnlyActive else { return }
                if case .error(let message) = state {
                    self.handleRecorderError(message)
                } else {
                    self.recordingState = state
                }
            }
            .store(in: &cancellables)

        recorder.$elapsed
            .receive(on: RunLoop.main)
            .sink { [weak self] value in
                guard let self, !self.isCameraOnlyActive else { return }
                self.elapsed = value
            }
            .store(in: &cancellables)

        library.refresh()
        setupHotKeys()
    }

    var isRecording: Bool {
        switch recordingState {
        case .recording, .paused: return true
        default: return false
        }
    }

    var isPaused: Bool {
        if case .paused = recordingState { return true }
        return false
    }

    // MARK: - Hotkeys

    private func setupHotKeys() {
        HotKeyManager.shared.register(key: .r, modifiers: HotKeyManager.cmdShift) { [weak self] in
            self?.toggleRecording()
        }
        HotKeyManager.shared.register(key: .p, modifiers: HotKeyManager.cmdShift) { [weak self] in
            self?.togglePause()
        }
    }

    // MARK: - Source discovery

    func refreshSources() {
        Task {
            await permissions.refreshScreenRecording()
            camera.refreshDevices()
            audio.refreshDevices()
            guard let content = try? await ScreenRecorder.fetchShareableContent() else { return }
            availableDisplays = content.displays
            availableWindows = content.windows
                .filter { $0.owningApplication?.bundleIdentifier != Bundle.main.bundleIdentifier }
                .filter { ($0.title?.isEmpty == false) && $0.frame.width > 80 && $0.frame.height > 80 }
                .sorted { ($0.owningApplication?.applicationName ?? "") < ($1.owningApplication?.applicationName ?? "") }
            if selectedDisplay == nil { selectedDisplay = content.displays.first }
        }
    }

    // MARK: - Recording flow

    func toggleRecording() {
        if isRecording {
            stopRecording()
        } else {
            beginRecording()
        }
    }

    func togglePause() {
        guard isRecording else { return }
        if isPaused {
            if isCameraOnlyActive { cameraOnlyResume() } else { recorder.resume() }
        } else {
            if isCameraOnlyActive { cameraOnlyPause() } else { recorder.pause() }
        }
    }

    func beginRecording() {
        Task { @MainActor in
            await permissions.refreshScreenRecording()

            if sourceType != .cameraOnly && !permissions.screenRecording.isGranted {
                await permissions.requestScreenRecording()
                if !permissions.screenRecording.isGranted {
                    presentError("Screen Recording permission is required. Enable it in System Settings.")
                    permissions.openScreenRecordingSettings()
                    return
                }
            }

            // Resolve area selection up front.
            var areaRect = selectedAreaRect
            var areaDisplay = selectedDisplay
            if sourceType == .area {
                guard let result = await panels.presentAreaSelection() else { return }
                areaRect = result.rect
                areaDisplay = displayForScreen(result.screen)
                selectedAreaRect = areaRect
            }

            // Start camera preview bubble (for screen modes) or free the camera (camera-only).
            if sourceType == .cameraOnly {
                camera.stop()
                panels.hideBubble()
            } else if cameraOn {
                camera.start()
                panels.showBubble()
            }

            if micOn && sourceType != .cameraOnly {
                audio.start()
            }

            // Countdown.
            if settings.countdownEnabled {
                await panels.runCountdown(from: 3)
            }

            do {
                if sourceType == .cameraOnly {
                    try startCameraOnly()
                } else {
                    let selection = CaptureSelection(
                        type: sourceType,
                        display: areaDisplay ?? selectedDisplay ?? availableDisplays.first,
                        window: selectedWindow,
                        areaRect: areaRect)
                    let excluded = panels.excludedWindowIDs()
                    try await recorder.start(
                        selection: selection,
                        systemAudio: systemAudioOn,
                        microphone: micOn,
                        excludedWindowIDs: excluded,
                        settings: settings,
                        micSource: micOn ? audio : nil)
                }
                panels.showControlBar()
            } catch {
                cleanupAfterStop()
                presentError("Could not start recording: \(error.localizedDescription)")
            }
        }
    }

    func stopRecording() {
        Task { @MainActor in
            panels.hideControlBar()
            let url: URL?
            let wasCameraOnly = isCameraOnlyActive
            if isCameraOnlyActive {
                stopCameraOnlyTimer()
                url = await cameraOnlyRecorder.stop()
                isCameraOnlyActive = false
                recordingState = .idle
            } else {
                // Screen recorder surfaces its own errors via the state sink.
                url = await recorder.stop()
            }
            cleanupAfterStop()

            if let url {
                library.refresh()
                openLibrary(select: url)
            } else if wasCameraOnly {
                presentError("The camera recording could not be saved. Please try again.")
            }
        }
    }

    func restartRecording() {
        Task { @MainActor in
            // Discard the current take and immediately start a fresh one.
            if isCameraOnlyActive {
                stopCameraOnlyTimer()
                _ = await cameraOnlyRecorder.stop()
                isCameraOnlyActive = false
                recordingState = .idle
            } else {
                if let url = await recorder.stop() {
                    try? FileManager.default.removeItem(at: url)
                }
            }
            panels.hideControlBar()
            beginRecording()
        }
    }

    func deleteRecording() {
        Task { @MainActor in
            panels.hideControlBar()
            if isCameraOnlyActive {
                stopCameraOnlyTimer()
                if let url = await cameraOnlyRecorder.stop() {
                    try? FileManager.default.removeItem(at: url)
                }
                isCameraOnlyActive = false
                recordingState = .idle
            } else {
                if let url = await recorder.stop() {
                    try? FileManager.default.removeItem(at: url)
                }
            }
            cleanupAfterStop()
        }
    }

    private func cleanupAfterStop() {
        camera.stop()
        audio.stop()
        panels.hideBubble()
    }

    /// Handles an unexpected recorder failure (device disconnect, stream error,
    /// finalize failure). Tries to salvage a partial file, then surfaces a
    /// friendly message. Guarded so it never re-enters itself.
    private func handleRecorderError(_ message: String) {
        guard !isHandlingError else { return }
        isHandlingError = true
        Task { @MainActor in
            panels.hideControlBar()
            let salvaged = await recorder.stop()   // finalize whatever exists
            cleanupAfterStop()
            recordingState = .idle
            isHandlingError = false
            if let salvaged {
                library.refresh()
                openLibrary(select: salvaged)
                presentError("The recording stopped unexpectedly (\(message)), but your video up to that point was saved.")
            } else {
                presentError(message)
            }
        }
    }

    /// Finalizes any in-progress recording so quitting never leaves a corrupt
    /// or zero-byte file. Called from the app delegate on termination.
    func finalizeForTermination() async {
        guard isRecording else { return }
        if isCameraOnlyActive {
            stopCameraOnlyTimer()
            _ = await cameraOnlyRecorder.stop()
        } else {
            _ = await recorder.stop()
        }
        cleanupAfterStop()
    }

    // MARK: - Live camera bubble preview

    /// Shows the floating camera bubble as a live preview (before recording).
    func startCameraPreview() {
        guard cameraOn,
              sourceType != .cameraOnly,
              AVCaptureDevice.authorizationStatus(for: .video) == .authorized else { return }
        camera.start()
        panels.showBubble()
    }

    func stopCameraPreview() {
        panels.hideBubble()
        camera.stop()
    }

    // MARK: - Camera-only path

    private func startCameraOnly() throws {
        try cameraOnlyRecorder.start(
            cameraID: camera.selectedDeviceID,
            micID: micOn ? audio.selectedDeviceID : nil,
            url: settings.makeRecordingURL())
        isCameraOnlyActive = true
        elapsed = 0
        recordingState = .recording
        startCameraOnlyTimer()
    }

    private func cameraOnlyPause() {
        cameraOnlyRecorder.pause()
        recordingState = .paused
        stopCameraOnlyTimer()
    }

    private func cameraOnlyResume() {
        cameraOnlyRecorder.resume()
        recordingState = .recording
        startCameraOnlyTimer()
    }

    private func startCameraOnlyTimer() {
        stopCameraOnlyTimer()
        let t = DispatchSource.makeTimerSource(queue: .main)
        t.schedule(deadline: .now() + 0.1, repeating: 0.1)
        t.setEventHandler { [weak self] in self?.elapsed += 0.1 }
        t.resume()
        cameraOnlyTimer = t
    }

    private func stopCameraOnlyTimer() {
        cameraOnlyTimer?.cancel()
        cameraOnlyTimer = nil
    }

    // MARK: - Navigation

    func openLibrary(select url: URL? = nil) {
        if let url {
            pendingSelection = library.recordings.first(where: { $0.url == url })
                ?? Recording(url: url, title: url.deletingPathExtension().lastPathComponent,
                             date: Date(), duration: 0, fileSize: 0)
        }
        NSApp.activate(ignoringOtherApps: true)
        if let libraryWindow {
            libraryWindow.makeKeyAndOrderFront(nil)
            return
        }
        let window = makeWindow(title: "Zappt Library",
                                size: NSSize(width: 860, height: 600),
                                view: LibraryView(appState: self))
        window.delegate = windowCloser
        libraryWindow = window
        window.makeKeyAndOrderFront(nil)
    }

    func openSettings() {
        NSApp.activate(ignoringOtherApps: true)
        if let settingsWindow {
            settingsWindow.makeKeyAndOrderFront(nil)
            return
        }
        let window = makeWindow(title: "Settings",
                                size: NSSize(width: 520, height: 560),
                                view: SettingsView(appState: self))
        window.delegate = windowCloser
        settingsWindow = window
        window.makeKeyAndOrderFront(nil)
    }

    func openOnboarding() {
        NSApp.activate(ignoringOtherApps: true)
        if let onboardingWindow {
            onboardingWindow.makeKeyAndOrderFront(nil)
            return
        }
        let window = makeWindow(title: "Welcome to Zappt",
                                size: NSSize(width: 460, height: 600),
                                view: OnboardingView(appState: self) { [weak self] in
                                    self?.onboardingWindow?.close()
                                })
        window.delegate = windowCloser
        onboardingWindow = window
        window.makeKeyAndOrderFront(nil)
    }

    func showOnboardingIfNeeded() {
        if !settings.didOnboard {
            openOnboarding()
        }
    }

    private lazy var windowCloser = WindowCloser { [weak self] window in
        guard let self else { return }
        if window == self.libraryWindow { self.libraryWindow = nil }
        if window == self.settingsWindow { self.settingsWindow = nil }
        if window == self.onboardingWindow { self.onboardingWindow = nil }
    }

    private func makeWindow<V: View>(title: String, size: NSSize, view: V) -> NSWindow {
        let window = NSWindow(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false)
        window.title = title
        window.appearance = NSAppearance(named: .aqua)
        window.isReleasedWhenClosed = false
        window.contentViewController = NSHostingController(rootView: view)
        window.center()
        return window
    }

    // MARK: - Helpers

    private func displayForScreen(_ screen: NSScreen) -> SCDisplay? {
        guard let number = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID
        else { return selectedDisplay }
        return availableDisplays.first(where: { $0.displayID == number }) ?? selectedDisplay
    }

    func presentError(_ message: String) {
        let alert = NSAlert()
        alert.messageText = "Zappt"
        alert.informativeText = message
        alert.alertStyle = .warning
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
}
