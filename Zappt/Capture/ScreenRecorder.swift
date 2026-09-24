import Foundation
import ScreenCaptureKit
import AVFoundation
import AppKit
import Combine

/// Describes what the user chose to capture.
struct CaptureSelection {
    var type: CaptureSourceType
    var display: SCDisplay?
    var window: SCWindow?
    /// For area capture: rect in global Cocoa (bottom-left origin) coordinates.
    var areaRect: CGRect?
}

/// Orchestrates ScreenCaptureKit + microphone + writer for a single recording.
final class ScreenRecorder: NSObject, ObservableObject {
    @Published private(set) var state: RecorderState = .idle
    @Published private(set) var elapsed: TimeInterval = 0
    @Published private(set) var lastRecordingURL: URL?

    private var stream: SCStream?
    private var writer: VideoWriter?
    private let mixer = AudioMixer()
    private weak var audioManager: AudioManager?

    private let videoQueue = DispatchQueue(label: "com.zappt.stream.video")
    private let audioQueue = DispatchQueue(label: "com.zappt.stream.audio")

    private var timer: DispatchSourceTimer?

    // MARK: - Shareable content

    static func fetchShareableContent() async throws -> SCShareableContent {
        try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
    }

    // MARK: - Start

    /// Starts a screen recording. `micSampleSource` supplies mic buffers (already
    /// started) when microphone recording is enabled.
    func start(selection: CaptureSelection,
               systemAudio: Bool,
               microphone: Bool,
               excludedWindowIDs: [CGWindowID],
               settings: AppSettings,
               micSource: AudioManager?) async throws {

        let content = try await Self.fetchShareableContent()
        let filter = try buildFilter(for: selection, content: content, excludedWindowIDs: excludedWindowIDs)

        let scale = displayScale(for: selection)
        let sourcePoints = sourceSize(for: selection)
        let outputSize = Self.computeOutputSize(sourcePoints: sourcePoints,
                                                scale: scale,
                                                quality: settings.videoQuality)

        let config = SCStreamConfiguration()
        config.width = Int(outputSize.width)
        config.height = Int(outputSize.height)
        config.minimumFrameInterval = CMTime(value: 1, timescale: CMTimeScale(settings.frameRate.rawValue))
        config.showsCursor = settings.showCursor
        config.capturesAudio = systemAudio
        config.excludesCurrentProcessAudio = true
        config.queueDepth = 6
        config.pixelFormat = kCVPixelFormatType_32BGRA
        config.colorSpaceName = CGColorSpace.sRGB
        config.sampleRate = 48_000
        config.channelCount = 2

        if selection.type == .area, let rect = localSourceRect(for: selection) {
            config.sourceRect = rect
        }

        // Configure the writer.
        let url = settings.makeRecordingURL()
        let writer = VideoWriter(outputURL: url)
        try writer.start(videoSize: outputSize,
                         fps: settings.frameRate.rawValue,
                         hasAudio: systemAudio || microphone)
        self.writer = writer

        // Configure the mixer and wire it to the writer.
        mixer.configure(system: systemAudio, mic: microphone)
        mixer.onMixedBuffer = { [weak writer] buffer in
            writer?.appendAudio(buffer)
        }

        // Wire microphone buffers into the mixer.
        if microphone, let micSource {
            audioManager = micSource
            micSource.onSampleBuffer = { [weak self] buffer in
                self?.mixer.appendMic(buffer)
            }
        }

        // Build and start the stream. If anything fails, tear down the
        // half-initialized writer and delete the empty file we just created.
        do {
            let stream = SCStream(filter: filter, configuration: config, delegate: self)
            try stream.addStreamOutput(self, type: .screen, sampleHandlerQueue: videoQueue)
            if systemAudio {
                try stream.addStreamOutput(self, type: .audio, sampleHandlerQueue: audioQueue)
            }
            self.stream = stream
            try await stream.startCapture()
        } catch {
            await abortStartup(url: url)
            throw error
        }

        await MainActor.run {
            self.elapsed = 0
            self.state = .recording
            self.startTimer()
        }
    }

    /// Tears down state after a failed start so no orphaned file remains.
    private func abortStartup(url: URL) async {
        audioManager?.onSampleBuffer = nil
        mixer.onMixedBuffer = nil
        if let stream { try? await stream.stopCapture() }
        stream = nil
        _ = await writer?.finish()
        writer = nil
        try? FileManager.default.removeItem(at: url)
    }

    // MARK: - Pause / Resume / Stop

    func pause() {
        guard case .recording = state else { return }
        writer?.pause()
        DispatchQueue.main.async {
            self.state = .paused
            self.stopTimer()
        }
    }

    func resume() {
        guard case .paused = state else { return }
        writer?.resume()
        DispatchQueue.main.async {
            self.state = .recording
            self.startTimer()
        }
    }

