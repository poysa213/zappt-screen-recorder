import Foundation
import AVFoundation
import AppKit
import Combine

/// Manages the live camera preview via AVCaptureSession. The preview layer is
/// shown in the floating bubble, which is captured naturally by the screen recorder.
final class CameraManager: ObservableObject {
    @Published private(set) var devices: [AVCaptureDevice] = []
    @Published private(set) var isRunning = false
    @Published var selectedDeviceID: String? {
        didSet {
            if oldValue != selectedDeviceID { switchDevice() }
        }
    }

    let session = AVCaptureSession()
    private var currentInput: AVCaptureDeviceInput?
    private let sessionQueue = DispatchQueue(label: "com.zappt.camera.session")
    private var observersInstalled = false

    init() {
        session.sessionPreset = .high
        refreshDevices()
        installObservers()
    }

    func refreshDevices() {
        let discovery = AVCaptureDevice.DiscoverySession(
            deviceTypes: [.builtInWideAngleCamera, .external, .continuityCamera, .deskViewCamera],
            mediaType: .video,
            position: .unspecified)
        devices = discovery.devices
        if selectedDeviceID == nil {
            selectedDeviceID = AppSettings.shared.defaultCameraID ?? devices.first?.uniqueID
        }
    }

    func start() {
        guard AVCaptureDevice.authorizationStatus(for: .video) == .authorized else { return }
        let wantedID = selectedDeviceID
        let snapshot = devices
        sessionQueue.async { [weak self] in
            guard let self else { return }
            self.configureInputIfNeeded(wantedID: wantedID, devices: snapshot)
            if !self.session.isRunning { self.session.startRunning() }
            let running = self.session.isRunning
            DispatchQueue.main.async { self.isRunning = running }
        }
    }

    func stop() {
        sessionQueue.async { [weak self] in
            guard let self else { return }
            if self.session.isRunning { self.session.stopRunning() }
            DispatchQueue.main.async { self.isRunning = false }
        }
    }

    // MARK: - Input configuration (always on sessionQueue)

    private func configureInputIfNeeded(wantedID: String?, devices: [AVCaptureDevice]) {
        // Already have the right device? Nothing to do.
        if let current = currentInput, current.device.uniqueID == wantedID { return }
        let device = devices.first(where: { $0.uniqueID == wantedID })
            ?? currentInput?.device
            ?? AVCaptureDevice.default(for: .video)
        guard let device else { return }

        session.beginConfiguration()
        if let existing = currentInput {
            session.removeInput(existing)
            currentInput = nil
        }
        do {
            let input = try AVCaptureDeviceInput(device: device)
            if session.canAddInput(input) {
                session.addInput(input)
                currentInput = input
            }
        } catch {
            NSLog("Zappt camera input error: \(error.localizedDescription)")
        }
        session.commitConfiguration()
    }

    private func switchDevice() {
        let wantedID = selectedDeviceID
        let snapshot = devices
        sessionQueue.async { [weak self] in
            guard let self else { return }
            let wasRunning = self.session.isRunning
            self.configureInputIfNeeded(wantedID: wantedID, devices: snapshot)
            if wasRunning && !self.session.isRunning { self.session.startRunning() }
        }
    }

    // MARK: - Recovery

    private func installObservers() {
        guard !observersInstalled else { return }
        observersInstalled = true
        let nc = NotificationCenter.default
        nc.addObserver(self, selector: #selector(handleRuntimeError(_:)),
                       name: .AVCaptureSessionRuntimeError, object: session)
        nc.addObserver(self, selector: #selector(handleInterruptionEnded(_:)),
                       name: .AVCaptureSessionInterruptionEnded, object: session)
    }

    @objc private func handleRuntimeError(_ note: Notification) {
        // Attempt a restart; camera glitches (e.g. Continuity handoff) can stop the session.
        sessionQueue.async { [weak self] in
            guard let self else { return }
            if !self.session.isRunning { self.session.startRunning() }
        }
    }

    @objc private func handleInterruptionEnded(_ note: Notification) {
        sessionQueue.async { [weak self] in
            guard let self else { return }
            if !self.session.isRunning { self.session.startRunning() }
        }
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}
