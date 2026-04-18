import Foundation

protocol TranscriptionEngine: AnyObject {
    var isConnected: Bool { get }
    func connect() async throws
    func disconnect() async
    func send(audioData: Data) async throws
    var transcriptStream: AsyncThrowingStream<TranscriptSegment, Error> { get }
}
