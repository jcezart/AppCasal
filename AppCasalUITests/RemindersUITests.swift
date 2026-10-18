//
//  RemindersUITests.swift
//  AppCasalUITests
//

import XCTest

/// Reminders end to end in the demo configuration (no notification permission prompt there).
final class RemindersUITests: XCTestCase {
    private let baseArguments = ["-AppCasalDemo", "YES", "-AppCasalDemoEmpty", "YES", "-AppCasalShowSpace", "YES"]

    override func setUp() {
        continueAfterFailure = false
    }

    @MainActor
    func testCreateReminderPersistsAfterRelaunch() {
        let app = XCUIApplication()
        app.launchArguments = baseArguments + ["-AppCasalDemoReset", "YES"]
        app.launch()

        openReminders(in: app)
        app.buttons["reminders.add"].tap()
        let title = app.textFields["reminderEditor.title"]
        XCTAssertTrue(title.waitForExistence(timeout: 5))
        title.tap()
        title.typeText("Dia do primeiro beijo")
        app.buttons["reminderEditor.save"].tap()
        XCTAssertTrue(reminderRow("Dia do primeiro beijo", in: app).waitForExistence(timeout: 5))

        app.terminate()
        let reopened = XCUIApplication()
        reopened.launchArguments = baseArguments
        reopened.launch()
        openReminders(in: reopened)
        XCTAssertTrue(reminderRow("Dia do primeiro beijo", in: reopened).waitForExistence(timeout: 10))
    }

    @MainActor
    private func openReminders(in app: XCUIApplication) {
        let link = app.buttons["space.reminders"]
        XCTAssertTrue(link.waitForExistence(timeout: 15))
        link.tap()
        XCTAssertTrue(app.buttons["reminders.add"].waitForExistence(timeout: 5))
    }

    @MainActor
    private func reminderRow(_ text: String, in app: XCUIApplication) -> XCUIElement {
        app.buttons.matching(NSPredicate(format: "label CONTAINS %@", text)).firstMatch
    }
}
