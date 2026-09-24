import SwiftUI
import AVFoundation

/// Full preview of a recording with playback and actions.
struct PreviewView: View {
    let recording: Recording
    @ObservedObject var library: LibraryStore
    var onClose: () -> Void

    @State private var player = AVPlayer()
    @State private var showRename = false
    @State private var showTrim = false
    @State private var newName = ""

    var body: some View {
        VStack(spacing: 0) {
            header
            VideoPlayerView(player: player)
                .background(Color.black)
                .frame(minWidth: 560, minHeight: 340)
            actionBar
        }
        .frame(minWidth: 620, minHeight: 480)
        .background(Theme.background)
        .onAppear {
            player.replaceCurrentItem(with: AVPlayerItem(url: recording.url))
            player.play()
        }
        .onDisappear { player.pause() }
        .sheet(isPresented: $showTrim) {
            TrimView(recording: recording, library: library) { showTrim = false }
        }
        .alert("Rename recording", isPresented: $showRename) {
            TextField("Name", text: $newName)
            Button("Cancel", role: .cancel) {}
            Button("Rename") {
                library.rename(recording, to: newName)
                onClose()
            }
        }
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(recording.title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Theme.textPrimary)
                Text("\(recording.displayDuration) · \(recording.displaySize) · \(recording.displayDate)")
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.textSecondary)
            }
            Spacer()
            Button {
                player.pause()
                onClose()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 20))
                    .foregroundStyle(Theme.textTertiary)
            }
            .buttonStyle(.plain)
        }
        .padding(16)
    }

    private var actionBar: some View {
        HStack(spacing: 10) {
            actionButton("pencil", "Rename") {
                newName = recording.title
                showRename = true
            }
            actionButton("scissors", "Trim") { showTrim = true }
            actionButton("folder", "Reveal") { library.revealInFinder(recording) }
            actionButton("doc.on.doc", "Copy") { library.copyToPasteboard(recording) }
            Spacer()
            actionButton("trash", "Delete", tint: Theme.recordRed) {
                player.pause()
                library.moveToTrash(recording)
                onClose()
            }
        }
        .padding(16)
    }

    private func actionButton(_ icon: String, _ title: String,
                              tint: Color = Theme.textPrimary,
                              action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                Text(title)
            }
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(tint)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Theme.card)
            .clipShape(RoundedRectangle(cornerRadius: Theme.cornerSmall, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: Theme.cornerSmall).stroke(Theme.separator, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}
