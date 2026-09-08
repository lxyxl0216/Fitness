import XCTest

final class FitnessUITests: XCTestCase {
    func testTrainingAndBodyRecordsSurviveRelaunch() throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments += ["-AppleLanguages", "(zh-Hans)", "-AppleLocale", "zh_CN"]
        app.launch()
        app.tabBars.buttons["训练"].tap()
        XCTAssertTrue(app.buttons["start-bench"].waitForExistence(timeout: 15))
        reveal(app.buttons["start-bench"], in: app)
        capture("01-今日")
        app.buttons["start-bench"].tap()
        let weight = app.textFields["weight-bench-0"]
        XCTAssertTrue(weight.waitForExistence(timeout: 10))
        weight.tap()
        weight.typeText(XCUIKeyboardKey.delete.rawValue + "60")
        app.buttons["complete-bench-0"].tap()
        capture("02-训练记录")
        app.buttons["pauseTraining"].tap()
        app.terminate()
        app.launch()
        XCTAssertTrue(app.buttons["resumeTraining"].waitForExistence(timeout: 15))
        reveal(app.buttons["resumeTraining"], in: app)
        app.buttons["resumeTraining"].tap()
        XCTAssertTrue(app.buttons["finishTraining"].waitForExistence(timeout: 10))
        app.buttons["finishTraining"].tap()
        app.buttons["保存到历史"].tap()
        app.tabBars.buttons["训练"].tap()
        app.segmentedControls.buttons["记录"].tap()
        XCTAssertTrue(app.buttons["historyWorkout"].firstMatch.waitForExistence(timeout: 10))
        app.buttons["historyWorkout"].firstMatch.tap()
        XCTAssertTrue(app.staticTexts["60 kg × 10 次"].waitForExistence(timeout: 5))
        capture("03-历史详情")
        app.tabBars.buttons["我的"].tap()
        app.buttons["bodyData"].tap()
        app.buttons["addBodyRecord"].tap()
        let bodyWeight = app.textFields["bodyWeight"]
        XCTAssertTrue(bodyWeight.waitForExistence(timeout: 10))
        bodyWeight.tap()
        bodyWeight.typeText("72.4")
        app.buttons["saveBodyRecord"].tap()
        XCTAssertTrue(app.buttons["bodyRecord"].firstMatch.waitForExistence(timeout: 10))
        capture("04-身体数据")
        app.terminate()
        app.launch()
        app.tabBars.buttons["我的"].tap()
        app.buttons["bodyData"].tap()
        XCTAssertTrue(app.buttons["bodyRecord"].firstMatch.waitForExistence(timeout: 10))
        app.tabBars.buttons["训练"].tap()
        app.segmentedControls.buttons["记录"].tap()
        XCTAssertTrue(app.buttons["historyWorkout"].firstMatch.waitForExistence(timeout: 10))
        app.segmentedControls.buttons["计划"].tap()
        reveal(app.buttons["manageTemplates"], in: app)
        app.buttons["manageTemplates"].tap()
        app.buttons["新建计划"].tap()
        let name = app.textFields["templateName"]
        XCTAssertTrue(name.waitForExistence(timeout: 10))
        name.tap()
        name.typeText("自定义训练")
        reveal(app.buttons["exercise-bench"], in: app)
        app.buttons["exercise-bench"].tap()
        app.buttons["saveTemplate"].tap()
        XCTAssertTrue(app.staticTexts["自定义训练"].waitForExistence(timeout: 10))
        capture("05-训练计划")
    }

    func testNutritionWorkflowSurvivesRelaunch() throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments += ["-AppleLanguages", "(zh-Hans)", "-AppleLocale", "zh_CN"]
        app.launch()
        XCTAssertTrue(app.tabBars.buttons["我的"].waitForExistence(timeout: 15))
        app.tabBars.buttons["我的"].tap()
        reveal(app.buttons["foodLibrary"], in: app)
        app.buttons["foodLibrary"].tap()
        app.buttons["addFood"].tap()
        enter("Test yogurt", field: "foodName", in: app)
        enter("120", field: "foodCalories", in: app)
        enter("10", field: "foodProtein", in: app)
        enter("15", field: "foodCarbs", in: app)
        enter("2", field: "foodFat", in: app)
        app.buttons["saveFood"].tap()
        XCTAssertTrue(app.staticTexts["Test yogurt"].waitForExistence(timeout: 10))
        app.tabBars.buttons["今日"].tap()
        reveal(app.buttons["logFood"], in: app)
        app.buttons["logFood"].tap()
        reveal(app.buttons["chooseFood-Test yogurt"], in: app)
        app.buttons["chooseFood-Test yogurt"].tap()
        app.buttons["saveFoodLog"].tap()
        XCTAssertTrue(app.staticTexts["120"].waitForExistence(timeout: 10))
        capture("06-今日营养")
        app.terminate()
        app.launch()
        XCTAssertTrue(app.staticTexts["120"].waitForExistence(timeout: 10))
        app.tabBars.buttons["趋势"].tap()
        XCTAssertTrue(app.staticTexts["120 kcal"].waitForExistence(timeout: 10))
        capture("07-营养趋势")
        app.tabBars.buttons["训练"].tap()
        app.segmentedControls.buttons["动作"].tap()
        XCTAssertTrue(app.staticTexts["杠铃卧推"].waitForExistence(timeout: 10))
        capture("08-动作库")
        app.tabBars.buttons["我的"].tap()
        capture("09-我的")
    }

    private func enter(_ value: String, field id: String, in app: XCUIApplication) {
        let field = app.textFields[id]
        reveal(field, in: app)
        field.tap()
        field.typeText(value)
    }

    private func reveal(_ element: XCUIElement, in app: XCUIApplication) {
        for _ in 0..<6 {
            if element.exists && element.isHittable { return }
            app.swipeUp()
        }
        XCTAssertTrue(element.exists && element.isHittable)
    }

    private func capture(_ name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
