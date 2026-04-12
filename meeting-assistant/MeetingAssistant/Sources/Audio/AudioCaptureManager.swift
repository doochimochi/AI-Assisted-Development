import Foundation
import ScreenCaptureKit
import CoreMedia

@MainActor
final class AudioCaptureManager: NSObject, ObservableObject {
    @Published var isCapturing = false
    @Published var audioLevel: Float = 0.0  // 0.0–1.0 RMS for level meter

    private var stream: SCStream?
    private let bufferProcessor = AudioBufferProcessor()
    private let audioQueue = DispatchQueue(label: "com.meetingassistant.audio", qos: .userInteractive)

    var audioDataStream: AsyncStream<Data>?

    func startCapture() async throws {
        guard CGPreflightScreenCaptureAccess() else {
            throw CaptureError.permissionDenied
        }

        let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: false)
        guard let display = content.displays.first else {
            throw CaptureError.noDisplay
        }

        let config = SCStreamConfiguration()
        config.capturesAudio = true
        config.excludesCurrentProcessAudio = false
        config.sampleRate = 48000
        config.channelCount = 2

        // Minimal video config - we only want audio but SCStream requires a filter
        config.width = 2
        config.height = 2
        config.minimumFrameInterval = CMTime(value: 1, timescale: 1)  // 1 fps max - minimizes video overhead

        let filter = SCContentFilter(display: display, excludingWindows: [])
        let stream = SCStream(filter: filter, configuration: config, delegate: self)

        audioDataStream = await bufferProcessor.makeStream()

        // Register BOTH audio and screen output handlers.
        // SCStream always sends screen frames even when we only want audio.
        // Without a screen handler registered, it logs "stream output NOT found. Dropping frame".
        try stream.addStreamOutput(self, type: .audio, sampleHandlerQueue: audioQueue)
        try stream.addStreamOutput(self, type: .screen, sampleHandlerQueue: audioQueue)
        try await stream.startCapture()

        self.stream = stream
        isCapturing = true
    }

    func stopCapture() async {
        guard let stream else { return }
        try? await stream.stopCapture()
        await bufferProcessor.stop()
        self.stream = nil
        isCapturing = false
        audioLevel = 0
    }

    enum CaptureError: LocalizedError {
        case permissionDenied
        case noDisplay

        var errorDescription: String? {
            switch self {
            case .permissionDenied:
                return "Screen Recording permission is required. Grant it in System Settings > Privacy & Security > Screen Recording."
            case .noDisplay:
                return "No display found to capture audio from."
            }
        }
    }
}

// MARK: - SCStreamOutput

extension AudioCaptureManager: SCStreamOutput {
    nonisolated func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType) {
        guard type == .audio else { return }

        Task {
            await bufferProcessor.process(sampleBuffer: sampleBuffer)
            let level = sampleBuffer.rmsLevel()
            await MainActor.run { self.audioLevel = level }
        }
    }
}

// MARK: - SCStreamDelegate

extension AudioCaptureManager: SCStreamDelegate {
    nonisolated func stream(_ stream: SCStream, didStopWithError error: Error) {
        Task { @MainActor in
            self.isCapturing = false
            self.audioLevel = 0
        }
    }
}

// MARK: - RMS level helper

private extension CMSampleBuffer {
    func rmsLevel() -> Float {
        guard let blockBuffer = CMSampleBufferGetDataBuffer(self) else { return 0 }
        var dataPointer: UnsafeMutablePointer<CChar>?
        var length = 0
        CMBlockBufferGetDataPointer(blockBuffer, atOffset: 0, lengthAtOffsetOut: nil, totalLengthOut: &length, dataPointerOut: &dataPointer)
        guard let ptr = dataPointer else { return 0 }

        let sampleCount = length / MemoryLayout<Int16>.size
        guard sampleCount > 0 else { return 0 }
        let samples = UnsafeBufferPointer(start: UnsafeRawPointer(ptr).assumingMemoryBound(to: Int16.self), count: sampleCount)

        var sumSquares: Float = 0
        for sample in samples {
            let f = Float(sample) / Float(Int16.max)
            sumSquares += f * f
        }
        let rms = sqrt(sumSquares / Float(sampleCount))
        return min(rms * 10, 1.0)  // amplify for visual feedback
    }
}
