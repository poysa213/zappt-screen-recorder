import SwiftUI

/// The floating control bar shown during recording. Excluded from capture.
struct ControlBarView: View {
    @ObservedObject var appState: AppState

    private var timeString: String {
        let total = Int(appState.elapsed)
        let m = total / 60
        let s = total % 60
        return String(format: "%02d:%02d", m, s)
    }

    var body: some View {
        HStack(spacing: 14) {
            // Recording indicator + timer
            HStack(spacing: 8) {
                Circle()
                    .fill(appState.isPaused ? Theme.textTertiary : Theme.recordRed)
                    .frame(width: 10, height: 10)
                    .opacity(appState.isPaused ? 1 : pulse ? 0.35 : 1)
                    .animation(appState.isPaused ? nil : .easeInOut(duration: 0.7).repeatForever(autoreverses: true), value: pulse)
                Text(timeString)
                    .font(.system(.title3, design: .rounded).monospacedDigit().weight(.semibold))
                    .foregroundStyle(Theme.textPrimary)
            }
            .padding(.horizontal, 6)

            Divider().frame(height: 24)

            controlButton(appState.isPaused ? "play.fill" : "pause.fill",
                          label: appState.isPaused ? "Resume" : "Pause") {
                appState.togglePause()
            }
            controlButton("arrow.counterclockwise", label: "Restart") {
                appState.restartRecording()
            }
            controlButton("trash", label: "Delete", tint: Theme.recordRed) {
                appState.deleteRecording()
            }

            // Stop (primary)
            Button(action: { appState.stopRecording() }) {
                HStack(spacing: 6) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.white)
                        .frame(width: 12, height: 12)
                    Text("Stop")
                        .font(.system(.body, design: .rounded).weight(.semibold))
                        .foregroundStyle(.white)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(Theme.recordRed, in: Capsule())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial, in: Capsule())
        .overlay(Capsule().stroke(Theme.separator, lineWidth: 1))
        .shadow(color: .black.opacity(0.18), radius: 20, y: 8)
        .onAppear { pulse = true }
    }

    @State private var pulse = false

    private func controlButton(_ symbol: String, label: String,
                               tint: Color = Theme.textPrimary,
                               action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: 34, height: 34)
                .background(Color.black.opacity(0.04), in: Circle())
        }
        .buttonStyle(.plain)
        .help(label)
    }
}
