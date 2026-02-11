import Foundation

/// Metadata for a whisper.cpp model available for download.
struct ModelManifest: Identifiable, Codable {
    let id: String
    let displayName: String
    let downloadURL: URL
    let sha256Checksum: String
    let fileSizeBytes: Int64
    let languageScope: LanguageScope

    enum LanguageScope: String, Codable {
        case english
        case multilingual
    }
}

extension ModelManifest {
    /// Built-in model catalog.
    static let catalog: [ModelManifest] = [
        ModelManifest(
            id: "whisper-small.en",
            displayName: "Small (English)",
            downloadURL: URL(string: "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-small.en.bin")!,
            sha256Checksum: "c6138d6d58ecc8322097e0f987c32f1be8bb0a18532a3f88f734d1bbf9c41e5d",
            fileSizeBytes: 487_614_201,
            languageScope: .english
        ),
        ModelManifest(
            id: "whisper-small",
            displayName: "Small (Multilingual)",
            downloadURL: URL(string: "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-small.bin")!,
            sha256Checksum: "1be3a9b2063867b937e64e2ec7483364a79917e157fa98c5d94b5c1fffea987b",
            fileSizeBytes: 487_601_967,
            languageScope: .multilingual
        ),
        ModelManifest(
            id: "whisper-base.en",
            displayName: "Base (English, Lightweight)",
            downloadURL: URL(string: "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-base.en.bin")!,
            sha256Checksum: "a03779c86df3323075f5e796cb2ce5029f00ec8869eee3fdfb897afe36c6d002",
            fileSizeBytes: 147_964_211,
            languageScope: .english
        ),
    ]

    static func manifest(for id: String) -> ModelManifest? {
        catalog.first { $0.id == id }
    }
}
