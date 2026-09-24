import Foundation
import AppKit

/// A recording saved on disk, shown in the Library.
struct Recording: Identifiable, Hashable {
    let url: URL
    var title: String
    let date: Date
    let duration: TimeInterval
    let fileSize: Int64

    var id: URL { url }

    var displayDuration: String {
        let total = Int(duration.rounded())
        let h = total / 3600
        let m = (total % 3600) / 60
        let s = total % 60
        if h > 0 { return String(format: "%d:%02d:%02d", h, m, s) }
        return String(format: "%d:%02d", m, s)
    }

    var displaySize: String {
        ByteCountFormatter.string(fromByteCount: fileSize, countStyle: .file)
    }

    var displayDate: String {
        let df = DateFormatter()
        df.dateStyle = .medium
        df.timeStyle = .short
        return df.string(from: date)
    }

    static func == (lhs: Recording, rhs: Recording) -> Bool { lhs.url == rhs.url }
    func hash(into hasher: inout Hasher) { hasher.combine(url) }
}
