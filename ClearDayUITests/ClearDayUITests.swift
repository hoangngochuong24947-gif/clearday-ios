import XCTest

final class ClearDayUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testCreatesTaskFromPlanPreview() throws {
        let app = XCUIApplication()
        app.launchArguments.append("-ui-testing")
        app.launch()

        app.buttons["addTaskButton"].tap()

        let titleField = app.textFields["composer.title"]
        XCTAssertTrue(titleField.waitForExistence(timeout: 3))
        titleField.tap()
        titleField.typeText("Prepare launch brief")

        app.buttons["composer.previewButton"].tap()
        XCTAssertTrue(app.otherElements["planPreview"].waitForExistence(timeout: 3))

        app.buttons["composer.saveButton"].tap()
        app.tabBars.buttons["Tasks"].tap()

        XCTAssertTrue(app.staticTexts["Prepare launch brief"].waitForExistence(timeout: 3))
    }
}
