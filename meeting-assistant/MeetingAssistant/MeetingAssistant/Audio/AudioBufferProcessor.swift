import AVFoundation
import CoreMedia

/// Receives raw CMSampleBuffers from SCStream, resamples to 16 kHz mono,
/// and emits fixed-duration Data chunks suitable for Deepgram streaming.
///
/// Runs as a Swift actor so all state mutations are serialised without locks.
actor AudioBufferProcessor {

    // Chunk size sent to Deepgram — 100 ms of 16 kHz 16-bit mono = 3200 bytes
    private static let chunkFrames: AVAudioFrameCount = 1600   // 100 ms @ 16 kHz

    private let outputFormat = AVAudioFormat(
        commonFormat: .pcmFormatInt16,
        sampleRate: 16_000,
        channels: 1,
        interleaved: true
    )!

    private var converter: AVAudioConverter?
    private var accumulator = Data()
    private var droppedChunks = 0

    // Continuation for the AsyncStream consumer (DeepgramEngine)
    private var continuation: AsyncStream<Data>.Continuation?

    /// Returns an AsyncStream of 16 kHz PCM chunks.
    func makeStream() -> AsyncStream<Data> {
        AsyncStream(bufferPolicy: .bufferingNewest(10)) { [weak self] continuation in
            Task { await self?.setContinuation(continuation) }
        }
    }

    private func setContinuation(_ c: AsyncStream<Data>.Continuation) {
        continuation = c
    }

    /// Called from the SCStream delegate queue for every audio sample buffer.
    /// CMSampleBuffer is released immediately after PCM data is extracted.
    func process(_ sampleBuffer: CMSampleBuffer) {
        guard let inputFormat = inferFormat(from: sampleBuffer) else { return }

        if converter == nil || converter?.inputFormat != inputFormat {
            converter = AVAudioConverter(from: inputFormat, to: outputFormat)
        }
        guard let converter else { return }

        // Extract PCM from CMSampleBuffer
        guard let block = CMSampleBufferGetDataBuffer(sampleBuffer) else { return }
        let length = CMBlockBufferGetDataLength(block)
        var raw = [UInt8](repeating: 0, count: length)
        CMBlockBufferCopyDataBytes(block, atOffset: 0, dataLength: length, destination: &raw)

        // Wrap in AVAudioPCMBuffer
        let frameCount = AVAudioFrameCount(length) / inputFormat.streamDescription.pointee.mBytesPerFrame
        guard let inputBuf = AVAudioPCMBuffer(pcmFormat: inputFormat, frameCapacity: frameCount) else { return }
        inputBuf.frameLength = frameCount
        raw.withUnsafeBytes { ptr in
            inputBuf.audioBufferList.pointee.mBuffers.mData?.copyMemory(from: ptr.baseAddress!, byteCount: length)
        }

        // Convert to 16 kHz mono int16
        let outputFrames = AVAudioFrameCount(Double(frameCount) * outputFormat.sampleRate / inputFormat.sampleRate) + 1
        guard let outputBuf = AVAudioPCMBuffer(pcmFormat: outputFormat, frameCapacity: outputFrames) else { return }

        var error: NSError?
        converter.convert(to: outputBuf, error: &error) { _, status in
            status.pointee = .haveData
            return inputBuf
        }
        guard error == nil, outputBuf.frameLength > 0,
              let int16Ptr = outputBuf.int16ChannelData?[0] else { return }

        let byteCount = Int(outputBuf.frameLength) * 2
        let chunk = Data(bytes: int16Ptr, count: byteCount)
        accumulator.append(chunk)

        // Emit 100 ms chunks
        let chunkBytes = Int(Self.chunkFrames) * 2
        while accumulator.count >= chunkBytes {
            let toSend = accumulator.prefix(chunkBytes)
            accumulator.removeFirst(chunkBytes)
            if continuation?.yield(Data(toSend)) == .dropped {
                droppedChunks += 1
            }
        }
    }

    func droppedChunkCount() -> Int { droppedChunks }

    func stop() {
        continuation?.finish()
        continuation = nil
        accumulator.removeAll()
    }

    // MARK: - Private

    private func inferFormat(from buffer: CMSampleBuffer) -> AVAudioFormat? {
        guard let desc = CMSampleBufferGetFormatDescription(buffer),
              let asbd = CMAudioFormatDescriptionGetStreamBasicDescription(desc) else { return nil }
        return AVAudioFormat(streamDescription: asbd)
    }
}
