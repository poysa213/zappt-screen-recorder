import Foundation
import AVFoundation
import Combine

/// Captures the microphone via AVCaptureSession, drives a live level meter,
/// and forwards sample buffers to the mixer during recording.
final class AudioManager: NSObject, ObservableObject {
    @Published private(set) var devices: [AVCaptureDevice] = []
    @Published private(set) var level: Float = 0        // 0...1, for the meter
    @Published private(set) var isRunning = false
    @Published var selectedDeviceID: String? {
        didSet {
            if oldValue != selectedDeviceID { reconfigureInput() }
        }
    }

    /// Set during recording to forward mic buffers to the mixer.
    var onSampleBuffer: ((CMSampleBuffer) -> Void)?

    private let session = AVCaptureSession()
    private var currentInput: AVCaptureDeviceInput?
    private let output = AVCaptureAudioDataOutput()
    private let sessionQueue = DispatchQueue(label: "com.zappt.audio.session")
    private let sampleQueue = DispatchQueue(label: "com.zappt.audio.samples")

    override init() {
        super.init()
        refreshDevices()
        output.setSampleBufferDelegate(self, queue: sampleQueue)
        if session.canAddOutput(output) { session.addOutput(output) }
        let nc = NotificationCenter.default
        nc.addObserver(self, selector: #selector(handleRuntimeError(_:)),
                       name: .AVCaptureSessionRuntimeError, object: session)
        nc.addObserver(self, selector: #selector(handleInterruptionEnded(_:)),
                       name: .AVCaptureSessionInterruptionEnded, object: session)
    }

    @objc private func handleRuntimeError(_ note: Notification) {
        // The mic can drop out (unplugged, grabbed by another app). Try to recover.
        sessionQueue.async { [weak self] in
            guard let self, !self.session.isRunning else { return }
            self.session.startRunning()
        }
    }

    @objc private func handleInterruptionEnded(_ note: Notification) {
        sessionQueue.async { [weak self] in
            guard let self, !self.session.isRunning else { return }
            self.session.startRunning()
        }
    }

    deinit { NotificationCenter.default.removeObserver(self) }

    func refreshDevices() {
        let discovery = AVCaptureDevice.DiscoverySession(
            deviceTypes: [.microphone, .external],
            mediaType: .audio,
            position: .unspecified)
        DispatchQueue.main.async {
            self.devices = discovery.devices
            if self.selectedDeviceID == nil {
                self.selectedDeviceID = AppSettings.shared.defaultMicID ?? discovery.devices.first?.uniqueID
            }
        }
    }

    /// Starts the session for live metering and/or recording.
    func start() {
        guard AVCaptureDevice.authorizationStatus(for: .audio) == .authorized else { return }
        if currentInput == nil { reconfigureInput() }
        sessionQueue.async { [weak self] in
            guard let self else { return }
            if !self.session.isRunning { self.session.startRunning() }
            DispatchQueue.main.async { self.isRunning = self.session.isRunning }
        }
    }

    func stop() {
        onSampleBuffer = nil
        sessionQueue.async { [weak self] in
            guard let self else { return }
            if self.session.isRunning { self.session.stopRunning() }
            DispatchQueue.main.async {
                self.isRunning = false
                self.level = 0
            }
        }
    }

    private func reconfigureInput() {
        let id = selectedDeviceID
        let device = devices.first(where: { $0.uniqueID == id })
            ?? AVCaptureDevice.default(for: .audio)
        guard let device else { return }

        sessionQueue.async { [weak self] in
            guard let self else { return }
            self.session.beginConfiguration()
            if let existing = self.currentInput {
                self.session.removeInput(existing)
                self.currentInput = nil
            }
            do {
                let input = try AVCaptureDeviceInput(device: device)
                if self.session.canAddInput(input) {
                    self.session.addInput(input)
                    self.currentInput = input
                }
            } catch {
                NSLog("Zappt mic input error: \(error.localizedDescription)")
            }
            self.session.commitConfiguration()
        }
    }
}

extension AudioManager: AVCaptureAudioDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput,
                       didOutput sampleBuffer: CMSampleBuffer,
                       from connection: AVCaptureConnection) {
        onSampleBuffer?(sampleBuffer)

        let value = AudioSampleUtils.level(from: sampleBuffer)
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            // Smooth the meter a little.
            self.level = max(value, self.level * 0.8)
        }
    }
}
