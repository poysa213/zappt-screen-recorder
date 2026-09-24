import Foundation
import AVFoundation
import ScreenCaptureKit
import AppKit
import Combine

enum PermissionStatus {
    case unknown
    case granted
    case denied

    var isGranted: Bool { self == .granted }
}

/// Checks and requests the three permissions Zappt needs: Screen Recording,
/// Camera, and Microphone. Also opens the relevant System Settings panes.
@MainActor
final class PermissionsManager: ObservableObject {
    @Published var screenRecording: PermissionStatus = .unknown
    @Published var camera: PermissionStatus = .unknown
    @Published var microphone: PermissionStatus = .unknown

    var allGranted: Bool {
        screenRecording.isGranted && camera.isGranted && microphone.isGranted
    }

    // MARK: - Refresh

    func refreshAll() {
        refreshCamera()
        refreshMicrophone()
        Task { await refreshScreenRecording() }
    }

    func refreshCamera() {
        camera = Self.mapAV(AVCaptureDevice.authorizationStatus(for: .video))
    }

    func refreshMicrophone() {
        microphone = Self.mapAV(AVCaptureDevice.authorizationStatus(for: .audio))
    }

    func refreshScreenRecording() async {
        // The reliable way to know if we have screen-recording access is to try
        // to enumerate shareable content. It throws if access is not granted.
        do {
            _ = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
            screenRecording = .granted
        } catch {
            // Fall back to CoreGraphics preflight for a best-effort answer.
            screenRecording = CGPreflightScreenCaptureAccess() ? .granted : .denied
        }
    }

    private static func mapAV(_ status: AVAuthorizationStatus) -> PermissionStatus {
        switch status {
        case .authorized: return .granted
        case .notDetermined: return .unknown
        default: return .denied
        }
    }

    // MARK: - Request

    func requestCamera() async {
        _ = await AVCaptureDevice.requestAccess(for: .video)
        refreshCamera()
    }

    func requestMicrophone() async {
        _ = await AVCaptureDevice.requestAccess(for: .audio)
        refreshMicrophone()
    }

    /// Triggers the system screen-recording prompt (first time) and refreshes.
    func requestScreenRecording() async {
        CGRequestScreenCaptureAccess()
        await refreshScreenRecording()
    }

    // MARK: - Open System Settings

    func openScreenRecordingSettings() {
        open("x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture")
    }
    func openCameraSettings() {
        open("x-apple.systempreferences:com.apple.preference.security?Privacy_Camera")
    }
    func openMicrophoneSettings() {
        open("x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone")
    }

    private func open(_ urlString: String) {
        if let url = URL(string: urlString) {
            NSWorkspace.shared.open(url)
        }
    }
}
