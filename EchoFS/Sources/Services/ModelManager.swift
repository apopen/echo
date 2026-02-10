import Foundation
import CryptoKit
import os.log

/// Manages whisper.cpp model downloads, verification, and storage.
@MainActor
final class ModelManager: ObservableObject {
    private static let logger = Logger(subsystem: "com.echo-fs", category: "ModelManager")

    @Published var downloadProgress: Double = 0
    @Published var isDownloading: Bool = false
    @Published var downloadError: String?

    private let fileManager = FileManager.default
    private var downloadDelegate: DownloadDelegate?

    /// Base directory for model storage.
    var modelsDirectory: URL {
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return appSupport.appendingPathComponent("echo-fs/Models", isDirectory: true)
    }

    /// Get the full file path for a model.
    func modelPath(for modelID: String) -> String {
        modelsDirectory.appendingPathComponent("\(modelID).bin").path
    }

    /// Check if a model is already downloaded.
    func isModelDownloaded(_ modelID: String) -> Bool {
        fileManager.fileExists(atPath: modelPath(for: modelID))
    }

    /// Get the list of available models with their download status.
    func availableModels() -> [(manifest: ModelManifest, downloaded: Bool)] {
        ModelManifest.catalog.map { manifest in
            (manifest, isModelDownloaded(manifest.id))
        }
    }

    /// Download a model from Hugging Face using URLSessionDownloadTask.
    func downloadModel(_ manifest: ModelManifest) async throws {
        guard !isDownloading else { return }

        isDownloading = true
        downloadProgress = 0
        downloadError = nil

        // Ensure directory exists
        do {
            try fileManager.createDirectory(at: modelsDirectory, withIntermediateDirectories: true)
        } catch {
            isDownloading = false
            downloadError = "Failed to create models directory: \(error.localizedDescription)"
            throw error
        }

        let destinationURL = URL(fileURLWithPath: modelPath(for: manifest.id))

        Self.logger.info("Starting download: \(manifest.id) from \(manifest.downloadURL)")

        do {
            let tempFileURL = try await downloadWithProgress(from: manifest.downloadURL)

            // Verify checksum if available
            if !manifest.sha256Checksum.isEmpty {
                Self.logger.info("Verifying checksum for \(manifest.id)...")
                let checksum = try computeSHA256(fileURL: tempFileURL)
                guard checksum == manifest.sha256Checksum else {
                    try? fileManager.removeItem(at: tempFileURL)
                    let error = ModelError.checksumMismatch(expected: manifest.sha256Checksum, actual: checksum)
                    downloadError = error.localizedDescription
                    isDownloading = false
                    throw error
                }
                Self.logger.info("Checksum verified for \(manifest.id)")
            }

            // Move temp file to final destination
            try? fileManager.removeItem(at: destinationURL)
            try fileManager.moveItem(at: tempFileURL, to: destinationURL)

            let fileSize = (try? fileManager.attributesOfItem(atPath: destinationURL.path)[.size] as? Int64) ?? 0
            Self.logger.info("Download complete: \(manifest.id) (\(fileSize) bytes)")

            downloadProgress = 1.0
            isDownloading = false
        } catch {
            Self.logger.error("Download failed: \(error.localizedDescription)")
            downloadError = error.localizedDescription
            isDownloading = false
            throw error
        }
    }

    /// Delete a downloaded model.
    func deleteModel(_ modelID: String) throws {
        let path = modelPath(for: modelID)
        if fileManager.fileExists(atPath: path) {
            try fileManager.removeItem(atPath: path)
            Self.logger.info("Deleted model: \(modelID)")
        }
    }

    // MARK: - Private

    private func downloadWithProgress(from url: URL) async throws -> URL {
        let delegate = DownloadDelegate()
        self.downloadDelegate = delegate

        // Observe progress on main actor
        let progressTask = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                if let self {
                    self.downloadProgress = delegate.progress
                }
                try await Task.sleep(nanoseconds: 200_000_000) // 200ms
            }
        }

        defer {
            progressTask.cancel()
            self.downloadDelegate = nil
        }

        let session = URLSession(configuration: .default, delegate: delegate, delegateQueue: nil)
        defer { session.finishTasksAndInvalidate() }

        return try await withCheckedThrowingContinuation { continuation in
            let task = session.downloadTask(with: url) { tempURL, response, error in
                if let error {
                    continuation.resume(throwing: ModelError.downloadFailed(error.localizedDescription))
                    return
                }

                guard let httpResponse = response as? HTTPURLResponse else {
                    continuation.resume(throwing: ModelError.downloadFailed("No HTTP response"))
                    return
                }

                guard (200...299).contains(httpResponse.statusCode) else {
                    continuation.resume(throwing: ModelError.downloadFailed("HTTP \(httpResponse.statusCode)"))
                    return
                }

                guard let tempURL else {
                    continuation.resume(throwing: ModelError.downloadFailed("No downloaded file"))
                    return
                }

                // Move to a stable temp location before the completion handler returns
                // (the system deletes the file after this callback)
                let stableTempURL = FileManager.default.temporaryDirectory
                    .appendingPathComponent(UUID().uuidString + ".bin")
                do {
                    try FileManager.default.moveItem(at: tempURL, to: stableTempURL)
                    continuation.resume(returning: stableTempURL)
                } catch {
                    continuation.resume(throwing: ModelError.downloadFailed("Failed to save temp file: \(error.localizedDescription)"))
                }
            }
            task.resume()
        }
    }

    private func computeSHA256(fileURL: URL) throws -> String {
        // Stream the file in chunks to avoid loading 460MB into memory
        let handle = try FileHandle(forReadingFrom: fileURL)
        defer { handle.closeFile() }

        var hasher = SHA256()
        let chunkSize = 1024 * 1024 // 1MB chunks
        while autoreleasepool(invoking: {
            let data = handle.readData(ofLength: chunkSize)
            guard !data.isEmpty else { return false }
            hasher.update(data: data)
            return true
        }) {}

        let digest = hasher.finalize()
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}

// MARK: - Download Delegate

private final class DownloadDelegate: NSObject, URLSessionDownloadDelegate {
    var progress: Double = 0

    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask,
                    didWriteData bytesWritten: Int64, totalBytesWritten: Int64,
                    totalBytesExpectedToWrite: Int64) {
        if totalBytesExpectedToWrite > 0 {
            progress = Double(totalBytesWritten) / Double(totalBytesExpectedToWrite)
        }
    }

    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask,
                    didFinishDownloadingTo location: URL) {
        // Handled in the completion handler of downloadTask
    }
}

// MARK: - Errors

enum ModelError: LocalizedError {
    case downloadFailed(String)
    case checksumMismatch(expected: String, actual: String)
    case modelNotFound(String)

    var errorDescription: String? {
        switch self {
        case .downloadFailed(let reason):
            return "Download failed: \(reason)"
        case .checksumMismatch(let expected, let actual):
            return "Checksum mismatch: expected \(expected), got \(actual)"
        case .modelNotFound(let id):
            return "Model not found: \(id)"
        }
    }
}
