import XCTest
import CoreMedia
@testable import Zappt

final class TimelineNormalizerTests: XCTestCase {
    private let ts: CMTimeScale = 600

    private func t(_ value: Int64) -> CMTime { CMTime(value: value, timescale: ts) }

    func testFirstFrameStartsAtZero() {
        var n = TimelineNormalizer()
        let out = n.normalize(t(600))
        XCTAssertEqual(out.map { CMTimeGetSeconds($0) }, 0)
    }

    func testMonotonicIncrease() {
        var n = TimelineNormalizer()
        _ = n.normalize(t(600))
        let out = n.normalize(t(620))
        XCTAssertEqual(CMTimeGetSeconds(out!), 20.0 / 600.0, accuracy: 1e-6)
    }

    func testInvalidTimeIsDropped() {
        var n = TimelineNormalizer()
        XCTAssertNil(n.normalize(.invalid))
    }

    func testFramesDroppedWhilePaused() {
        var n = TimelineNormalizer()
        _ = n.normalize(t(600))
        _ = n.normalize(t(620))
        n.pause()
        XCTAssertTrue(n.isPaused)
        XCTAssertNil(n.normalize(t(700)), "frames during pause must be dropped")
        XCTAssertNil(n.normalize(t(760)))
    }

    func testResumeIsSeamless() {
        var n = TimelineNormalizer()
        _ = n.normalize(t(600))
        let last = n.normalize(t(620))!   // normalized = 20/600
        n.pause()
        _ = n.normalize(t(700))           // dropped
        n.resume()
        // First frame after resume maps to the same normalized time as the last
        // pre-pause frame — no gap in the file.
        let resumed = n.normalize(t(800))!
        XCTAssertEqual(CMTimeGetSeconds(resumed), CMTimeGetSeconds(last), accuracy: 1e-6)

        // Subsequent frames continue advancing from there.
        let next = n.normalize(t(820))!
        XCTAssertEqual(CMTimeGetSeconds(next), CMTimeGetSeconds(last) + 20.0 / 600.0, accuracy: 1e-6)
    }

    func testAccumulatedPauseTracksTotalSkippedTime() {
        var n = TimelineNormalizer()
        _ = n.normalize(t(600))
        _ = n.normalize(t(620))
        n.pause()
        n.resume()
        _ = n.normalize(t(800)) // pause gap = 800 - 620 = 180
        XCTAssertEqual(CMTimeGetSeconds(n.accumulatedPause), 180.0 / 600.0, accuracy: 1e-6)
    }
}
