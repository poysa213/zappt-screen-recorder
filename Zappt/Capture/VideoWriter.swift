import Foundation
import AVFoundation
import CoreMedia

/// Writes H.264 video + AAC audio into an .mp4 using AVAssetWriter.
/// Handles PTS normalization so recordings start at zero and pauses are seamless.
final class VideoWriter {
    private let queue = DispatchQueue(label: "com.zappt.videowriter")

    private var writer: AVAssetWriter?
    private var videoInput: AVAssetWriterInput?
    private var audioInput: AVAssetWriterInput?

    private(set) var isWriting = false
    private var sessionStarted = false
    private(set) var lastErrorMessage: String?

    /// Outcome of finalizing a recording.
    enum FinishOutcome: Equatable {
        case success           // a valid file was written
        case empty             // no frames were ever captured
        case failed(String)    // the writer reported an error
    }

    // Time normalization (pure, unit-tested type)
    private var timeline = TimelineNormalizer()

    let outputURL: URL

    init(outputURL: URL) {
        self.outputURL = outputURL
    }

    // MARK: - Setup

    func start(videoSize: CGSize, fps: Int, hasAudio: Bool) throws {
        try? FileManager.default.removeItem(at: outputURL)

        let writer = try AVAssetWriter(outputURL: outputURL, fileType: .mp4)

        let width = max(2, Int(videoSize.width.rounded()))
        let height = max(2, Int(videoSize.height.rounded()))
        // Even dimensions are required by most encoders.
        let evenWidth = width - (width % 2)
        let evenHeight = height - (height % 2)

        let bitrate = Self.bitrate(width: evenWidth, height: evenHeight, fps: fps)
        let videoSettings: [String: Any] = [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: evenWidth,
            AVVideoHeightKey: evenHeight,
            AVVideoCompressionPropertiesKey: [
                AVVideoAverageBitRateKey: bitrate,
                AVVideoExpectedSourceFrameRateKey: fps,
                AVVideoMaxKeyFrameIntervalKey: fps * 2,
                AVVideoProfileLevelKey: AVVideoProfileLevelH264HighAutoLevel
            ]
        ]
        let videoInput = AVAssetWriterInput(mediaType: .video, outputSettings: videoSettings)
        videoInput.expectsMediaDataInRealTime = true
        guard writer.canAdd(videoInput) else {
            throw NSError(domain: "Zappt", code: 1,
                          userInfo: [NSLocalizedDescriptionKey: "Cannot add video input"])
        }
        writer.add(videoInput)

        var audioInput: AVAssetWriterInput?
        if hasAudio {
            let audioSettings: [String: Any] = [
                AVFormatIDKey: kAudioFormatMPEG4AAC,
                AVNumberOfChannelsKey: 2,
                AVSampleRateKey: 48_000,
                AVEncoderBitRateKey: 128_000
            ]
            let input = AVAssetWriterInput(mediaType: .audio, outputSettings: audioSettings)
            input.expectsMediaDataInRealTime = true
            if writer.canAdd(input) {
                writer.add(input)
                audioInput = input
            }
        }

        guard writer.startWriting() else {
            throw writer.error ?? NSError(domain: "Zappt", code: 2,
                userInfo: [NSLocalizedDescriptionKey: "Failed to start writing"])
        }

        self.writer = writer
        self.videoInput = videoInput
        self.audioInput = audioInput
        self.isWriting = true
    }

    // MARK: - Pause / Resume

    func pause() { queue.async { self.timeline.pause() } }
    func resume() { queue.async { self.timeline.resume() } }

    // MARK: - Append

    func appendVideo(_ sampleBuffer: CMSampleBuffer) {
        queue.async { [weak self] in
            guard let self, self.isWriting,
                  let writer = self.writer, let input = self.videoInput else { return }
            if writer.status == .failed { self.noteFailure(writer); return }
            guard CMSampleBufferGetImageBuffer(sampleBuffer) != nil else { return }

            let raw = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)

            if !self.sessionStarted {
                writer.startSession(atSourceTime: .zero)
                self.sessionStarted = true
            }

            guard let normalized = self.timeline.normalize(raw) else { return }
            guard input.isReadyForMoreMediaData else { return }

            if let retimed = Self.retime(sampleBuffer, to: normalized) {
                input.append(retimed)
            }
        }
    }

    /// Appends an already-normalized audio buffer (timestamps start at zero).
    func appendAudio(_ sampleBuffer: CMSampleBuffer) {
        queue.async { [weak self] in
            guard let self, self.isWriting, self.sessionStarted,
                  let writer = self.writer, let input = self.audioInput else { return }
            if writer.status == .failed { self.noteFailure(writer); return }
            if self.timeline.isPaused { return }
            guard input.isReadyForMoreMediaData else { return }
            input.append(sampleBuffer)
        }
    }

    private func noteFailure(_ writer: AVAssetWriter) {
        if lastErrorMessage == nil {
            lastErrorMessage = writer.error?.localizedDescription ?? "The recording failed while writing."
        }
    }

    // MARK: - Finish

    func finish() async -> FinishOutcome {
        await withCheckedContinuation { continuation in
            queue.async { [weak self] in
                guard let self, let writer = self.writer, self.isWriting else {
                    continuation.resume(returning: .failed("The recorder was not running."))
                    return
                }
                self.isWriting = false

                // No frames were ever captured — cancel to avoid an empty/corrupt file.
                guard self.sessionStarted else {
                    writer.cancelWriting()
                    continuation.resume(returning: .empty)
                    return
                }

                if writer.status == .failed {
                    let message = writer.error?.localizedDescription ?? "The recording failed."
                    writer.cancelWriting()
                    continuation.resume(returning: .failed(self.lastErrorMessage ?? message))
                    return
                }

                self.videoInput?.markAsFinished()
                self.audioInput?.markAsFinished()
                writer.finishWriting {
                    if writer.status == .completed {
                        continuation.resume(returning: .success)
                    } else {
                        let message = writer.error?.localizedDescription ?? "Could not finalize the recording."
                        continuation.resume(returning: .failed(message))
                    }
                }
            }
        }
    }

    // MARK: - Helpers

    private static func retime(_ sampleBuffer: CMSampleBuffer, to pts: CMTime) -> CMSampleBuffer? {
        var count: CMItemCount = 0
        CMSampleBufferGetSampleTimingInfoArray(sampleBuffer, entryCount: 0,
                                               arrayToFill: nil, entriesNeededOut: &count)
        guard count > 0 else { return nil }
        var timing = [CMSampleTimingInfo](repeating: CMSampleTimingInfo(), count: count)
        CMSampleBufferGetSampleTimingInfoArray(sampleBuffer, entryCount: count,
                                               arrayToFill: &timing, entriesNeededOut: &count)
        for i in 0..<count {
            timing[i].presentationTimeStamp = pts
            timing[i].decodeTimeStamp = .invalid
        }
        var out: CMSampleBuffer?
        let status = CMSampleBufferCreateCopyWithNewTiming(
            allocator: kCFAllocatorDefault,
            sampleBuffer: sampleBuffer,
            sampleTimingEntryCount: count,
            sampleTimingArray: &timing,
            sampleBufferOut: &out)
        return status == noErr ? out : nil
    }

    private static func bitrate(width: Int, height: Int, fps: Int) -> Int {
        // ~0.1 bits per pixel per frame, clamped to a sensible range.
        let bpp = 0.1
        let raw = Double(width * height) * Double(fps) * bpp
        return Int(min(max(raw, 2_000_000), 40_000_000))
    }
}
