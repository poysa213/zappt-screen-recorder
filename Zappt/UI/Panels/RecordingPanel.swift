import SwiftUI
import ScreenCaptureKit

/// The compact recording panel shown from the menu bar.
struct RecordingPanel: View {
    @ObservedObject var appState: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            header
            sourceSection
            if appState.sourceType == .fullScreen { displayPicker }
            if appState.sourceType == .window { windowPicker }
            audioSection
            cameraSection
            RecordButton(isRecording: appState.isRecording) {
                appState.toggleRecording()
            }
            footer
        }
        .padding(18)
        .frame(width: 340)
        .background(Theme.background)
        .onAppear {
            appState.refreshSources()
            if appState.micOn { appState.audio.start() }
            appState.startCameraPreview()
        }
        .onChange(of: appState.sourceType) { _, newValue in
            // Camera-only frees the camera for direct recording; other modes preview it.
            if newValue == .cameraOnly {
                appState.stopCameraPreview()
            } else {
                appState.startCameraPreview()
            }
        }
    }

    // MARK: - Sections

    private var header: some View {
        HStack {
            HStack(spacing: 8) {
                Image("ZapptMark")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 22, height: 22)
                Text("Zappt")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(Theme.textPrimary)
            }
            Spacer()
            Button {
                appState.refreshSources()
            } label: {
                Image(systemName: "arrow.clockwise")
                    .foregroundStyle(Theme.textSecondary)
            }
            .buttonStyle(.plain)
            .help("Refresh sources")
        }
    }

    private var sourceSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionLabel(text: "Capture")
            HStack(spacing: 8) {
                ForEach(CaptureSourceType.allCases) { type in
                    SourceButton(type: type, isSelected: appState.sourceType == type) {
                        withAnimation(Theme.spring) { appState.sourceType = type }
                    }
                }
            }
        }
    }

    private var displayPicker: some View {
        VStack(alignment: .leading, spacing: 6) {
            SectionLabel(text: "Display")
            Picker("", selection: displaySelection) {
                ForEach(appState.availableDisplays, id: \.displayID) { display in
                    Text("Display \(display.displayID) · \(display.width)×\(display.height)")
                        .tag(display.displayID as CGDirectDisplayID?)
                }
            }
            .labelsHidden()
            .pickerStyle(.menu)
        }
    }

    private var displaySelection: Binding<CGDirectDisplayID?> {
        Binding(
            get: { appState.selectedDisplay?.displayID },
            set: { id in appState.selectedDisplay = appState.availableDisplays.first(where: { $0.displayID == id }) }
        )
    }

    private var windowPicker: some View {
        VStack(alignment: .leading, spacing: 6) {
            SectionLabel(text: "Window")
            Picker("", selection: windowSelection) {
                Text("Choose a window…").tag(nil as CGWindowID?)
                ForEach(appState.availableWindows, id: \.windowID) { window in
                    Text(windowLabel(window)).tag(window.windowID as CGWindowID?)
                }
            }
            .labelsHidden()
            .pickerStyle(.menu)
        }
    }

    private var windowSelection: Binding<CGWindowID?> {
        Binding(
            get: { appState.selectedWindow?.windowID },
            set: { id in appState.selectedWindow = appState.availableWindows.first(where: { $0.windowID == id }) }
        )
    }

    private func windowLabel(_ window: SCWindow) -> String {
        let app = window.owningApplication?.applicationName ?? "App"
        let title = window.title ?? ""
        return title.isEmpty ? app : "\(app) — \(title)"
    }

    private var audioSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionLabel(text: "Audio")
            PillToggle(icon: "speaker.wave.2.fill", title: "System Audio", isOn: $appState.systemAudioOn)
            PillToggle(icon: "mic.fill", title: "Microphone", isOn: micBinding)
            if appState.micOn {
                Picker("", selection: micSelection) {
                    ForEach(appState.audio.devices, id: \.uniqueID) { device in
                        Text(device.localizedName).tag(device.uniqueID as String?)
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)
                LevelMeter(level: appState.audio.level)
            }
        }
    }

    private var micBinding: Binding<Bool> {
        Binding(
            get: { appState.micOn },
            set: { on in
                appState.micOn = on
                if on { appState.audio.start() } else { appState.audio.stop() }
            }
        )
    }

    private var micSelection: Binding<String?> {
        Binding(
            get: { appState.audio.selectedDeviceID },
            set: { appState.audio.selectedDeviceID = $0; appState.settings.defaultMicID = $0 }
        )
    }

    private var cameraSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionLabel(text: "Camera")
            PillToggle(icon: "video.fill", title: "Camera Bubble", isOn: cameraBinding)
            if appState.cameraOn {
                Picker("", selection: cameraSelection) {
                    ForEach(appState.camera.devices, id: \.uniqueID) { device in
                        Text(device.localizedName).tag(device.uniqueID as String?)
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)

                // Size
                HStack(spacing: 8) {
                    rowLabel("Size")
                    ForEach(BubbleSize.allCases) { size in
                        segButton(size.title, selected: appState.bubbleSize == size) {
                            appState.bubbleSize = size
                        }
                    }
                    Spacer(minLength: 0)
                }

                // Shape
                HStack(spacing: 8) {
                    rowLabel("Shape")
                    ForEach(BubbleShape.allCases) { shape in
                        shapePill(shape)
                    }
                    Spacer(minLength: 0)
                }

                // Mirror
                PillToggle(icon: "arrow.left.and.right", title: "Mirror camera",
                           isOn: $appState.mirrored)
            }
        }
    }

    private func rowLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(Theme.textSecondary)
            .frame(width: 46, alignment: .leading)
    }

    private func shapePill(_ shape: BubbleShape) -> some View {
        let selected = appState.bubbleShape == shape
        return Button {
            appState.bubbleShape = shape
        } label: {
            HStack(spacing: 5) {
                Image(systemName: shape.symbol)
                    .font(.system(size: 11, weight: .semibold))
                Text(shape.title)
                    .font(.system(size: 12, weight: .medium))
            }
            .padding(.horizontal, 11)
            .padding(.vertical, 5)
            .foregroundStyle(selected ? .white : Theme.textSecondary)
            .background(selected ? Theme.accent : Theme.background)
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    private var cameraBinding: Binding<Bool> {
        Binding(
            get: { appState.cameraOn },
            set: { on in
                appState.cameraOn = on
                if on {
                    appState.startCameraPreview()
                } else {
                    appState.stopCameraPreview()
                }
            }
        )
    }

    private var cameraSelection: Binding<String?> {
        Binding(
            get: { appState.camera.selectedDeviceID },
            set: { appState.camera.selectedDeviceID = $0; appState.settings.defaultCameraID = $0 }
        )
    }

    private func segButton(_ title: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 12, weight: .medium))
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .foregroundStyle(selected ? .white : Theme.textSecondary)
                .background(selected ? Theme.accent : Theme.background)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    private var footer: some View {
        HStack {
            Button {
                appState.openLibrary()
            } label: {
                Label("Library", systemImage: "square.grid.2x2")
                    .font(.system(size: 12, weight: .medium))
            }
            .buttonStyle(.plain)
            .foregroundStyle(Theme.accent)

            Spacer()

            Button {
                appState.openSettings()
            } label: {
                Label("Settings", systemImage: "gearshape")
                    .font(.system(size: 12, weight: .medium))
            }
            .buttonStyle(.plain)
            .foregroundStyle(Theme.textSecondary)
        }
    }
}
