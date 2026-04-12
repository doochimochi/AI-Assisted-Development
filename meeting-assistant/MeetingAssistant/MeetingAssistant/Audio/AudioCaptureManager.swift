import Foundation
import ScreenCaptureKit
import CoreMedia
import os.signpost

private let log = OSLog(subsystem: "com.meetingassistant", category: "AudioCapture")

/// Captures all system audio output using ScreenCaptureKit SCStream.
///
/// - Runs on a private serial queue (not the main thread).
/// - Immediately forwards CMSampleBuffers to AudioBufferProcessor then releases them.
/// - The caller is responsible for calling startCapture() only after Screen Recording
///   permission has been granted (see AudioPermissionManager).
final class AudioCaptureManager: NSObject {

    private var stream: SCStream?
    private let audioQueue = DispatchQueue(label: "com.meetingassistant.audio", qos: .userInteractive)
    private let bufferProcessor: AudioBufferProcessor

    private(set) var isCapturing = false

    init(bufferProcessor: AudioBufferProcessor) {
        self.bufferProcessor = bufferProcessor
    }

    // MARK: - Public API

    func startCapture() async throws {
        guard !isCapturing else { return }

        let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: false)
        guard let display = content.displays.first else {
            throw CaptureError.noDisplayFound
        }

        let filter = SCContentFilter(display: display, excludingWindows: [])

        let config = SCStreamConfiguration()
        config.capturesAudio = true
        config.excludesCurrentProcessAudio = false  // include our own audio if any
        config.sampleRate = 48_000
        config.channelCount = 2

        // Disable video — audio only
        config.width  = 2
        config.height = 2
        config.minimumFrameInterval = CMTime(value: 1, timescale: 1)   // 1 fps = near zero CPU

        let newStream = SCStream(filter: filter, configuration: config, delegate: self)
        try newStream.addStreamOutput(self, type: .audio, sampleHandlerQueue: audioQueue)
        try await newStream.startCapture()

        stream = newStream
        isCapturing = true
    }

    func stopCapture() async {
        guard isCapturing, let stream else { return }
        try? await stream.stopCapture()
        self.stream = nil
        isCapturing = false
        await bufferProcessor.stop()
    }

    // MARK: - Error

    enum CaptureError: Error {
        case noDisplayFound
        case permissionDenied
    }
}

// MARK: - SCStreamOutput

extension AudioCaptureManager: SCStreamOutput {
    func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType) {
        guard type == .audio else { return }
        os_signpost(.begin, log: log, name: "AudioChunk")
        Task { await bufferProcessor.process(sampleBuffer) }
        // sampleBuffer is released here as it goes out of scope
        os_signpost(.end, log: log, name: "AudioChunk")
    }
}

// MARK: - SCStreamDelegate

extension AudioCaptureManager: SCStreamDelegate {
    func stream(_ stream: SCStream, didStopWithError error: Error) {
        isCapturing = false
        print("[AudioCaptureManager] Stream stopped with error: \(error)")
    }
}
