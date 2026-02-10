import AVFoundation
import os.log

/// Captures microphone audio via AVAudioEngine, resampling to 16kHz mono Float32.
final class RecordingService {
    private static let logger = Logger(subsystem: "com.echo-fs", category: "RecordingService")

    /// Target format required by whisper.cpp: 16kHz mono Float32
    static let targetSampleRate: Double = 16000.0
    static let targetChannels: AVAudioChannelCount = 1

    private let engine = AVAudioEngine()
    private var audioBuffer: [Float] = []
    private var isRecording = false
    private var maxDurationTimer: Timer?
    private let bufferLock = NSLock()

    /// Current audio level (RMS, 0.0–1.0) updated during recording.
    var onAudioLevel: ((Float) -> Void)?

    /// Start recording audio from the default input device.
    /// - Parameters:
    ///   - maxDuration: Maximum recording duration in seconds before auto-stop.
    ///   - onMaxDuration: Called on the main thread when max duration is reached.
    func start(maxDuration: TimeInterval = 120, onMaxDuration: (() -> Void)? = nil) {
        guard !isRecording else { return }

        bufferLock.lock()
        audioBuffer.removeAll()
        bufferLock.unlock()

        let inputNode = engine.inputNode
        let inputFormat = inputNode.outputFormat(forBus: 0)

        guard let targetFormat = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: Self.targetSampleRate,
            channels: Self.targetChannels,
            interleaved: false
        ) else {
            Self.logger.error("Failed to create target audio format")
            return
        }

        // Create converter for resampling if needed
        let converter: AVAudioConverter?
        if inputFormat.sampleRate != Self.targetSampleRate || inputFormat.channelCount != Self.targetChannels {
            converter = AVAudioConverter(from: inputFormat, to: targetFormat)
            if converter == nil {
                Self.logger.error("Failed to create audio converter from \(inputFormat.sampleRate)Hz to \(Self.targetSampleRate)Hz")
                return
            }
        } else {
            converter = nil
        }

        inputNode.installTap(onBus: 0, bufferSize: 4096, format: inputFormat) { [weak self] buffer, _ in
            guard let self else { return }

            if let converter {
                self.convertAndAppend(buffer: buffer, converter: converter, targetFormat: targetFormat)
            } else {
                self.appendBuffer(buffer)
            }
        }

        do {
            try engine.start()
            isRecording = true
            Self.logger.info("Recording started (input: \(inputFormat.sampleRate)Hz \(inputFormat.channelCount)ch)")

            // Set up max duration timer
            if maxDuration > 0 {
                DispatchQueue.main.async {
                    self.maxDurationTimer = Timer.scheduledTimer(withTimeInterval: maxDuration, repeats: false) { [weak self] _ in
                        guard let self, self.isRecording else { return }
                        Self.logger.info("Max recording duration reached (\(maxDuration)s)")
                        onMaxDuration?()
                    }
                }
            }
        } catch {
            Self.logger.error("Failed to start audio engine: \(error.localizedDescription)")
        }
    }

    /// Stop recording and return the captured audio buffer.
    /// - Returns: Array of Float32 samples at 16kHz mono, or nil if not recording.
    @discardableResult
    func stop() -> [Float]? {
        guard isRecording else { return nil }

        maxDurationTimer?.invalidate()
        maxDurationTimer = nil

        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        isRecording = false

        bufferLock.lock()
        let result = audioBuffer
        audioBuffer.removeAll()
        bufferLock.unlock()

        Self.logger.info("Recording stopped (\(result.count) samples, \(Double(result.count) / Self.targetSampleRate)s)")
        return result
    }

    /// List available audio input devices.
    func availableInputDevices() -> [AVCaptureDevice] {
        AVCaptureDevice.DiscoverySession(
            deviceTypes: [.microphone],
            mediaType: .audio,
            position: .unspecified
        ).devices
    }

    // MARK: - Private

    private func convertAndAppend(buffer: AVAudioPCMBuffer, converter: AVAudioConverter, targetFormat: AVAudioFormat) {
        let frameCapacity = AVAudioFrameCount(
            Double(buffer.frameLength) * Self.targetSampleRate / buffer.format.sampleRate
        )
        guard let convertedBuffer = AVAudioPCMBuffer(pcmFormat: targetFormat, frameCapacity: frameCapacity) else {
            return
        }

        var error: NSError?
        var inputConsumed = false
        converter.convert(to: convertedBuffer, error: &error) { _, outStatus in
            if inputConsumed {
                outStatus.pointee = .noDataNow
                return nil
            }
            inputConsumed = true
            outStatus.pointee = .haveData
            return buffer
        }

        if let error {
            Self.logger.error("Audio conversion error: \(error.localizedDescription)")
            return
        }

        appendBuffer(convertedBuffer)
    }

    private func appendBuffer(_ buffer: AVAudioPCMBuffer) {
        guard let channelData = buffer.floatChannelData else { return }
        let frameCount = Int(buffer.frameLength)
        let ptr = channelData[0]
        let samples = Array(UnsafeBufferPointer(start: ptr, count: frameCount))

        bufferLock.lock()
        audioBuffer.append(contentsOf: samples)
        bufferLock.unlock()

        // Calculate audio level for metering — use peak amplitude, not RMS,
        // for more responsive visual feedback
        if frameCount > 0, let callback = onAudioLevel {
            var peak: Float = 0
            for i in 0..<frameCount {
                let abs = Swift.abs(ptr[i])
                if abs > peak { peak = abs }
            }
            // Scale up aggressively — mic input is very quiet
            let level = min(peak * 25.0, 1.0)
            callback(level)
        }
    }
}
