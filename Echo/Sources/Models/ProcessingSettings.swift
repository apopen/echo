import Foundation

/// Configuration for the text processing pipeline.
struct ProcessingSettings: Codable, Equatable {
    var fillerRemovalEnabled: Bool = false
    var numberNormalizationEnabled: Bool = false
    var punctuationFormattingEnabled: Bool = false
    var customReplacementsEnabled: Bool = false
    var customReplacements: [ReplacementRule] = []
    var aiPostProcessingEnabled: Bool = true
}

/// A single find-and-replace rule.
struct ReplacementRule: Codable, Equatable, Identifiable {
    let id: UUID
    var find: String
    var replace: String
    var caseSensitive: Bool

    init(id: UUID = UUID(), find: String, replace: String, caseSensitive: Bool = false) {
        self.id = id
        self.find = find
        self.replace = replace
        self.caseSensitive = caseSensitive
    }
}

/// Per-app rule overrides.
struct AppRule: Codable, Equatable, Identifiable {
    let id: UUID
    var bundleID: String
    var displayName: String
    var autoSendEnabled: Bool = false
    var processingOverrides: ProcessingSettings?

    init(id: UUID = UUID(), bundleID: String, displayName: String, autoSendEnabled: Bool = false, processingOverrides: ProcessingSettings? = nil) {
        self.id = id
        self.bundleID = bundleID
        self.displayName = displayName
        self.autoSendEnabled = autoSendEnabled
        self.processingOverrides = processingOverrides
    }
}
