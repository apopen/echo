import Foundation
import CryptoKit
import os.log

/// Manages whisper.cpp model downloads, verification, and storage.
@MainActor
final class ModelManager: ObservableObject {
    private static let logger = Logger(subsystem: "com.echo", category: "ModelManager")

    @Published var downloadProgress: Double = 0
    @Published var isDownloading: Bool = false
    @Published var downloadingModelID: String?
    @Published var downloadError: String?

    private let fileManager = FileManager.default

    /// Base directory for model storage.
    var modelsDirectory: URL {
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return appSupport.appendingPathComponent("Echo/Models", isDirectory: true)
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

    /// Download a model from Hugging Face using URLSession with bytes streaming.
    func downloadModel(_ manifest: ModelManifest) async throws {
        guard !isDownloading else { return }

        isDownloading = true
        downloadingModelID = manifest.id
        downloadProgress = 0
        downloadError = nil

        // Ensure directory exists
        do {
            try fileManager.createDirectory(at: modelsDirectory, withIntermediateDirectories: true)
        } catch {
            isDownloading = false
            downloadingModelID = nil
            downloadError = "Failed to create models directory: \(error.localizedDescription)"
            throw error
        }

        let destinationURL = URL(fileURLWithPath: modelPath(for: manifest.id))

        Self.logger.info("Starting download: \(manifest.id) from \(manifest.downloadURL)")

        do {
            let tempFileURL = try await downloadWithProgress(from: manifest.downloadURL, expectedSize: manifest.fileSizeBytes)

            // Verify checksum if available
            if !manifest.sha256Checksum.isEmpty {
                Self.logger.info("Verifying checksum for \(manifest.id)...")
                downloadProgress = 1.0
                let checksum = try computeSHA256(fileURL: tempFileURL)
                guard checksum == manifest.sha256Checksum else {
                    try? fileManager.removeItem(at: tempFileURL)
                    let error = ModelError.checksumMismatch(expected: manifest.sha256Checksum, actual: checksum)
                    downloadError = error.localizedDescription
                    isDownloading = false
                    downloadingModelID = nil
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
            downloadingModelID = nil
        } catch {
            Self.logger.error("Download failed: \(error.localizedDescription)")
            downloadError = error.localizedDescription
            isDownloading = false
            downloadingModelID = nil
            throw error
        }
    }

    /// Delete a downloaded model.
    func deleteModel(_ modelID: String) throws {
        let path = modelPath(for: modelID)
        if fileManager.fileExists(atPath: path) {
            try fileManager.removeItem(atPath: path)
            Self.logger.info("Deleted model: \(modelID)")
            objectWillChange.send()
        }
    }

    // MARK: - Private

    private func downloadWithProgress(from url: URL, expectedSize: Int64) async throws -> URL {
        let tempFileURL = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".bin")

        let (bytes, response) = try await URLSession.shared.bytes(from: url)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            let code = (response as? HTTPURLResponse)?.statusCode ?? 0
            throw ModelError.downloadFailed("HTTP \(code)")
        }

        let totalSize = httpResponse.expectedContentLength > 0
            ? httpResponse.expectedContentLength
            : expectedSize

        fileManager.createFile(atPath: tempFileURL.path, contents: nil)
        let handle = try FileHandle(forWritingTo: tempFileURL)
        defer { try? handle.close() }

        var bytesReceived: Int64 = 0
        var lastProgressUpdate = Date.distantPast
        let bufferSize = 65_536 // 64KB buffer
        var buffer = Data()
        buffer.reserveCapacity(bufferSize)

        for try await byte in bytes {
            buffer.append(byte)

            if buffer.count >= bufferSize {
                handle.write(buffer)
                bytesReceived += Int64(buffer.count)
                buffer.removeAll(keepingCapacity: true)

                let now = Date()
                if now.timeIntervalSince(lastProgressUpdate) >= 0.2 {
                    lastProgressUpdate = now
                    let progress = totalSize > 0 ? Double(bytesReceived) / Double(totalSize) : 0
                    self.downloadProgress = progress
                }
            }
        }

        // Flush remaining buffer
        if !buffer.isEmpty {
            handle.write(buffer)
            bytesReceived += Int64(buffer.count)
        }

        self.downloadProgress = 1.0
        return tempFileURL
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
