import Foundation
import AVFoundation
import AppKit
import Combine

enum LibrarySort: String, CaseIterable, Identifiable {
    case dateNewest = "Newest"
    case dateOldest = "Oldest"
    case name = "Name"
    var id: String { rawValue }
}

/// Loads and manages the recordings shown in the Library.
@MainActor
final class LibraryStore: ObservableObject {
    @Published private(set) var recordings: [Recording] = []
    @Published var searchText: String = ""
    @Published var sort: LibrarySort = .dateNewest
    @Published private(set) var thumbnails: [URL: NSImage] = [:]

    private let settings: AppSettings

    init(settings: AppSettings) {
        self.settings = settings
    }

    var filteredRecordings: [Recording] {
        var list = recordings
        if !searchText.isEmpty {
            list = list.filter { $0.title.localizedCaseInsensitiveContains(searchText) }
        }
        switch sort {
        case .dateNewest: list.sort { $0.date > $1.date }
        case .dateOldest: list.sort { $0.date < $1.date }
        case .name: list.sort { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
        }
        return list
    }

    func refresh() {
        let folder = settings.saveFolder
        Task.detached { [weak self] in
            let items = await Self.scan(folder: folder)
            await MainActor.run {
                self?.recordings = items
            }
            await self?.generateMissingThumbnails(items)
        }
    }

    private static func scan(folder: URL) async -> [Recording] {
        let fm = FileManager.default
        guard let urls = try? fm.contentsOfDirectory(
            at: folder,
            includingPropertiesForKeys: [.contentModificationDateKey, .fileSizeKey],
            options: [.skipsHiddenFiles]) else { return [] }

        var results: [Recording] = []
        for url in urls where ["mp4", "mov", "m4v"].contains(url.pathExtension.lowercased()) {
            let values = try? url.resourceValues(forKeys: [.contentModificationDateKey, .fileSizeKey])
            let date = values?.contentModificationDate ?? Date.distantPast
            let size = Int64(values?.fileSize ?? 0)
            let asset = AVURLAsset(url: url)
            let duration: TimeInterval
            if let d = try? await asset.load(.duration) {
                duration = CMTimeGetSeconds(d)
            } else {
                duration = 0
            }
            let title = url.deletingPathExtension().lastPathComponent
            results.append(Recording(url: url, title: title, date: date,
                                     duration: duration, fileSize: size))
        }
        return results
    }

    private func generateMissingThumbnails(_ items: [Recording]) async {
        for item in items where thumbnails[item.url] == nil {
            if let image = await Self.thumbnail(for: item.url) {
                await MainActor.run { self.thumbnails[item.url] = image }
            }
        }
    }

    static func thumbnail(for url: URL) async -> NSImage? {
        let asset = AVURLAsset(url: url)
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: 640, height: 640)
        let time = CMTime(seconds: 1, preferredTimescale: 600)
        return await withCheckedContinuation { continuation in
            generator.generateCGImagesAsynchronously(forTimes: [NSValue(time: time)]) { _, cgImage, _, _, _ in
                if let cgImage {
                    let image = NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
                    continuation.resume(returning: image)
                } else {
                    continuation.resume(returning: nil)
                }
            }
        }
    }

    // MARK: - Actions

    func rename(_ recording: Recording, to newName: String) {
        let trimmed = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let ext = recording.url.pathExtension
        let dest = recording.url.deletingLastPathComponent()
            .appendingPathComponent(trimmed)
            .appendingPathExtension(ext)
        do {
            try FileManager.default.moveItem(at: recording.url, to: dest)
            refresh()
        } catch {
            NSSound.beep()
        }
    }

    func revealInFinder(_ recording: Recording) {
        NSWorkspace.shared.activateFileViewerSelecting([recording.url])
    }

    func copyToPasteboard(_ recording: Recording) {
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.writeObjects([recording.url as NSURL])
    }

    func moveToTrash(_ recording: Recording) {
        try? FileManager.default.trashItem(at: recording.url, resultingItemURL: nil)
        thumbnails[recording.url] = nil
        refresh()
    }
}
