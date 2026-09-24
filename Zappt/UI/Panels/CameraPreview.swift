import SwiftUI
import AVFoundation
import AppKit

/// Hosts an AVCaptureVideoPreviewLayer for the live camera feed.
final class CameraPreviewNSView: NSView {
    private let previewLayer = AVCaptureVideoPreviewLayer()

    init(session: AVCaptureSession) {
        super.init(frame: NSRect(x: 0, y: 0, width: 200, height: 200))
        let hostLayer = CALayer()
        hostLayer.backgroundColor = NSColor.black.cgColor
        layer = hostLayer
        wantsLayer = true
        previewLayer.session = session
        previewLayer.videoGravity = .resizeAspectFill
        previewLayer.frame = bounds
        hostLayer.addSublayer(previewLayer)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func layout() {
        super.layout()
        syncPreviewFrame()
    }

    override func setFrameSize(_ newSize: NSSize) {
        super.setFrameSize(newSize)
        syncPreviewFrame()
    }

    private func syncPreviewFrame() {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        previewLayer.frame = bounds
        CATransaction.commit()
    }

    func setMirrored(_ mirrored: Bool) {
        guard let connection = previewLayer.connection else { return }
        if connection.isVideoMirroringSupported {
            connection.automaticallyAdjustsVideoMirroring = false
            connection.isVideoMirrored = mirrored
        }
    }
}

struct CameraPreview: NSViewRepresentable {
    let session: AVCaptureSession
    var mirrored: Bool

    func makeNSView(context: Context) -> CameraPreviewNSView {
        let view = CameraPreviewNSView(session: session)
        view.setMirrored(mirrored)
        return view
    }

    func updateNSView(_ nsView: CameraPreviewNSView, context: Context) {
        nsView.setMirrored(mirrored)
    }
}
