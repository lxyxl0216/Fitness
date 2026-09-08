import XCTest
@testable import FitnessCore

final class FitnessCoreTests: XCTestCase {
    private func store() throws -> FitnessStore {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        addTeardownBlock { try? FileManager.default.removeItem(at: directory) }
        return try FitnessStore(url: directory.appendingPathComponent("fitness.json"))
    }

    func testCompletedSetsRejectInvalidInputsButAllowBodyweight() throws {
        for weight in ["-1", "nan", "inf", "", "abc", "1001"] {
            XCTAssertThrowsError(try TrainingSet(weight: weight, reps: "10", isCompleted: true).validate())
        }
        for reps in ["0", "-1", "2.5", "", "abc", "1000"] {
            XCTAssertThrowsError(try TrainingSet(weight: "20", reps: reps, isCompleted: true).validate())
        }
        XCTAssertNoThrow(try TrainingSet(weight: "0", reps: "10", isCompleted: true).validate())
        XCTAssertNoThrow(try TrainingSet(weight: "2,5", reps: "10", isCompleted: true).validate())
    }

    func testDraftRestoresAcrossStoreInstances() throws {
        let first = try store()
        try first.start(template: first.data.templates[0])
        var draft = try XCTUnwrap(first.data.draft)
        draft.exercises[0].sets[0].weight = "42.5"
        try first.updateDraft(draft)
        let reloaded = try FitnessStore(url: first.url)
        XCTAssertEqual(reloaded.data.draft?.exercises[0].sets[0].weight, "42.5")
        XCTAssertThrowsError(try first.start(template: first.data.templates[1]))
    }

    func testFinishKeepsOnlyCompletedSetsAndComputesVolume() throws {
        let store = try store()
        try store.start(template: store.data.templates[0])
        var draft = try XCTUnwrap(store.data.draft)
        draft.exercises[0].sets = [
            TrainingSet(weight: "60", reps: "10", isCompleted: true),
            TrainingSet(weight: "62.5", reps: "8", isCompleted: true),
            TrainingSet(weight: "999", reps: "99")
        ]
        try store.updateDraft(draft)
        try store.finish()
        XCTAssertNil(store.data.draft)
        let workout = try XCTUnwrap(store.data.workouts.first)
        XCTAssertEqual(workout.completedSetCount, 2)
        XCTAssertEqual(workout.volume, 1100)
        XCTAssertEqual(workout.exercises.count, 1)
        XCTAssertEqual(workout.exercises[0].sets.count, 2)
        XCTAssertNotNil(workout.finishedAt)
        let reloaded = try FitnessStore(url: store.url)
        XCTAssertEqual(reloaded.data.workouts.first?.volume, 1100)
        XCTAssertNil(reloaded.data.draft)
    }

    func testCannotFinishEmptyTrainingOrSaveInvalidCompletedSet() throws {
        let store = try store()
        try store.start(template: store.data.templates[0])
        XCTAssertThrowsError(try store.finish())
        var draft = try XCTUnwrap(store.data.draft)
        draft.exercises[0].sets[0] = TrainingSet(weight: "-1", reps: "10", isCompleted: true)
        XCTAssertThrowsError(try store.updateDraft(draft))
        XCTAssertEqual(store.data.draft?.completedSetCount, 0)
        XCTAssertTrue(store.data.workouts.isEmpty)
    }

    func testDeletingTemplateDoesNotChangeActiveTraining() throws {
        let store = try store()
        let template = store.data.templates[0]
        try store.start(template: template)
        try store.deleteTemplate(id: template.id)
        XCTAssertEqual(store.data.draft?.name, template.name)
        XCTAssertEqual(store.data.draft?.exercises.count, template.exerciseIDs.count)
        let reopened = try FitnessStore(url: store.url)
        XCTAssertFalse(reopened.data.templates.contains { $0.id == template.id })
    }

    func testTemplateValidationAndEditing() throws {
        let store = try store()
        XCTAssertThrowsError(try store.saveTemplate(WorkoutTemplate(name: "  ", exerciseIDs: ["bench"])))
        XCTAssertThrowsError(try store.saveTemplate(WorkoutTemplate(name: "空计划", exerciseIDs: [])))
        XCTAssertThrowsError(try store.saveTemplate(WorkoutTemplate(name: "未知动作", exerciseIDs: ["missing"])))
        var template = store.data.templates[0]
        template.name = "  自定义推日  "
        try store.saveTemplate(template)
        XCTAssertEqual(store.data.templates.count, 3)
        XCTAssertEqual(store.data.templates[0].name, "自定义推日")
    }

    func testBodyValidationAndPersistence() throws {
        let store = try store()
        for value in [0.0, -1, .nan, .infinity, 501] {
            XCTAssertThrowsError(try store.saveBody(BodyRecord(date: Date(), weight: value)))
        }
        XCTAssertThrowsError(try store.saveBody(BodyRecord(date: Date(), weight: 72, bodyFat: 101)))
        XCTAssertThrowsError(try store.saveBody(BodyRecord(date: Date(), weight: 72, waist: -1)))
        let record = BodyRecord(date: Date(), weight: 72.4, bodyFat: 18, waist: 80)
        try store.saveBody(record)
        XCTAssertEqual(try FitnessStore(url: store.url).data.bodyRecords.first?.weight, 72.4)
        try store.deleteBody(id: record.id)
        XCTAssertTrue(try FitnessStore(url: store.url).data.bodyRecords.isEmpty)
    }

    func testFailedWriteDoesNotMutateMemory() throws {
        let store = try store()
        try FileManager.default.createDirectory(at: store.url, withIntermediateDirectories: true)
        XCTAssertThrowsError(try store.start(template: store.data.templates[0]))
        XCTAssertNil(store.data.draft)
    }

    func testCorruptFileIsNotOverwritten() throws {
        let store = try store()
        try FileManager.default.createDirectory(at: store.url.deletingLastPathComponent(), withIntermediateDirectories: true)
        let bytes = Data("broken data".utf8)
        try bytes.write(to: store.url)
        XCTAssertThrowsError(try FitnessStore(url: store.url))
        XCTAssertEqual(try Data(contentsOf: store.url), bytes)
    }

    func testPreviousPerformanceSurvivesTemplateChangesAndExcludesDraft() throws {
        let store = try store()
        let template = store.data.templates[0]
        try store.start(template: template)
        var draft = try XCTUnwrap(store.data.draft)
        let exerciseID = draft.exercises[0].exerciseID
        draft.exercises[0].sets[0] = TrainingSet(weight: "50", reps: "8", isCompleted: true)
        try store.updateDraft(draft)
        XCTAssertNil(store.previousSets(for: exerciseID))
        try store.finish()
        try store.start(template: template)
        XCTAssertEqual(store.previousSets(for: exerciseID)?.first?.weight, "50")
        XCTAssertEqual(store.data.draft?.completedSetCount, 0)
        try store.discardDraft()
        let id = try XCTUnwrap(store.data.workouts.first?.id)
        try store.deleteWorkout(id: id)
        XCTAssertNil(store.previousSets(for: exerciseID))
        XCTAssertTrue(try FitnessStore(url: store.url).data.workouts.isEmpty)
    }
}
