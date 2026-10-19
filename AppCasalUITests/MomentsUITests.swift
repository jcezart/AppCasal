//
//  MomentsUITests.swift
//  AppCasalUITests
//

import XCTest

/// "Hoje, nós dois" end to end in the demo configuration (local stores, no CloudKit).
final class MomentsUITests: XCTestCase {
    private let baseArguments = ["-AppCasalDemo", "YES", "-AppCasalDemoEmpty", "YES"]

    override func setUp() {
        continueAfterFailure = false
    }

    /// Answer today's question from Início; the sent answer waits for the partner, never
    /// shows theirs, and survives a relaunch. Once answered, the card leaves Início and
    /// stays in the "Hoje" tab.
    @MainActor
    func testAnswerDailyQuestionWaitsForPartnerAfterRelaunch() {
        let app = XCUIApplication()
        app.launchArguments = baseArguments + ["-AppCasalDemoReset", "YES"]
        app.launch()

        let action = app.buttons["moments.home.action"]
        scrollTo(action, in: app)
        action.tap()

        let answer = app.textFields["daily.answer"]
        XCTAssertTrue(answer.waitForExistence(timeout: 5))
        answer.tap()
        answer.typeText("Uma comédia com muitas risadas")
        app.buttons["daily.send"].tap()
        let confirm = app.buttons["Enviar"]
        XCTAssertTrue(confirm.waitForExistence(timeout: 5))
        confirm.tap()

        XCTAssertTrue(app.staticTexts["Sua resposta"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Uma comédia com muitas risadas"].exists)
        XCTAssertFalse(app.textFields["daily.answer"].exists, "a sent answer is final")

        app.terminate()
        let reopened = XCUIApplication()
        reopened.launchArguments = baseArguments
        reopened.launch()
        XCTAssertTrue(reopened.tabBars.buttons["Início"].waitForExistence(timeout: 10))
        XCTAssertFalse(reopened.buttons["moments.home.action"].exists, "answered: not on Início")
        openMoments(in: reopened)
        let again = reopened.buttons["moments.home.action"]
        scrollTo(again, in: reopened)
        XCTAssertEqual(again.label, "Ver pergunta")
        again.tap()
        XCTAssertTrue(reopened.staticTexts["Uma comédia com muitas risadas"].waitForExistence(timeout: 5))
    }

    /// Explore lists the activities; drawing a date and planning it shows the confirmation.
    @MainActor
    func testDrawAndPlanADate() {
        let app = XCUIApplication()
        app.launchArguments = baseArguments + ["-AppCasalDemoReset", "YES"]
        app.launch()

        openMoments(in: app)
        let dates = app.buttons["moments.explore.dates"]
        XCTAssertTrue(dates.waitForExistence(timeout: 5))
        dates.tap()

        let draw = app.buttons["dates.draw"]
        scrollTo(draw, in: app)
        draw.tap()
        let plan = app.buttons["dates.plan"]
        scrollTo(plan, in: app)
        plan.tap()
        XCTAssertTrue(app.staticTexts["Combinado! O plano está em Planos e convites."].waitForExistence(timeout: 5))
    }

    @MainActor
    private func openMoments(in app: XCUIApplication) {
        let button = app.tabBars.buttons["Hoje"]
        XCTAssertTrue(button.waitForExistence(timeout: 10))
        button.tap()
    }

    @MainActor
    private func scrollTo(_ element: XCUIElement, in app: XCUIApplication) {
        var attempts = 0
        while !(element.exists && element.isHittable) && attempts < 8 {
            app.swipeUp()
            attempts += 1
        }
        XCTAssertTrue(element.waitForExistence(timeout: 5))
    }
}
