import Foundation
import AVFoundation

/// Utilities for moving audio between CoreMedia and AVAudioEngine worlds.
enum AudioSampleUtils {

    /// Wraps a CMSampleBuffer's PCM data in an AVAudioPCMBuffer using its own format.
    static func pcmBuffer(from sampleBuffer: CMSampleBuffer) -> AVAudioPCMBuffer? {
        guard let fmtDesc = CMSampleBufferGetFormatDescription(sampleBuffer),
              let asbdPtr = CMAudioFormatDescriptionGetStreamBasicDescription(fmtDesc) else {
            return nil
        }
        let format = AVAudioFormat(streamDescription: asbdPtr)
        guard let format else { return nil }
        let frames = AVAudioFrameCount(CMSampleBufferGetNumSamples(sampleBuffer))
        guard frames > 0, let pcm = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frames) else {
            return nil
        }
        pcm.frameLength = frames
        let status = CMSampleBufferCopyPCMDataIntoAudioBufferList(
            sampleBuffer, at: 0, frameCount: Int32(frames), into: pcm.mutableAudioBufferList)
        guard status == noErr else { return nil }
        return pcm
    }

    /// Builds a CMSampleBuffer from an interleaved PCM buffer with the given PTS.
    static func sampleBuffer(from pcm: AVAudioPCMBuffer, pts: CMTime) -> CMSampleBuffer? {
        let format = pcm.format
        var timing = CMSampleTimingInfo(
            duration: CMTime(value: 1, timescale: CMTimeScale(format.sampleRate)),
            presentationTimeStamp: pts,
            decodeTimeStamp: .invalid)
        var sampleBuffer: CMSampleBuffer?
        let status = CMSampleBufferCreate(
            allocator: kCFAllocatorDefault,
            dataBuffer: nil,
            dataReady: false,
            makeDataReadyCallback: nil,
            refcon: nil,
            formatDescription: format.formatDescription,
            sampleCount: CMItemCount(pcm.frameLength),
            sampleTimingEntryCount: 1,
            sampleTimingArray: &timing,
            sampleSizeEntryCount: 0,
            sampleSizeArray: nil,
            sampleBufferOut: &sampleBuffer)
        guard status == noErr, let sampleBuffer else { return nil }
        let attachStatus = CMSampleBufferSetDataBufferFromAudioBufferList(
            sampleBuffer,
            blockBufferAllocator: kCFAllocatorDefault,
            blockBufferMemoryAllocator: kCFAllocatorDefault,
            flags: 0,
            bufferList: pcm.audioBufferList)
        guard attachStatus == noErr else { return nil }
        return sampleBuffer
    }

    /// Computes a normalized (0...1) loudness value for a metering display.
    static func level(from sampleBuffer: CMSampleBuffer) -> Float {
        guard let pcm = pcmBuffer(from: sampleBuffer) else { return 0 }
        let frames = Int(pcm.frameLength)
        guard frames > 0 else { return 0 }
        let channels = Int(pcm.format.channelCount)
        var sumSquares: Float = 0
        var count = 0

        if pcm.format.commonFormat == .pcmFormatInt16, let data = pcm.int16ChannelData {
            let interleaved = pcm.format.isInterleaved
            if interleaved {
                let ptr = data[0]
                for i in 0..<(frames * channels) {
                    let v = Float(ptr[i]) / 32768.0
                    sumSquares += v * v; count += 1
                }
            } else {
                for c in 0..<channels {
                    let ptr = data[c]
                    for i in 0..<frames {
                        let v = Float(ptr[i]) / 32768.0
                        sumSquares += v * v; count += 1
                    }
                }
            }
        } else if let data = pcm.floatChannelData {
            let interleaved = pcm.format.isInterleaved
            if interleaved {
                let ptr = data[0]
                for i in 0..<(frames * channels) {
                    let v = ptr[i]; sumSquares += v * v; count += 1
                }
            } else {
                for c in 0..<channels {
                    let ptr = data[c]
                    for i in 0..<frames {
                        let v = ptr[i]; sumSquares += v * v; count += 1
                    }
                }
            }
        }

        guard count > 0 else { return 0 }
        let rms = sqrt(sumSquares / Float(count))
        // Map RMS to a friendly meter curve.
        let db = 20 * log10(max(rms, 0.000_001))
        let normalized = (db + 60) / 60 // -60 dB .. 0 dB -> 0..1
        return min(max(normalized, 0), 1)
    }
}

/// A simple FIFO of interleaved Int16 samples. Internal (not private) so it can
/// be unit tested via `@testable import`.
struct Int16FIFO {
    private var storage: [Int16] = []
    var count: Int { storage.count }

    mutating func append(_ samples: [Int16]) { storage.append(contentsOf: samples) }

    /// Removes and returns up to `n` samples, padding with silence if short.
    mutating func take(_ n: Int) -> [Int16] {
        if storage.count >= n {
            let chunk = Array(storage[0..<n])
            storage.removeFirst(n)
            return chunk
        } else {
            var chunk = storage
            storage.removeAll(keepingCapacity: true)
            chunk.append(contentsOf: repeatElement(0, count: n - chunk.count))
            return chunk
        }
    }

    /// Prevents unbounded growth if a source runs ahead.
    mutating func trim(maxSamples: Int) {
        if storage.count > maxSamples {
            storage.removeFirst(storage.count - maxSamples)
        }
    }
}

