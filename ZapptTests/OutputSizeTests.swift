import XCTest
@testable import Zappt

final class OutputSizeTests: XCTestCase {
    private let hd = CGSize(width: 1920, height: 1080)

    func testNativeUsesSourceTimesScale() {
        let size = ScreenRecorder.computeOutputSize(sourcePoints: hd, scale: 2, quality: .native)
        XCTAssertEqual(size, CGSize(width: 3840, height: 2160))
    }

    func testNativeScaleOne() {
        let size = ScreenRecorder.computeOutputSize(sourcePoints: hd, scale: 1, quality: .native)
        XCTAssertEqual(size, hd)
    }

    func test720pKeepsAspectRatio() {
        let size = ScreenRecorder.computeOutputSize(sourcePoints: hd, scale: 2, quality: .p720)
        XCTAssertEqual(size.height, 720)
        XCTAssertEqual(size.width, 1280) // 720 * 16/9
    }

    func test1080pIndependentOfScale() {
        let a = ScreenRecorder.computeOutputSize(sourcePoints: hd, scale: 2, quality: .p1080)
        let b = ScreenRecorder.computeOutputSize(sourcePoints: hd, scale: 1, quality: .p1080)
        XCTAssertEqual(a, b)
        XCTAssertEqual(a, CGSize(width: 1920, height: 1080))
    }

    func testFallbackAspectWhenSourceDegenerate() {
        // Zero-height source must not divide-by-zero; falls back to 16:9.
        let size = ScreenRecorder.computeOutputSize(sourcePoints: CGSize(width: 0, height: 0),
                                                    scale: 1, quality: .p1080)
        XCTAssertEqual(size.height, 1080)
        XCTAssertEqual(size.width, 1920)
    }
}
