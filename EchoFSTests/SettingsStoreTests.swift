import XCTest
@testable import EchoFS

final class SettingsStoreTests: XCTestCase {

    // MARK: - Default Values

    func testDefaultHotkeyCombo() {
        let store = SettingsStore()
        XCTAssertEqual(store.hotkeyCombo, HotkeyCombo.default)
    }

    func testDefaultRecordMode() {
        let store = SettingsStore()
        XCTAssertEqual(store.recordMode, .hold)
    }

    func testDefaultModelID() {
        let store = SettingsStore()
        XCTAssertEqual(store.selectedModelID, "whisper-small.en")
    }

    func testDefaultMaxRecordingDuration() {
        let store = SettingsStore()
        XCTAssertEqual(store.maxRecordingDuration, 120)
    }

    func testDefaultPrivacyMode() {
        let store = SettingsStore()
        XCTAssertFalse(store.privacyModeEnabled)
    }

    // MARK: - App Rule Helpers

    func testShouldAutoSend_noRules() {
        let store = SettingsStore()
        XCTAssertFalse(store.shouldAutoSend(forBundleID: "com.apple.TextEdit"))
    }

    func testShouldAutoSend_withMatchingRule() {
        let store = SettingsStore()
        store.appRules = [
            AppRule(bundleID: "com.tinyspeck.slackmacgap", displayName: "Slack", autoSendEnabled: true)
        ]
        XCTAssertTrue(store.shouldAutoSend(forBundleID: "com.tinyspeck.slackmacgap"))
    }

    func testShouldAutoSend_withNonMatchingRule() {
        let store = SettingsStore()
        store.appRules = [
            AppRule(bundleID: "com.tinyspeck.slackmacgap", displayName: "Slack", autoSendEnabled: true)
        ]
        XCTAssertFalse(store.shouldAutoSend(forBundleID: "com.apple.TextEdit"))
    }

    func testShouldAutoSend_nilBundleID() {
        let store = SettingsStore()
        XCTAssertFalse(store.shouldAutoSend(forBundleID: nil))
    }

    // MARK: - Model Manifest

    func testModelManifestCatalog_hasEntries() {
        XCTAssertGreaterThanOrEqual(ModelManifest.catalog.count, 2)
    }

    func testModelManifestLookup() {
        let manifest = ModelManifest.manifest(for: "whisper-small.en")
        XCTAssertNotNil(manifest)
        XCTAssertEqual(manifest?.languageScope, .english)
    }

    func testModelManifestLookup_unknown() {
        let manifest = ModelManifest.manifest(for: "nonexistent-model")
        XCTAssertNil(manifest)
    }
}
