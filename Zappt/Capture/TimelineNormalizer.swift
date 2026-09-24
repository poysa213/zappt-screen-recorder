import Foundation
import CoreMedia

/// Pure value type that turns raw capture presentation timestamps into a
/// normalized timeline that starts at zero and skips paused intervals, so the
/// written file has no gap across pause/resume.
///
/// Extracted from `VideoWriter` specifically so this timing logic can be unit
/// tested without any capture hardware.
struct TimelineNormalizer {
    private(set) var hasStarted = false
    private var startPTS: CMTime = .invalid
    private var lastRawPTS: CMTime = .invalid
    private var pausedDuration: CMTime = .zero
    private var paused = false
    private var resumePending = false

    /// Whether the timeline is currently paused (frames should be dropped).
    var isPaused: Bool { paused }

    /// Total time skipped so far due to pauses.
    var accumulatedPause: CMTime { pausedDuration }

    mutating func pause() { paused = true }

    mutating func resume() {
        guard paused else { return }
        paused = false
        resumePending = true
    }

    /// Returns the normalized PTS for a frame at raw time `raw`, or `nil` if the
    /// frame should be dropped (paused, or it would land before zero).
    mutating func normalize(_ raw: CMTime) -> CMTime? {
        guard raw.isValid else { return nil }

        if !hasStarted {
            startPTS = raw
            lastRawPTS = raw
            hasStarted = true
        }

        if resumePending {
            // Absorb the wall-clock gap that elapsed while paused.
            if lastRawPTS.isValid {
                pausedDuration = pausedDuration + (raw - lastRawPTS)
            }
            resumePending = false
        }

        if paused { return nil }

        lastRawPTS = raw
        let normalized = raw - startPTS - pausedDuration
        return normalized >= .zero ? normalized : nil
    }
}
