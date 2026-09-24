import SwiftUI

/// App preferences.
struct SettingsView: View {
    @ObservedObject var appState: AppState
    @ObservedObject var settings: AppSettings

    init(appState: AppState) {
        self.appState = appState
        self.settings = appState.settings
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text("Settings")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(Theme.textPrimary)

                saveSection
                videoSection
                captureSection
                deviceSection
            }
            .padding(24)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(Theme.background)
        .frame(width: 520, height: 560)
    }

    private var saveSection: some View {
        Card {
            VStack(alignment: .leading, spacing: 12) {
                SectionLabel(text: "Save Location")
                HStack {
                    Text(settings.saveFolder.path)
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.textSecondary)
                        .lineLimit(1).truncationMode(.middle)
                    Spacer()
                    Button("Change…") { chooseFolder() }
                    Button("Reveal") {
                        NSWorkspace.shared.activateFileViewerSelecting([settings.saveFolder])
                    }
                }
            }
        }
    }

    private var videoSection: some View {
        Card {
            VStack(alignment: .leading, spacing: 14) {
                SectionLabel(text: "Video")
                HStack {
                    Text("Quality").frame(width: 120, alignment: .leading)
                    Picker("", selection: $settings.videoQuality) {
                        ForEach(VideoQuality.allCases) { Text($0.title).tag($0) }
                    }.labelsHidden().pickerStyle(.segmented)
                }
                HStack {
                    Text("Frame rate").frame(width: 120, alignment: .leading)
                    Picker("", selection: $settings.frameRate) {
                        ForEach(FrameRate.allCases) { Text($0.title).tag($0) }
                    }.labelsHidden().pickerStyle(.segmented)
                }
            }
            .font(.system(size: 13))
            .foregroundStyle(Theme.textPrimary)
        }
    }

    private var captureSection: some View {
        Card {
            VStack(alignment: .leading, spacing: 12) {
                SectionLabel(text: "Capture")
                Toggle("Show cursor", isOn: $settings.showCursor)
                Toggle("Highlight clicks", isOn: $settings.highlightClicks)
                Toggle("Show 3-2-1 countdown", isOn: $settings.countdownEnabled)
            }
            .toggleStyle(.switch)
            .tint(Theme.accent)
            .font(.system(size: 13))
            .foregroundStyle(Theme.textPrimary)
        }
    }

    private var deviceSection: some View {
        Card {
            VStack(alignment: .leading, spacing: 12) {
                SectionLabel(text: "Default Devices")
                HStack {
                    Text("Camera").frame(width: 120, alignment: .leading)
                    Picker("", selection: cameraBinding) {
                        Text("None").tag(nil as String?)
                        ForEach(appState.camera.devices, id: \.uniqueID) {
                            Text($0.localizedName).tag($0.uniqueID as String?)
                        }
                    }.labelsHidden()
                }
                HStack {
                    Text("Microphone").frame(width: 120, alignment: .leading)
                    Picker("", selection: micBinding) {
                        Text("None").tag(nil as String?)
                        ForEach(appState.audio.devices, id: \.uniqueID) {
                            Text($0.localizedName).tag($0.uniqueID as String?)
                        }
                    }.labelsHidden()
                }
            }
            .font(.system(size: 13))
            .foregroundStyle(Theme.textPrimary)
        }
    }

    private var cameraBinding: Binding<String?> {
        Binding(get: { settings.defaultCameraID },
                set: { settings.defaultCameraID = $0; appState.camera.selectedDeviceID = $0 })
    }
    private var micBinding: Binding<String?> {
        Binding(get: { settings.defaultMicID },
                set: { settings.defaultMicID = $0; appState.audio.selectedDeviceID = $0 })
    }

    private func chooseFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.directoryURL = settings.saveFolder
        if panel.runModal() == .OK, let url = panel.url {
            settings.saveFolder = url
            settings.ensureSaveFolderExists()
            appState.library.refresh()
        }
    }
}
