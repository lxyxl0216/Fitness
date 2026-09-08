import XCTest
@testable import FitnessCore

final class WellnessTests: XCTestCase {
    private func store() throws -> FitnessStore {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        addTeardownBlock { try? FileManager.default.removeItem(at: folder) }
        return try FitnessStore(url: folder.appendingPathComponent("fitness.json"))
    }

    private var food: FoodItem {
        FoodItem(name: "测试食品", servingName: "100 g", nutrition: NutritionValues(calories: 120, protein: 10, carbs: 15, fat: 2))
    }

    func testLegacyFileKeepsRecordsAndAddsEmptyWellness() throws {
        let store = try store()
        let bytes = Data("{\"version\":1,\"templates\":[],\"workouts\":[],\"bodyRecords\":[]}".utf8)
        try FileManager.default.createDirectory(at: store.url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try bytes.write(to: store.url)
        let reopened = try FitnessStore(url: store.url)
        XCTAssertTrue(reopened.wellness.foods.isEmpty)
        XCTAssertNil(reopened.wellness.targets)
        XCTAssertTrue(reopened.data.templates.isEmpty)
        try reopened.saveFood(food)
        XCTAssertEqual(try FitnessStore(url: store.url).wellness.foods.count, 1)
    }

    func testFoodPortionsAndDateBoundaries() throws {
        let store = try store()
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let day = Date(timeIntervalSince1970: 1_788_825_600)
        try store.logFood(food, servings: 1.5, meal: .breakfast, date: day)
        try store.logFood(food, servings: 1, meal: .lunch, date: day.addingTimeInterval(86400))
        let total = store.intake(on: day, calendar: calendar)
        XCTAssertEqual(total.calories, 180)
        XCTAssertEqual(total.protein, 15)
        XCTAssertEqual(total.carbs, 22.5)
        XCTAssertEqual(total.fat, 3)
    }

    func testEditingOrDeletingFoodDoesNotRewriteLogs() throws {
        let store = try store()
        var item = food
        try store.saveFood(item)
        try store.logFood(item, servings: 2, meal: .dinner)
        item.nutrition.calories = 999
        try store.saveFood(item)
        try store.deleteFood(id: item.id)
        let reopened = try FitnessStore(url: store.url)
        XCTAssertEqual(reopened.wellness.logs.first?.nutrition.calories, 240)
        XCTAssertEqual(reopened.wellness.logs.first?.food.name, "测试食品")
        let id = try XCTUnwrap(reopened.wellness.logs.first?.id)
        try reopened.deleteFoodLog(id: id)
        XCTAssertTrue(reopened.wellness.logs.isEmpty)
    }

    func testFoodValidationRejectsNonfiniteAndNegativeValues() throws {
        let store = try store()
        for value in [-1.0, Double.nan, Double.infinity] {
            var item = food
            item.nutrition.protein = value
            XCTAssertThrowsError(try store.saveFood(item))
        }
        for servings in [0.0, -1, Double.nan, Double.infinity] {
            XCTAssertThrowsError(try store.logFood(food, servings: servings, meal: .snack))
        }
        XCTAssertTrue(store.wellness.logs.isEmpty)
    }

    func testMealPlanLogsOnlySelectedMealAndShoppingMergesPortions() throws {
        let store = try store()
        let plan = MealPlan(name: "测试餐单", items: [
            PlannedFood(food: food, servings: 1, meal: .breakfast),
            PlannedFood(food: food, servings: 2, meal: .dinner)
        ])
        try store.saveMealPlan(plan)
        try store.activateMealPlan(id: plan.id)
        try store.logMeal(planID: plan.id, meal: .breakfast)
        XCTAssertEqual(store.wellness.logs.count, 1)
        XCTAssertEqual(store.wellness.logs[0].nutrition.calories, 120)
        XCTAssertEqual(store.shoppingList(days: 2).first?.servings, 6)
        XCTAssertEqual(store.shoppingList(days: 2).count, 1)
    }

    func testScheduleRepeatsAndPreservesRestDays() throws {
        let store = try store()
        let start = Date(timeIntervalSince1970: 1_788_825_600)
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let template = store.data.templates[0]
        try store.saveSchedule(TrainingSchedule(startDate: start, days: [
            ScheduleDay(templateID: template.id), ScheduleDay(templateID: nil)
        ]))
        XCTAssertEqual(store.scheduledTemplate(on: start, calendar: calendar)?.id, template.id)
        XCTAssertNil(store.scheduledTemplate(on: start.addingTimeInterval(86400), calendar: calendar))
        XCTAssertEqual(store.scheduledTemplate(on: start.addingTimeInterval(172800), calendar: calendar)?.id, template.id)
        XCTAssertNil(store.scheduledTemplate(on: start.addingTimeInterval(-86400), calendar: calendar))
    }

    func testPrescriptionAndRestTimerSurviveRelaunch() throws {
        let store = try store()
        var template = store.data.templates[0]
        template.prescriptions = ["bench": ExercisePrescription(reps: [10, 10, 8], restSeconds: 90, targetRPE: 8)]
        try store.saveTemplate(template)
        try store.start(template: template)
        XCTAssertEqual(store.data.draft?.exercises[0].sets.map(\.reps), ["10", "10", "8"])
        XCTAssertEqual(store.data.draft?.exercises[0].restSeconds, 90)
        let end = Date().addingTimeInterval(90)
        try store.setRestEnd(end)
        XCTAssertEqual(try FitnessStore(url: store.url).data.draft?.restUntil, end)
    }

    func testInvalidPrescriptionCannotBeSaved() throws {
        let store = try store()
        var template = store.data.templates[0]
        template.prescriptions = ["bench": ExercisePrescription(reps: [0], restSeconds: -1, targetRPE: 11)]
        XCTAssertThrowsError(try store.saveTemplate(template))
    }

    func testTargetsAndProfileRemainOptionalAndValidate() throws {
        let store = try store()
        XCTAssertNil(store.wellness.targets)
        XCTAssertThrowsError(try store.saveTargets(NutritionValues(calories: -1, protein: 10, carbs: 10, fat: 10)))
        try store.saveTargets(NutritionValues(calories: 2000, protein: 120, carbs: 240, fat: 60))
        let profile = BodyProfile(name: "我的档案", age: 30, height: 175, sex: .male, targetWeight: 70)
        try store.saveProfile(profile)
        XCTAssertEqual(profile.restingEnergy(weight: 77), 1718.75)
        XCTAssertEqual(try FitnessStore(url: store.url).wellness.targets?.calories, 2000)
    }
}
