import XCTest

final class FitnessUITests: XCTestCase {
    func testTrainingAndBodyRecordsSurviveRelaunch() throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments += ["-AppleLanguages", "(zh-Hans)", "-AppleLocale", "zh_CN"]
        app.launch()
        XCTAssertTrue(app.buttons["start-bench"].waitForExistence(timeout: 15))
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
        app.buttons["resumeTraining"].tap()
        XCTAssertTrue(app.buttons["finishTraining"].waitForExistence(timeout: 10))
        app.buttons["finishTraining"].tap()
        app.buttons["保存到历史"].tap()
        app.tabBars.buttons["历史"].tap()
        XCTAssertTrue(app.buttons["historyWorkout"].firstMatch.waitForExistence(timeout: 10))
        app.buttons["historyWorkout"].firstMatch.tap()
        XCTAssertTrue(app.staticTexts["60 kg × 10 次"].waitForExistence(timeout: 5))
        capture("03-历史详情")
        app.tabBars.buttons["身体"].tap()
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
        app.tabBars.buttons["身体"].tap()
        XCTAssertTrue(app.buttons["bodyRecord"].firstMatch.waitForExistence(timeout: 10))
        app.tabBars.buttons["历史"].tap()
        XCTAssertTrue(app.buttons["historyWorkout"].firstMatch.waitForExistence(timeout: 10))
        app.tabBars.buttons["计划"].tap()
        app.buttons["新建计划"].tap()
        let name = app.textFields["templateName"]
        XCTAssertTrue(name.waitForExistence(timeout: 10))
        name.tap()
        name.typeText("自定义训练")
        app.buttons["exercise-bench"].tap()
        app.buttons["saveTemplate"].tap()
        XCTAssertTrue(app.staticTexts["自定义训练"].waitForExistence(timeout: 10))
        capture("05-训练计划")
    }

    private func capture(_ name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