/// Mixes optional system audio and optional microphone audio into a single
/// contiguous interleaved-Int16 stream, emitting mixed CMSampleBuffers whose
/// timestamps run continuously from zero (so pauses leave no gap).
final class AudioMixer {
    /// Called on the mixer's internal queue with each mixed buffer.
    var onMixedBuffer: ((CMSampleBuffer) -> Void)?

    let outputFormat: AVAudioFormat
    private let queue = DispatchQueue(label: "com.zappt.audiomixer")

    private var systemEnabled = false
    private var micEnabled = false
    private var masterIsSystem = true

    private var secondaryFIFO = Int16FIFO()
    private var outputFrameCount: Int64 = 0

    private var systemConverter: AVAudioConverter?
    private var systemInputFormat: AVAudioFormat?
    private var micConverter: AVAudioConverter?
    private var micInputFormat: AVAudioFormat?

    init(sampleRate: Double = 48_000, channels: AVAudioChannelCount = 2) {
        outputFormat = AVAudioFormat(commonFormat: .pcmFormatInt16,
                                     sampleRate: sampleRate,
                                     channels: channels,
                                     interleaved: true)!
    }

    func configure(system: Bool, mic: Bool) {
        queue.sync {
            systemEnabled = system
            micEnabled = mic
            masterIsSystem = system // if both or system-only, system drives the clock
            secondaryFIFO = Int16FIFO()
            outputFrameCount = 0
        }
    }

    var hasAudio: Bool { systemEnabled || micEnabled }

    func appendSystem(_ sampleBuffer: CMSampleBuffer) {
        guard systemEnabled else { return }
        queue.async { [weak self] in self?.handle(sampleBuffer, isSystem: true) }
    }

    func appendMic(_ sampleBuffer: CMSampleBuffer) {
        guard micEnabled else { return }
        queue.async { [weak self] in self?.handle(sampleBuffer, isSystem: false) }
    }

    // MARK: - Internal

    private func handle(_ sampleBuffer: CMSampleBuffer, isSystem: Bool) {
        guard let samples = convertToOutputInt16(sampleBuffer, isSystem: isSystem) else { return }
        let isMaster = (isSystem == masterIsSystem) || (masterIsSystem && !micEnabled) || (!masterIsSystem && !systemEnabled)

        if isMaster {
            emitMixed(masterSamples: samples)
        } else {
            secondaryFIFO.append(samples)
            secondaryFIFO.trim(maxSamples: Int(outputFormat.sampleRate) * Int(outputFormat.channelCount)) // ~1s
        }
    }

    private func emitMixed(masterSamples: [Int16]) {
        let frames = masterSamples.count / Int(outputFormat.channelCount)
        guard frames > 0 else { return }

        var mixed = masterSamples
        // Mix in the secondary source only when both are active.
        if systemEnabled && micEnabled {
            let secondary = secondaryFIFO.take(masterSamples.count)
            for i in 0..<mixed.count {
                let sum = Int32(mixed[i]) + Int32(secondary[i])
                mixed[i] = Int16(max(Int32(Int16.min), min(Int32(Int16.max), sum)))
            }
        }

        guard let pcm = AVAudioPCMBuffer(pcmFormat: outputFormat,
                                         frameCapacity: AVAudioFrameCount(frames)) else { return }
        pcm.frameLength = AVAudioFrameCount(frames)
        if let dst = pcm.int16ChannelData?[0] {
            mixed.withUnsafeBufferPointer { src in
                dst.update(from: src.baseAddress!, count: mixed.count)
            }
        }

        let pts = CMTime(value: outputFrameCount, timescale: CMTimeScale(outputFormat.sampleRate))
        outputFrameCount += Int64(frames)
        if let sb = AudioSampleUtils.sampleBuffer(from: pcm, pts: pts) {
            onMixedBuffer?(sb)
        }
    }

    /// Converts an incoming buffer to interleaved Int16 at the output rate.
    private func convertToOutputInt16(_ sampleBuffer: CMSampleBuffer, isSystem: Bool) -> [Int16]? {
        guard let input = AudioSampleUtils.pcmBuffer(from: sampleBuffer) else { return nil }

        let converter: AVAudioConverter
        if isSystem {
            if systemConverter == nil || systemInputFormat != input.format {
                systemConverter = AVAudioConverter(from: input.format, to: outputFormat)
                systemInputFormat = input.format
            }
            guard let c = systemConverter else { return nil }
            converter = c
        } else {
            if micConverter == nil || micInputFormat != input.format {
                micConverter = AVAudioConverter(from: input.format, to: outputFormat)
                micInputFormat = input.format
            }
            guard let c = micConverter else { return nil }
            converter = c
        }

        let ratio = outputFormat.sampleRate / input.format.sampleRate
        let capacity = AVAudioFrameCount(Double(input.frameLength) * ratio + 1024)
        guard let output = AVAudioPCMBuffer(pcmFormat: outputFormat, frameCapacity: capacity) else {
            return nil
        }

        var fed = false
        var error: NSError?
        let status = converter.convert(to: output, error: &error) { _, outStatus in
            if fed {
                outStatus.pointee = .noDataNow
                return nil
            }
            fed = true
            outStatus.pointee = .haveData
            return input
        }
        guard status != .error, output.frameLength > 0, let ptr = output.int16ChannelData?[0] else {
            return nil
        }
        let total = Int(output.frameLength) * Int(outputFormat.channelCount)
        return Array(UnsafeBufferPointer(start: ptr, count: total))
    }
}
