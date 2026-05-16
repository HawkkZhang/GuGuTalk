import Foundation

protocol SpeechProvider: AnyObject, Sendable {
    var mode: RecognitionMode { get }
    var events: AsyncStream<TranscriptEvent> { get }

    func startSession(config: RecognitionConfig) async throws
    func sendAudio(_ chunk: AudioChunk) async throws
    func finishAudio() async throws
    func cancel() async
}
