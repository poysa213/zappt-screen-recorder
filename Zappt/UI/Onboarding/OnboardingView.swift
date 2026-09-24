import SwiftUI

/// First-launch permissions onboarding with live status checks.
struct OnboardingView: View {
    @ObservedObject var appState: AppState
    @ObservedObject var permissions: PermissionsManager
    var onFinish: () -> Void

    @State private var timer = Timer.publish(every: 1.5, on: .main, in: .common).autoconnect()

    init(appState: AppState, onFinish: @escaping () -> Void) {
        self.appState = appState
        self.permissions = appState.permissions
        self.onFinish = onFinish
    }

    var body: some View {
        VStack(spacing: 22) {
            VStack(spacing: 8) {
                Image("ZapptMark")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 56, height: 56)
                Text("Welcome to Zappt")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(Theme.textPrimary)
                Text("Grant a few permissions so Zappt can record your screen, camera, and mic.")
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.textSecondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 380)
            }

            VStack(spacing: 12) {
                permissionRow(
                    icon: "rectangle.inset.filled.and.person.filled",
                    title: "Screen Recording",
                    description: "Record your display, a window, or a selected area.",
                    status: permissions.screenRecording,
                    action: {
                        Task { await permissions.requestScreenRecording() }
                        permissions.openScreenRecordingSettings()
                    })
                permissionRow(
                    icon: "camera.fill",
                    title: "Camera",
                    description: "Show a live camera bubble in your recordings.",
                    status: permissions.camera,
                    action: {
                        Task { await permissions.requestCamera() }
                    })
                permissionRow(
                    icon: "mic.fill",
                    title: "Microphone",
                    description: "Record narration alongside your screen.",
                    status: permissions.microphone,
                    action: {
                        Task { await permissions.requestMicrophone() }
                    })
            }

            Button {
                appState.settings.didOnboard = true
                onFinish()
            } label: {
                Text(permissions.allGranted ? "Get Started" : "Continue Anyway")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(permissions.allGranted ? Theme.accent : Theme.textTertiary)
                    .clipShape(RoundedRectangle(cornerRadius: Theme.corner, style: .continuous))
            }
            .buttonStyle(.plain)
        }
        .padding(28)
        .frame(width: 460)
        .background(Theme.background)
        .onAppear { permissions.refreshAll() }
        .onReceive(timer) { _ in permissions.refreshAll() }
    }

    private func permissionRow(icon: String, title: String, description: String,
                               status: PermissionStatus, action: @escaping () -> Void) -> some View {
        Card {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.system(size: 20))
                    .foregroundStyle(Theme.accent)
                    .frame(width: 30)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Theme.textPrimary)
                    Text(description)
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.textSecondary)
                }
                Spacer()
                if status.isGranted {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 22))
                        .foregroundStyle(.green)
                } else {
                    Button("Enable", action: action)
                        .buttonStyle(.borderedProminent)
                        .tint(Theme.accent)
                }
            }
        }
    }
}
