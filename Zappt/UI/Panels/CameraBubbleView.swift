import SwiftUI

/// The floating camera bubble content: live preview, masked to the chosen shape.
struct CameraBubbleView: View {
    @ObservedObject var appState: AppState

    private var shape: AnyShape {
        switch appState.bubbleShape {
        case .circle: return AnyShape(Circle())
        case .roundedRect: return AnyShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        }
    }

    var body: some View {
        CameraPreview(session: appState.camera.session, mirrored: appState.mirrored)
            .clipShape(shape)
            .overlay(
                shape.stroke(Color.white, lineWidth: 4)
            )
            .overlay(
                shape.stroke(Color.black.opacity(0.08), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.28), radius: 18, x: 0, y: 8)
            .padding(10)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
