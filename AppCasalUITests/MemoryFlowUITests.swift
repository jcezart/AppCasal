//
//  MemoryFlowUITests.swift
//  AppCasalUITests
//

import XCTest

/// End-to-end memory flow in the demo configuration (local stores, no CloudKit):
/// create, edit, then close and reopen the app and find the memory again.
final class MemoryFlowUITests: XCTestCase {
    private let baseArguments = ["-AppCasalDemo", "YES", "-AppCasalDemoEmpty", "YES", "-AppCasalInitialTab", "memories"]

    override func setUp() {
        continueAfterFailure = false
    }

    @MainActor
    func testCreateEditAndPersistAfterRelaunch() {
        let app = XCUIApplication()
        app.launchArguments = baseArguments + ["-AppCasalDemoReset", "YES"]
        app.launch()

        // Create.
        let add = app.buttons["memories.add"]
        XCTAssertTrue(add.waitForExistence(timeout: 15))
        add.tap()
        let title = app.textFields["memoryEditor.title"]
        XCTAssertTrue(title.waitForExistence(timeout: 5))
        title.tap()
        title.typeText("Piquenique no parque")
        app.buttons["memoryEditor.save"].tap()

        let createdCard = card(containing: "Piquenique no parque", in: app)
        XCTAssertTrue(createdCard.waitForExistence(timeout: 5), "memory appears in the timeline")

        // Edit from the detail screen.
        createdCard.tap()
        let menu = app.buttons["memoryDetail.menu"]
        XCTAssertTrue(menu.waitForExistence(timeout: 5))
        menu.tap()
        app.buttons["Editar"].tap()
        let editTitle = app.textFields["memoryEditor.title"]
        XCTAssertTrue(editTitle.waitForExistence(timeout: 5))
        editTitle.tap()
        editTitle.typeText(" editado")
        app.buttons["memoryEditor.save"].tap()
        XCTAssertTrue(app.staticTexts["Piquenique no parque editado"].waitForExistence(timeout: 5))

        // Close and reopen without resetting the store.
        app.terminate()
        let reopened = XCUIApplication()
        reopened.launchArguments = baseArguments
        reopened.launch()
        XCTAssertTrue(card(containing: "Piquenique no parque editado", in: reopened).waitForExistence(timeout: 15),
                      "edited memory is still there after reopening")
    }

    /// Walks the memory screens with demo content and attaches screenshots for design review.
    @MainActor
    func testMemoryScreensForReview() {
        let app = XCUIApplication()
        app.launchArguments = ["-AppCasalDemo", "YES", "-AppCasalDemoReset", "YES", "-AppCasalInitialTab", "memories"]
        app.launch()

        let firstCard = app.buttons["memories.card"].firstMatch
        XCTAssertTrue(firstCard.waitForExistence(timeout: 15))
        attachScreenshot(named: "1-timeline", app)

        firstCard.tap()
        XCTAssertTrue(app.buttons["memoryDetail.menu"].waitForExistence(timeout: 5))
        attachScreenshot(named: "2-detail", app)

        app.buttons["memoryDetail.menu"].tap()
        app.buttons["Editar"].tap()
        XCTAssertTrue(app.textFields["memoryEditor.title"].waitForExistence(timeout: 5))
        attachScreenshot(named: "3-edit", app)
    }

    @MainActor
    private func attachScreenshot(named name: String, _ app: XCUIApplication) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    @MainActor
    private func card(containing text: String, in app: XCUIApplication) -> XCUIElement {
        app.buttons.matching(NSPredicate(format: "label CONTAINS %@", text)).firstMatch
    }
}
