//
//  AccessibilityAuditUITests.swift
//  AppCasalUITests
//

import XCTest

/// Apple's accessibility audit on the main tabs, with the demo couple (local stores,
/// no CloudKit): every element VoiceOver reaches has a meaningful description.
final class AccessibilityAuditUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = true
    }

    @MainActor
    func testMainTabsHaveDescribedElements() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-AppCasalDemo", "YES", "-AppCasalDemoReset", "YES"]
        app.launch()
        XCTAssertTrue(app.tabBars.buttons["Início"].waitForExistence(timeout: 20))

        for tab in ["Início", "Hoje", "Memórias", "Recados"] {
            app.tabBars.buttons[tab].tap()
            try app.performAccessibilityAudit(for: [.sufficientElementDescription]) { issue in
                XCTFail("\(tab): \(issue.compactDescription) — \(issue.element?.debugDescription ?? "?")")
                return true
            }
        }
    }
}
