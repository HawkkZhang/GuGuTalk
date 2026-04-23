@preconcurrency import AVFoundation
import Foundation

final class AudioCaptureEngine {
    typealias AudioHandler = @Sendable (AudioChunk) async -> Void

    private let audioEngine = AVAudioEngine()
    private var audioConverter: AVAudioConverter?
    private let targetFormat = AVAudioFormat(commonFormat: .pcmFormatInt16, sampleRate: 16_000, channels: 1, interleaved: false)!
    private var audioHandler: AudioHandler?

    func startCapture(handler: @escaping AudioHandler) throws {
        stopCapture()

        audioHandler = handler

        let inputNode = audioEngine.inputNode
        let inputFormat = inputNode.outputFormat(forBus: 0)
        audioConverter = AVAudioConverter(from: inputFormat, to: targetFormat)

        inputNode.installTap(onBus: 0, bufferSize: 1_024, format: inputFormat) { [weak self] buffer, _ in
            guard let self else { return }
            guard let convertedBuffer = self.convert(buffer: buffer) else { return }
            guard let pcmData = convertedBuffer.int16PCMData else { return }

            let audioLevel = convertedBuffer.rmsLevel
            let chunk = AudioChunk(
                pcmData: pcmData,
                sampleRate: self.targetFormat.sampleRate,
                channels: Int(self.targetFormat.channelCount),
                audioLevel: audioLevel,
                nativeBuffer: convertedBuffer
            )

            Task {
                await handler(chunk)
            }
        }

        audioEngine.prepare()
        try audioEngine.start()
    }

    func stopCapture() {
        audioEngine.inputNode.removeTap(onBus: 0)
        audioEngine.stop()
        audioHandler = nil
        audioConverter = nil
    }

    private func convert(buffer: AVAudioPCMBuffer) -> AVAudioPCMBuffer? {
        guard let audioConverter else { return nil }

        let ratio = targetFormat.sampleRate / buffer.format.sampleRate
        let capacity = max(1, AVAudioFrameCount(Double(buffer.frameLength) * ratio) + 1)
        guard let convertedBuffer = AVAudioPCMBuffer(pcmFormat: targetFormat, frameCapacity: capacity) else {
            return nil
        }

        var conversionError: NSError?
        let sourceBuffer = buffer
        let status = audioConverter.convert(to: convertedBuffer, error: &conversionError) { _, outStatus in
            outStatus.pointee = .haveData
            return sourceBuffer
        }

        if let conversionError {
            NSLog("Audio conversion failed: \(conversionError.localizedDescription)")
            return nil
        }

        switch status {
        case .haveData, .inputRanDry, .endOfStream:
            return convertedBuffer
        default:
            return nil
        }
    }
}

private extension AVAudioPCMBuffer {
    var int16PCMData: Data? {
        guard let channelData = int16ChannelData else { return nil }
        let samples = Int(frameLength)
        return Data(bytes: channelData[0], count: samples * MemoryLayout<Int16>.size)
    }

    var rmsLevel: Float {
        guard let channelData = int16ChannelData else { return 0 }
        let samples = Int(frameLength)
        guard samples > 0 else { return 0 }
        let pointer = channelData[0]
        var sum: Float = 0
        for index in 0..<samples {
            let normalized = Float(pointer[index]) / Float(Int16.max)
            sum += normalized * normalized
        }
        return sqrt(sum / Float(samples))
    }
}
