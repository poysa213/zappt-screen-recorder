import XCTest
@testable import Zappt

final class ModelsTests: XCTestCase {

    // MARK: - Recording filename

    func testRecordingFileNameFormat() {
        let name = AppSettings.recordingFileName(date: Date(timeIntervalSince1970: 1_700_000_000))
        let pattern = #"^Zappt \d{4}-\d{2}-\d{2} at \d{2}\.\d{2}\.\d{2}\.mp4$"#
        XCTAssertNotNil(name.range(of: pattern, options: .regularExpression),
                        "unexpected filename: \(name)")
    }

    // MARK: - Recording display helpers

    func testDurationUnderAnHour() {
        let r = Recording(url: URL(fileURLWithPath: "/tmp/a.mp4"), title: "a",
                          date: Date(), duration: 65, fileSize: 0)
        XCTAssertEqual(r.displayDuration, "1:05")
    }

    func testDurationOverAnHour() {
        let r = Recording(url: URL(fileURLWithPath: "/tmp/a.mp4"), title: "a",
                          date: Date(), duration: 3661, fileSize: 0)
        XCTAssertEqual(r.displayDuration, "1:01:01")
    }

    func testDurationZero() {
        let r = Recording(url: URL(fileURLWithPath: "/tmp/a.mp4"), title: "a",
                          date: Date(), duration: 0, fileSize: 0)
        XCTAssertEqual(r.displayDuration, "0:00")
    }

    // MARK: - Enums

    func testVideoQualityTargetHeight() {
        XCTAssertEqual(VideoQuality.p720.targetHeight, 720)
        XCTAssertEqual(VideoQuality.p1080.targetHeight, 1080)
        XCTAssertNil(VideoQuality.native.targetHeight)
    }

    func testFrameRateRawValues() {
        XCTAssertEqual(FrameRate.fps30.rawValue, 30)
        XCTAssertEqual(FrameRate.fps60.rawValue, 60)
    }

    func testBubbleSizeDiametersIncrease() {
        XCTAssertLessThan(BubbleSize.small.diameter, BubbleSize.medium.diameter)
        XCTAssertLessThan(BubbleSize.medium.diameter, BubbleSize.large.diameter)
    }

    func testCaptureSourceTypeHasAllCases() {
        XCTAssertEqual(Set(CaptureSourceType.allCases),
                       [.fullScreen, .window, .area, .cameraOnly])
    }
}
