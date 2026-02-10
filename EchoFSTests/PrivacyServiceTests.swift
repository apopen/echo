import XCTest
@testable import EchoFS

final class PrivacyServiceTests: XCTestCase {

    func testDefaultPrivacyModeIsOff() {
        let service = PrivacyService()
        XCTAssertFalse(service.isPrivacyModeEnabled)
    }

    func testPrivacyModeCanBeEnabled() {
        let service = PrivacyService()
        service.isPrivacyModeEnabled = true
        XCTAssertTrue(service.isPrivacyModeEnabled)
    }

    func testPrivacyModeCanBeDisabled() {
        let service = PrivacyService()
        service.isPrivacyModeEnabled = true
        service.isPrivacyModeEnabled = false
        XCTAssertFalse(service.isPrivacyModeEnabled)
    }
}
