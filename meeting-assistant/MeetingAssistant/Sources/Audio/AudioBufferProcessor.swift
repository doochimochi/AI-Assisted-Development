import Foundation
@preconcurrency import AVFoundation
import CoreMedia

actor AudioBufferProcessor {
    // Target format for STT APIs: 16kHz mono, linear PCM
    private let targetFormat = AVAudioFormat(
        commonFormat: .pcmFormatInt16,
        sampleRate: 16000,
        channels: 1,
        interleaved: true
    )!

    private var converter: AVAudioConverter?
    private var continuation: AsyncStream<Data>.Continuation?

    // 250ms chunks at 16kHz = 4000 samples per chunk
    // Deepgram handles streaming well with small chunks
    private let chunkFrameCount: AVAudioFrameCount = 4000

    func makeStream() -> AsyncStream<Data> {
        AsyncStream { continuation in
            self.continuation = continuation
        }
    }

    func process(sampleBuffer: CMSampleBuffer) {
        guard let audioBuffer = sampleBuffer.asPCMBuffer() else { return }

        // Set up converter lazily using actual source format
        if converter == nil {
            converter = AVAudioConverter(from: audioBuffer.format, to: targetFormat)
        }
        guard let converter else { return }

        let frameCount = AVAudioFrameCount(
            Double(audioBuffer.frameLength) * targetFormat.sampleRate / audioBuffer.format.sampleRate
        )
        guard let outputBuffer = AVAudioPCMBuffer(pcmFormat: targetFormat, frameCapacity: frameCount) else { return }

        var error: NSError?
        var inputConsumed = false
        converter.convert(to: outputBuffer, error: &error) { _, outStatus in
            if inputConsumed {
                outStatus.pointee = .noDataNow
                return nil
            }
            outStatus.pointee = .haveData
            inputConsumed = true
            return audioBuffer
        }

        if error == nil, let data = outputBuffer.toData() {
            continuation?.yield(data)
        }
    }

    func stop() {
        continuation?.finish()
        continuation = nil
        converter = nil
    }
}

// MARK: - CMSampleBuffer → AVAudioPCMBuffer

private extension CMSampleBuffer {
    func asPCMBuffer() -> AVAudioPCMBuffer? {
        guard let formatDesc = CMSampleBufferGetFormatDescription(self) else { return nil }
        guard let streamDesc = CMAudioFormatDescriptionGetStreamBasicDescription(formatDesc) else { return nil }
        // streamDesc is UnsafePointer<AudioStreamBasicDescription> — pass directly, not .pointee
        guard let format = AVAudioFormat(streamDescription: streamDesc) else { return nil }

        let frameCount = CMSampleBufferGetNumSamples(self)
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(frameCount)) else { return nil }
        buffer.frameLength = AVAudioFrameCount(frameCount)

        guard let blockBuffer = CMSampleBufferGetDataBuffer(self) else { return nil }
        var dataPointer: UnsafeMutablePointer<CChar>?
        var length = 0
        CMBlockBufferGetDataPointer(blockBuffer, atOffset: 0, lengthAtOffsetOut: nil, totalLengthOut: &length, dataPointerOut: &dataPointer)

        if let int16Ptr = buffer.int16ChannelData?.pointee, let src = dataPointer {
            memcpy(int16Ptr, src, length)
        }
        return buffer
    }
}

private extension AVAudioPCMBuffer {
    func toData() -> Data? {
        guard let int16Ptr = int16ChannelData?.pointee else { return nil }
        let byteCount = Int(frameLength) * MemoryLayout<Int16>.size
        return Data(bytes: int16Ptr, count: byteCount)
    }
}