    /// Stops recording, finalizes the file, and returns its URL on success.
    @discardableResult
    func stop() async -> URL? {
        await MainActor.run {
            self.state = .stopping
            self.stopTimer()
        }

        audioManager?.onSampleBuffer = nil
        mixer.onMixedBuffer = nil

        if let stream {
            try? await stream.stopCapture()
        }
        stream = nil

        let outcome = await writer?.finish() ?? .failed("The recorder was not running.")
        let url = writer?.outputURL
        writer = nil

        switch outcome {
        case .success:
            await MainActor.run {
                if let url { self.lastRecordingURL = url }
                self.state = .idle
            }
            return url
        case .empty:
            if let url { try? FileManager.default.removeItem(at: url) }
            await MainActor.run {
                self.state = .error("No frames were captured, so nothing was saved. Check screen-recording permission and try again.")
            }
            return nil
        case .failed(let message):
            if let url { try? FileManager.default.removeItem(at: url) }
            await MainActor.run { self.state = .error(message) }
            return nil
        }
    }

    // MARK: - Timer

    private func startTimer() {
        stopTimer()
        let t = DispatchSource.makeTimerSource(queue: .main)
        t.schedule(deadline: .now() + 0.1, repeating: 0.1)
        t.setEventHandler { [weak self] in
            guard let self, case .recording = self.state else { return }
            self.elapsed += 0.1
        }
        t.resume()
        timer = t
    }

    private func stopTimer() {
        timer?.cancel()
        timer = nil
    }

    // MARK: - Filter building

    private func buildFilter(for selection: CaptureSelection,
                             content: SCShareableContent,
                             excludedWindowIDs: [CGWindowID]) throws -> SCContentFilter {
        switch selection.type {
        case .window:
            guard let window = selection.window
                ?? content.windows.first(where: { $0.windowID == selection.window?.windowID }) else {
                throw recorderError("No window selected.")
            }
            return SCContentFilter(desktopIndependentWindow: window)

        case .fullScreen, .area:
            guard let display = selection.display ?? content.displays.first else {
                throw recorderError("No display available.")
            }
            let excludeSet = Set(excludedWindowIDs)
            let excluded = content.windows.filter { excludeSet.contains($0.windowID) }
            return SCContentFilter(display: display, excludingWindows: excluded)

        case .cameraOnly:
            // Camera-only is handled without ScreenCaptureKit; should not reach here.
            guard let display = content.displays.first else {
                throw recorderError("No display available.")
            }
            return SCContentFilter(display: display, excludingWindows: [])
        }
    }

    // MARK: - Sizing helpers

    private func sourceSize(for selection: CaptureSelection) -> CGSize {
        switch selection.type {
        case .window:
            if let w = selection.window { return w.frame.size }
        case .area:
            if let r = selection.areaRect { return r.size }
        default:
            break
        }
        if let d = selection.display { return CGSize(width: d.width, height: d.height) }
        return CGSize(width: 1920, height: 1080)
    }

    private func displayScale(for selection: CaptureSelection) -> CGFloat {
        guard let display = selection.display else { return 2 }
        if let screen = NSScreen.screens.first(where: {
            ($0.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID) == display.displayID
        }) {
            return screen.backingScaleFactor
        }
        return 2
    }

    /// Converts the global area rect to a display-local, top-left-origin rect (points).
    private func localSourceRect(for selection: CaptureSelection) -> CGRect? {
        guard let rect = selection.areaRect, let display = selection.display,
              let screen = NSScreen.screens.first(where: {
                  ($0.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID) == display.displayID
              }) else { return nil }
        let frame = screen.frame
        let localX = rect.minX - frame.minX
        let localY = frame.maxY - rect.maxY // flip to top-left origin
        return CGRect(x: localX, y: localY, width: rect.width, height: rect.height)
    }

    static func computeOutputSize(sourcePoints: CGSize, scale: CGFloat, quality: VideoQuality) -> CGSize {
        let aspect = sourcePoints.width > 0 ? sourcePoints.width / sourcePoints.height : 16.0 / 9.0
        if let target = quality.targetHeight {
            let h = CGFloat(target)
            return CGSize(width: (h * aspect).rounded(), height: h)
        }
        return CGSize(width: (sourcePoints.width * scale).rounded(),
                      height: (sourcePoints.height * scale).rounded())
    }

    private func recorderError(_ message: String) -> NSError {
        NSError(domain: "Zappt", code: 100, userInfo: [NSLocalizedDescriptionKey: message])
    }
}

// MARK: - Stream output & delegate

extension ScreenRecorder: SCStreamOutput, SCStreamDelegate {
    func stream(_ stream: SCStream,
                didOutputSampleBuffer sampleBuffer: CMSampleBuffer,
                of type: SCStreamOutputType) {
        switch type {
        case .screen:
            guard isFrameComplete(sampleBuffer) else { return }
            writer?.appendVideo(sampleBuffer)
        case .audio:
            mixer.appendSystem(sampleBuffer)
        default:
            break
        }
    }

    func stream(_ stream: SCStream, didStopWithError error: Error) {
        DispatchQueue.main.async {
            self.state = .error(error.localizedDescription)
            self.stopTimer()
        }
    }

    private func isFrameComplete(_ sampleBuffer: CMSampleBuffer) -> Bool {
        guard let attachments = CMSampleBufferGetSampleAttachmentsArray(sampleBuffer, createIfNecessary: false)
                as? [[SCStreamFrameInfo: Any]],
              let first = attachments.first,
              let rawStatus = first[.status] as? Int,
              let status = SCFrameStatus(rawValue: rawStatus) else {
            return true
        }
        return status == .complete
    }
}
