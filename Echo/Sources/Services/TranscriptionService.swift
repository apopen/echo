import Foundation
import WhisperCppKit
import os.log

/// Wraps WhisperCppKit for on-device speech-to-text inference.
/// All inference runs on a dedicated background queue to keep the main thread responsive.
final class TranscriptionService {
    private static let logger = Logger(subsystem: "com.echo", category: "TranscriptionService")

    /// Dedicated serial queue for whisper.cpp inference (CPU/GPU intensive).
    private let inferenceQueue = DispatchQueue(label: "com.echo.inference", qos: .userInitiated)

    private var whisperContext: WhisperContext?
    private var isCancelled = false
    private let cancelLock = NSLock()

    var isModelLoaded: Bool {
        whisperContext != nil
    }

    /// Load a whisper.cpp model from disk.
    /// - Parameter path: Full file path to the .bin model file.
    func loadModel(_ path: String) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            inferenceQueue.async { [weak self] in
                guard let self else {
                    continuation.resume(throwing: TranscriptionError.serviceUnavailable)
                    return
                }

                // Unload existing model first
                self.whisperContext = nil

                do {
                    let ctx = try WhisperContext(modelPath: path, useGPU: true, flashAttn: true, gpuDevice: 0)
                    self.whisperContext = ctx
                    Self.logger.info("Model loaded: \(path)")
                    continuation.resume()
                } catch {
                    Self.logger.error("Failed to load model from: \(path) — \(error.localizedDescription)")
                    continuation.resume(throwing: TranscriptionError.modelLoadFailed(path))
                }
            }
        }
    }

    /// Unload the current model and free resources.
    func unloadModel() async {
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            inferenceQueue.async { [weak self] in
                self?.whisperContext = nil
                Self.logger.info("Model unloaded")
                continuation.resume()
            }
        }
    }

    /// Transcribe audio samples to text.
    /// - Parameters:
    ///   - samples: Float32 PCM samples at 16kHz mono, in range [-1, 1].
    ///   - language: Language code (e.g., "en") or nil for auto-detect.
    /// - Returns: Transcribed text.
    func transcribe(_ samples: [Float], language: String?) async throws -> String {
        guard whisperContext != nil else {
            throw TranscriptionError.noModelLoaded
        }

        cancelLock.lock()
        isCancelled = false
        cancelLock.unlock()

        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<String, Error>) in
            inferenceQueue.async { [weak self] in
                guard let self, let ctx = self.whisperContext else {
                    continuation.resume(throwing: TranscriptionError.noModelLoaded)
                    return
                }

                // Check for cancellation before starting
                self.cancelLock.lock()
                let cancelled = self.isCancelled
                self.cancelLock.unlock()
                if cancelled {
                    continuation.resume(throwing: TranscriptionError.cancelled)
                    return
                }

                var options = WhisperOptions()
                options.language = language
                options.verbose = false

                do {
                    let segments = try ctx.transcribe(pcm16k: samples, options: options)

                    let text = segments
                        .map { $0.text }
                        .joined()
                        .trimmingCharacters(in: .whitespacesAndNewlines)

                    Self.logger.info("Transcription complete (\(segments.count) segments)")
                    continuation.resume(returning: text)
                } catch {
                    Self.logger.error("Whisper inference failed: \(error.localizedDescription)")
                    continuation.resume(throwing: TranscriptionError.inferenceFailed(error.localizedDescription))
                }
            }
        }
    }

    /// Cancel an in-progress transcription.
    func cancel() {
        cancelLock.lock()
        isCancelled = true
        cancelLock.unlock()
    }
}

// MARK: - Errors

enum TranscriptionError: LocalizedError {
    case modelLoadFailed(String)
    case noModelLoaded
    case inferenceFailed(String)
    case cancelled
    case serviceUnavailable

    var errorDescription: String? {
        switch self {
        case .modelLoadFailed(let path):
            return "Failed to load model from: \(path)"
        case .noModelLoaded:
            return "No model is loaded"
        case .inferenceFailed(let reason):
            return "Transcription failed: \(reason)"
        case .cancelled:
            return "Transcription was cancelled"
        case .serviceUnavailable:
            return "Transcription service is unavailable"
        }
    }
}
