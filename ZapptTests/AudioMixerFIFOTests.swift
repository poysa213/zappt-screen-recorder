import XCTest
@testable import Zappt

final class AudioMixerFIFOTests: XCTestCase {
    func testTakeReturnsRequestedSamples() {
        var fifo = Int16FIFO()
        fifo.append([1, 2, 3, 4])
        XCTAssertEqual(fifo.count, 4)
        XCTAssertEqual(fifo.take(2), [1, 2])
        XCTAssertEqual(fifo.count, 2)
    }

    func testTakePadsWithSilenceWhenShort() {
        var fifo = Int16FIFO()
        fifo.append([1, 2])
        XCTAssertEqual(fifo.take(4), [1, 2, 0, 0])
        XCTAssertEqual(fifo.count, 0)
    }

    func testTakeFromEmptyIsAllSilence() {
        var fifo = Int16FIFO()
        XCTAssertEqual(fifo.take(3), [0, 0, 0])
    }

    func testTrimKeepsMostRecentSamples() {
        var fifo = Int16FIFO()
        fifo.append(Array(1...10).map(Int16.init))
        fifo.trim(maxSamples: 4)
        XCTAssertEqual(fifo.count, 4)
        XCTAssertEqual(fifo.take(4), [7, 8, 9, 10])
    }

    func testTrimNoOpWhenUnderLimit() {
        var fifo = Int16FIFO()
        fifo.append([1, 2, 3])
        fifo.trim(maxSamples: 10)
        XCTAssertEqual(fifo.count, 3)
    }
}
