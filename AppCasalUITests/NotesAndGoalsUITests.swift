//
//  NotesAndGoalsUITests.swift
//  AppCasalUITests
//

import XCTest

/// Notes and goals end to end in the demo configuration (local stores, no CloudKit).
final class NotesAndGoalsUITests: XCTestCase {
    private let baseArguments = ["-AppCasalDemo", "YES", "-AppCasalDemoEmpty", "YES"]

    override func setUp() {
        continueAfterFailure = false
    }

    @MainActor
    func testWriteNoteAndTickGoalStepPersistAfterRelaunch() {
        let app = XCUIApplication()
        app.launchArguments = baseArguments + ["-AppCasalDemoReset", "YES", "-AppCasalInitialTab", "notes"]
        app.launch()

        // Write a note and find it under "Enviados".
        let compose = app.buttons["notes.compose"]
        XCTAssertTrue(compose.waitForExistence(timeout: 15))
        compose.tap()
        let text = app.textFields["noteComposer.text"]
        XCTAssertTrue(text.waitForExistence(timeout: 5))
        text.typeText("Bom dia, amor")
        app.buttons["noteComposer.send"].tap()
        app.buttons["Enviados"].tap()
        XCTAssertTrue(app.staticTexts["Bom dia, amor"].waitForExistence(timeout: 5))

        // Create a goal with one step and tick it (Metas is at the end of Início).
        app.tabBars.buttons["Início"].tap()
        openGoals(in: app)
        let add = app.buttons["goals.add"]
        XCTAssertTrue(add.waitForExistence(timeout: 5))
        add.tap()
        let title = app.textFields["goalEditor.title"]
        XCTAssertTrue(title.waitForExistence(timeout: 5))
        title.tap()
        title.typeText("Viajar juntos")
        let newStep = app.textFields["goalEditor.newStep"]
        newStep.tap()
        newStep.typeText("Escolher destino\n")
        app.buttons["goalEditor.save"].tap()
        // Steps carry the toggle trait, so they are exposed as switches.
        let step = app.switches["Escolher destino"]
        XCTAssertTrue(step.waitForExistence(timeout: 5))
        step.tap()
        XCTAssertEqual(step.value as? String, "Feita")
        // Progress follows the tap right away, without reopening the screen.
        XCTAssertTrue(app.staticTexts["1 de 1 etapas"].waitForExistence(timeout: 2))
        step.tap()
        XCTAssertTrue(app.staticTexts["0 de 1 etapas"].waitForExistence(timeout: 2))
        step.tap()
        XCTAssertTrue(app.staticTexts["1 de 1 etapas"].waitForExistence(timeout: 2))

        // Reopen and check both survived.
        app.terminate()
        let reopened = XCUIApplication()
        reopened.launchArguments = baseArguments
        reopened.launch()
        openGoals(in: reopened)
        let reopenedStep = reopened.switches["Escolher destino"]
        XCTAssertTrue(reopenedStep.waitForExistence(timeout: 15))
        XCTAssertEqual(reopenedStep.value as? String, "Feita")
        reopened.tabBars.buttons["Recados"].tap()
        reopened.buttons["Enviados"].tap()
        XCTAssertTrue(reopened.staticTexts["Bom dia, amor"].waitForExistence(timeout: 5))
    }

    @MainActor
    private func openGoals(in app: XCUIApplication) {
        let link = app.buttons["home.goals"]
        var attempts = 0
        while !(link.exists && link.isHittable) && attempts < 8 {
            app.swipeUp()
            attempts += 1
        }
        XCTAssertTrue(link.waitForExistence(timeout: 10))
        link.tap()
    }
}
