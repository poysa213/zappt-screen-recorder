import Foundation
import AVFoundation

/// Records just the webcam (and optionally the mic) straight to a file.
/// Used for "camera only" mode, independent of ScreenCaptureKit.
final class CameraOnlyRecorder: NSObject, ObservableObject {
    private let session = AVCaptureSession()
    private let movieOutput = AVCaptureMovieFileOutput()
    private let sessionQueue = DispatchQueue(label: "com.zappt.cameraonly")
    private var finishContinuation: CheckedContinuation<URL?, Never>?
    private var destURL: URL?

    func start(cameraID: String?, micID: String?, url: URL) throws {
        destURL = url
        try? FileManager.default.removeItem(at: url)

        session.beginConfiguration()
        session.sessionPreset = .high

        // Camera input
        let camera = AVCaptureDevice.devices(for: .video).first(where: { $0.uniqueID == cameraID })
            ?? AVCaptureDevice.default(for: .video)
        if let camera {
            let input = try AVCaptureDeviceInput(device: camera)
            if session.canAddInput(input) { session.addInput(input) }
        }

        // Mic input (optional)
        if let micID {
            let mic = AVCaptureDevice.devices(for: .audio).first(where: { $0.uniqueID == micID })
                ?? AVCaptureDevice.default(for: .audio)
            if let mic {
                let input = try AVCaptureDeviceInput(device: mic)
                if session.canAddInput(input) { session.addInput(input) }
            }
        }

        if session.canAddOutput(movieOutput) { session.addOutput(movieOutput) }
        session.commitConfiguration()

        sessionQueue.async { [weak self] in
            guard let self else { return }
            self.session.startRunning()
            self.movieOutput.startRecording(to: url, recordingDelegate: self)
        }
    }

    func pause() {
        sessionQueue.async { [weak self] in
            guard let self, self.movieOutput.isRecording, !self.movieOutput.isRecordingPaused else { return }
            self.movieOutput.pauseRecording()
        }
    }

    func resume() {
        sessionQueue.async { [weak self] in
            guard let self, self.movieOutput.isRecordingPaused else { return }
            self.movieOutput.resumeRecording()
        }
    }

    func stop() async -> URL? {
        await withCheckedContinuation { continuation in
            self.finishContinuation = continuation
            sessionQueue.async { [weak self] in
                self?.movieOutput.stopRecording()
            }
        }
    }
}

extension CameraOnlyRecorder: AVCaptureFileOutputRecordingDelegate {
    func fileOutput(_ output: AVCaptureFileOutput,
                    didFinishRecordingTo outputFileURL: URL,
                    from connections: [AVCaptureConnection],
                    error: Error?) {
        session.stopRunning()
        let result: URL? = (error == nil) ? outputFileURL : nil
        let continuation = finishContinuation
        finishContinuation = nil
        continuation?.resume(returning: result)
    }
}
