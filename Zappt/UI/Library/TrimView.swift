import SwiftUI
import AVFoundation

/// Simple trim UI with start/end handles that exports a trimmed copy.
struct TrimView: View {
    let recording: Recording
    @ObservedObject var library: LibraryStore
    var onDone: () -> Void

    @State private var duration: Double = 0
    @State private var startTime: Double = 0
    @State private var endTime: Double = 0
    @State private var exporting = false
    @State private var errorMessage: String?

    private let player = AVPlayer()

    var body: some View {
        VStack(spacing: 16) {
            Text("Trim \(recording.title)")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Theme.textPrimary)

            VideoPlayerView(player: player)
                .background(Color.black)
                .frame(width: 520, height: 300)
                .clipShape(RoundedRectangle(cornerRadius: Theme.cornerSmall))

            VStack(spacing: 10) {
                sliderRow(title: "Start", value: $startTime, range: 0...max(duration, 0.1)) {
                    if startTime > endTime { startTime = endTime }
                    seek(to: startTime)
                }
                sliderRow(title: "End", value: $endTime, range: 0...max(duration, 0.1)) {
                    if endTime < startTime { endTime = startTime }
                    seek(to: endTime)
                }
                HStack {
                    Text("Selection: \(format(startTime)) – \(format(endTime))")
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.textSecondary)
                    Spacer()
                    Text("Length: \(format(max(endTime - startTime, 0)))")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Theme.accent)
                }
            }

            if let errorMessage {
                Text(errorMessage).font(.system(size: 12)).foregroundStyle(Theme.recordRed)
            }

            HStack {
                Button("Cancel") { onDone() }
                    .keyboardShortcut(.cancelAction)
                Spacer()
                Button {
                    export()
                } label: {
                    if exporting {
                        ProgressView().controlSize(.small)
                    } else {
                        Text("Export Trimmed Copy").fontWeight(.semibold)
                    }
                }
                .keyboardShortcut(.defaultAction)
                .disabled(exporting || endTime <= startTime)
            }
        }
        .padding(20)
        .frame(width: 560)
        .background(Theme.background)
        .onAppear(perform: load)
    }

    private func sliderRow(title: String, value: Binding<Double>,
                           range: ClosedRange<Double>, onChange: @escaping () -> Void) -> some View {
        HStack(spacing: 10) {
            Text(title).font(.system(size: 12, weight: .medium))
                .foregroundStyle(Theme.textSecondary).frame(width: 40, alignment: .leading)
            Slider(value: value, in: range, onEditingChanged: { editing in
                if !editing { onChange() }
            })
            Text(format(value.wrappedValue)).font(.system(size: 12).monospacedDigit())
                .foregroundStyle(Theme.textSecondary).frame(width: 54, alignment: .trailing)
        }
    }

    private func load() {
        let asset = AVURLAsset(url: recording.url)
        player.replaceCurrentItem(with: AVPlayerItem(url: recording.url))
        Task {
            if let d = try? await asset.load(.duration) {
                let seconds = CMTimeGetSeconds(d)
                await MainActor.run {
                    duration = seconds
                    endTime = seconds
                }
            }
        }
    }

    private func seek(to time: Double) {
        player.seek(to: CMTime(seconds: time, preferredTimescale: 600),
                    toleranceBefore: .zero, toleranceAfter: .zero)
    }

    private func format(_ seconds: Double) -> String {
        let total = Int(seconds.rounded())
        return String(format: "%d:%02d", total / 60, total % 60)
    }

    private func export() {
        exporting = true
        errorMessage = nil
        let asset = AVURLAsset(url: recording.url)
        guard let session = AVAssetExportSession(asset: asset,
                                                 presetName: AVAssetExportPresetHighestQuality) else {
            errorMessage = "Could not create export session."
            exporting = false
            return
        }
        let dest = recording.url.deletingPathExtension().lastPathComponent + " (trimmed)"
        let outputURL = recording.url.deletingLastPathComponent()
            .appendingPathComponent(dest).appendingPathExtension("mp4")
        try? FileManager.default.removeItem(at: outputURL)

        session.outputURL = outputURL
        session.outputFileType = .mp4
        let start = CMTime(seconds: startTime, preferredTimescale: 600)
        let end = CMTime(seconds: endTime, preferredTimescale: 600)
        session.timeRange = CMTimeRange(start: start, end: end)

        session.exportAsynchronously {
            DispatchQueue.main.async {
                exporting = false
                switch session.status {
                case .completed:
                    library.refresh()
                    onDone()
                default:
                    errorMessage = session.error?.localizedDescription ?? "Export failed."
                }
            }
        }
    }
}
