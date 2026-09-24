import SwiftUI

/// The main Library window: a grid of recordings with search and sort.
struct LibraryView: View {
    @ObservedObject var appState: AppState
    @ObservedObject var library: LibraryStore
    @State private var selected: Recording?

    private let columns = [GridItem(.adaptive(minimum: 240, maximum: 320), spacing: 18)]

    init(appState: AppState) {
        self.appState = appState
        self.library = appState.library
    }

    var body: some View {
        VStack(spacing: 0) {
            toolbar
            Divider()
            content
        }
        .background(Theme.background)
        .frame(minWidth: 720, minHeight: 500)
        .onAppear {
            library.refresh()
            if let pending = appState.pendingSelection {
                selected = pending
                appState.pendingSelection = nil
            }
        }
        .onChange(of: appState.pendingSelection) { _, newValue in
            if let newValue { selected = newValue }
        }
        .sheet(item: $selected) { rec in
            PreviewView(recording: rec, library: library) { selected = nil }
        }
    }

    private var toolbar: some View {
        HStack(spacing: 12) {
            Text("Library")
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(Theme.textPrimary)
            Spacer()
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass").foregroundStyle(Theme.textTertiary)
                TextField("Search", text: $library.searchText)
                    .textFieldStyle(.plain)
                    .frame(width: 180)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Theme.card)
            .clipShape(Capsule())
            .overlay(Capsule().stroke(Theme.separator, lineWidth: 1))

            Picker("", selection: $library.sort) {
                ForEach(LibrarySort.allCases) { Text($0.rawValue).tag($0) }
            }
            .labelsHidden()
            .frame(width: 110)

            Button {
                library.refresh()
            } label: {
                Image(systemName: "arrow.clockwise")
            }
            .help("Refresh")
        }
        .padding(16)
    }

    @ViewBuilder
    private var content: some View {
        if library.filteredRecordings.isEmpty {
            emptyState
        } else {
            ScrollView {
                LazyVGrid(columns: columns, spacing: 18) {
                    ForEach(library.filteredRecordings) { rec in
                        RecordingCardView(recording: rec,
                                          thumbnail: library.thumbnails[rec.url])
                            .onTapGesture { selected = rec }
                            .contextMenu {
                                Button("Reveal in Finder") { library.revealInFinder(rec) }
                                Button("Copy") { library.copyToPasteboard(rec) }
                                Divider()
                                Button("Move to Trash", role: .destructive) { library.moveToTrash(rec) }
                            }
                    }
                }
                .padding(18)
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "film.stack")
                .font(.system(size: 44))
                .foregroundStyle(Theme.textTertiary)
            Text("No recordings yet")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Theme.textSecondary)
            Text("Your Zappt recordings will appear here.")
                .font(.system(size: 13))
                .foregroundStyle(Theme.textTertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// A single recording tile.
struct RecordingCardView: View {
    let recording: Recording
    let thumbnail: NSImage?
    @State private var hovering = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ZStack {
                Rectangle().fill(Theme.background)
                if let thumbnail {
                    Image(nsImage: thumbnail)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } else {
                    Image(systemName: "film")
                        .font(.system(size: 28))
                        .foregroundStyle(Theme.textTertiary)
                }
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        Text(recording.displayDuration)
                            .font(.system(size: 11, weight: .semibold).monospacedDigit())
                            .foregroundStyle(.white)
                            .padding(.horizontal, 6).padding(.vertical, 3)
                            .background(.black.opacity(0.6), in: Capsule())
                            .padding(8)
                    }
                }
                if hovering {
                    Image(systemName: "play.circle.fill")
                        .font(.system(size: 40))
                        .foregroundStyle(.white.opacity(0.95))
                        .shadow(radius: 6)
                }
            }
            .frame(height: 150)
            .clipped()

            VStack(alignment: .leading, spacing: 3) {
                Text(recording.title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.textPrimary)
                    .lineLimit(1)
                Text("\(recording.displayDate) · \(recording.displaySize)")
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.textSecondary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
        }
        .background(Theme.card)
        .clipShape(RoundedRectangle(cornerRadius: Theme.corner, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: Theme.corner).stroke(Theme.separator, lineWidth: 1))
        .shadow(color: Theme.cardShadow, radius: hovering ? 14 : 8, y: hovering ? 6 : 3)
        .scaleEffect(hovering ? 1.015 : 1)
        .animation(Theme.spring, value: hovering)
        .onHover { hovering = $0 }
    }
}
