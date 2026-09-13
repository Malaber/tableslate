import XCTest

final class TableSlateUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testPrimaryNavigationAndStartFlow() throws {
        let app = launchApp()

        XCTAssertTrue(app.navigationBars["TableSlate"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["start-game-button"].exists)

        let gamesTab = tabButton(named: "Games", in: app)
        XCTAssertTrue(gamesTab.waitForExistence(timeout: 2))
        gamesTab.tap()
        XCTAssertTrue(app.navigationBars["Games"].waitForExistence(timeout: 2))

        let historyTab = tabButton(named: "History", in: app)
        XCTAssertTrue(historyTab.waitForExistence(timeout: 2))
        historyTab.tap()
        XCTAssertTrue(app.navigationBars["History"].waitForExistence(timeout: 2))
    }

    func testSettingsExposesAppearanceChoice() throws {
        let app = launchApp()
        app.buttons["settings-button"].tap()

        XCTAssertTrue(app.segmentedControls["appearance-picker"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.segmentedControls.buttons["System"].exists)
        XCTAssertTrue(app.segmentedControls.buttons["Light"].exists)
        XCTAssertTrue(app.segmentedControls.buttons["Dark"].exists)
    }

    func testGenericGameAutosavesAndResumesAfterRelaunch() throws {
        let app = launchApp()
        app.buttons["start-game-button"].tap()

        let generic = app.buttons["choose-game-generic-score"]
        XCTAssertTrue(generic.waitForExistence(timeout: 3))
        generic.tap()

        let playerField = app.textFields["new-player-field"]
        XCTAssertTrue(playerField.waitForExistence(timeout: 2))
        playerField.tap()
        playerField.typeText("Daniel")
        app.buttons["Add"].tap()

        let start = app.buttons["start-scoring-button"]
        XCTAssertTrue(start.isEnabled)
        start.tap()
        XCTAssertTrue(app.navigationBars["Generic Score"].waitForExistence(timeout: 4))

        app.buttons["increment-Daniel"].tap()
        XCTAssertEqual(app.buttons["score-Daniel"].label, "Daniel score, 1")

        app.terminate()
        app.launchArguments = []
        app.launch()

        let resume = app.buttons["resume-generic-score"]
        XCTAssertTrue(resume.waitForExistence(timeout: 5))
        resume.tap()
        XCTAssertTrue(app.navigationBars["Generic Score"].waitForExistence(timeout: 3))
        XCTAssertEqual(app.buttons["score-Daniel"].label, "Daniel score, 1")
    }

    func testLargestDynamicTypeKeepsPrimaryActionReachable() throws {
        let app = XCUIApplication()
        app.launchArguments = [
            "--ui-testing-reset",
            "-UIPreferredContentSizeCategoryName",
            "UICTContentSizeCategoryAccessibilityExtraExtraExtraLarge",
        ]
        app.launch()

        XCTAssertTrue(app.navigationBars["TableSlate"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["start-game-button"].isHittable)
    }

    func testWizardScoresRoundValidatesAndAdvances() throws {
        let app = launchApp()
        openGame("wizard", players: ["Daniel", "Luisa", "Pascal"], in: app)
        XCTAssertTrue(app.navigationBars["Wizard"].waitForExistence(timeout: 4))
        XCTAssertTrue(app.descendants(matching: .any)["round-validation-warning"].exists)

        tapWhenHittable(app.buttons["Daniel-bid-1"], in: app)
        tapWhenHittable(app.buttons["Daniel-tricks-1"], in: app)
        for player in ["Luisa", "Pascal"] {
            tapWhenHittable(app.buttons["\(player)-bid-0"], in: app)
            tapWhenHittable(app.buttons["\(player)-tricks-0"], in: app)
        }

        tapWhenHittable(app.buttons["next-round-button"], in: app)
        XCTAssertTrue(app.staticTexts["ROUND 2 OF 20"].waitForExistence(timeout: 3))
        tapWhenHittable(app.buttons["View and edit previous rounds"], in: app)
        XCTAssertTrue(app.navigationBars["Edit Rounds"].waitForExistence(timeout: 3))
    }

    func testCascadiaSubtotalAndCompletion() throws {
        let app = launchApp()
        openGame("cascadia", players: ["Mara"], in: app)
        XCTAssertTrue(app.navigationBars["Cascadia"].waitForExistence(timeout: 4))

        tapWhenHittable(app.buttons["Mara-bears-plus"], in: app)
        tapWhenHittable(app.buttons["Mara-bears-plus"], in: app)
        XCTAssertTrue(app.staticTexts["Wildlife subtotal, 2"].waitForExistence(timeout: 2))

        tapWhenHittable(app.buttons["finish-game-button"], in: app)
        XCTAssertTrue(app.staticTexts["Mara wins!"].waitForExistence(timeout: 4))
        XCTAssertTrue(app.staticTexts["Final ranking"].exists)
    }

    private func launchApp() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing-reset"]
        app.launch()
        return app
    }

    private func tabButton(named name: String, in app: XCUIApplication) -> XCUIElement {
        app.buttons.matching(NSPredicate(format: "label == %@", name)).firstMatch
    }

    private func openGame(_ id: String, players: [String], in app: XCUIApplication) {
        app.buttons["start-game-button"].tap()
        let game = app.buttons["choose-game-\(id)"]
        XCTAssertTrue(game.waitForExistence(timeout: 3))
        game.tap()
        for name in players {
            let field = app.textFields["new-player-field"]
            XCTAssertTrue(field.waitForExistence(timeout: 2))
            field.tap()
            field.typeText(name)
            app.buttons["Add"].tap()
        }
        let start = app.buttons["start-scoring-button"]
        XCTAssertTrue(start.isEnabled)
        tapWhenHittable(start, in: app)
    }

    private func tapWhenHittable(_ element: XCUIElement, in app: XCUIApplication) {
        for _ in 0..<6 where !element.isHittable {
            app.swipeUp()
        }
        XCTAssertTrue(element.isHittable)
        element.tap()
    }
}
