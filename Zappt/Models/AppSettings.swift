import Foundation
import Combine

/// Persisted user preferences, backed by UserDefaults.
final class AppSettings: ObservableObject {
    static let shared = AppSettings()

    @Published var saveFolder: URL {
        didSet { defaults.set(saveFolder.path, forKey: Keys.saveFolder) }
    }
    @Published var videoQuality: VideoQuality {
        didSet { defaults.set(videoQuality.rawValue, forKey: Keys.videoQuality) }
    }
    @Published var frameRate: FrameRate {
        didSet { defaults.set(frameRate.rawValue, forKey: Keys.frameRate) }
    }
    @Published var showCursor: Bool {
        didSet { defaults.set(showCursor, forKey: Keys.showCursor) }
    }
    @Published var highlightClicks: Bool {
        didSet { defaults.set(highlightClicks, forKey: Keys.highlightClicks) }
    }
    @Published var countdownEnabled: Bool {
        didSet { defaults.set(countdownEnabled, forKey: Keys.countdownEnabled) }
    }
    @Published var defaultCameraID: String? {
        didSet { defaults.set(defaultCameraID, forKey: Keys.defaultCameraID) }
    }
    @Published var defaultMicID: String? {
        didSet { defaults.set(defaultMicID, forKey: Keys.defaultMicID) }
    }

    private let defaults = UserDefaults.standard

    private enum Keys {
        static let saveFolder = "saveFolder"
        static let videoQuality = "videoQuality"
        static let frameRate = "frameRate"
        static let showCursor = "showCursor"
        static let highlightClicks = "highlightClicks"
        static let countdownEnabled = "countdownEnabled"
        static let defaultCameraID = "defaultCameraID"
        static let defaultMicID = "defaultMicID"
        static let didOnboard = "didOnboard"
    }

    private init() {
        let fm = FileManager.default
        let defaultFolder = fm.urls(for: .moviesDirectory, in: .userDomainMask).first!
            .appendingPathComponent("Zappt", isDirectory: true)

        if let path = defaults.string(forKey: Keys.saveFolder) {
            saveFolder = URL(fileURLWithPath: path, isDirectory: true)
        } else {
            saveFolder = defaultFolder
        }
        videoQuality = VideoQuality(rawValue: defaults.string(forKey: Keys.videoQuality) ?? "") ?? .p1080
        frameRate = FrameRate(rawValue: defaults.integer(forKey: Keys.frameRate)) ?? .fps30
        showCursor = defaults.object(forKey: Keys.showCursor) as? Bool ?? true
        highlightClicks = defaults.object(forKey: Keys.highlightClicks) as? Bool ?? false
        countdownEnabled = defaults.object(forKey: Keys.countdownEnabled) as? Bool ?? true
        defaultCameraID = defaults.string(forKey: Keys.defaultCameraID)
        defaultMicID = defaults.string(forKey: Keys.defaultMicID)

        ensureSaveFolderExists()
    }

    var didOnboard: Bool {
        get { defaults.bool(forKey: Keys.didOnboard) }
        set { defaults.set(newValue, forKey: Keys.didOnboard) }
    }

    func ensureSaveFolderExists() {
        try? FileManager.default.createDirectory(at: saveFolder, withIntermediateDirectories: true)
    }

    /// Builds a destination file URL using the Loom-style naming convention.
    func makeRecordingURL(date: Date = Date()) -> URL {
        ensureSaveFolderExists()
        return saveFolder.appendingPathComponent(Self.recordingFileName(date: date))
    }

    /// Pure filename generator (no filesystem side effects) — unit tested.
    static func recordingFileName(date: Date) -> String {
        let df = DateFormatter()
        df.locale = Locale(identifier: "en_US_POSIX")
        df.timeZone = TimeZone.current
        df.dateFormat = "yyyy-MM-dd 'at' HH.mm.ss"
        return "Zappt \(df.string(from: date)).mp4"
    }
}
