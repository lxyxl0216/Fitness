import Foundation
import Observation

@Observable
final class FitnessStore {
    private(set) var data: FitnessData
    let url: URL

    init(url: URL) throws {
        self.url = url
        if FileManager.default.fileExists(atPath: url.path) {
            data = try JSONDecoder().decode(FitnessData.self, from: Data(contentsOf: url))
            guard (1...2).contains(data.version) else {
                throw FitnessError.invalid("此数据文件由更新版本创建，请更新 App 后重试。")
            }
        } else {
            data = FitnessData()
        }
    }

    func commit(_ change: (inout FitnessData) throws -> Void) throws {
        var next = data
        try change(&next)
        next.version = 2
        let encoded = try JSONEncoder().encode(next)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try encoded.write(to: url, options: .atomic)
        data = next
    }

    func start(template: WorkoutTemplate) throws {
        guard data.draft == nil else { throw FitnessError.invalid("请先完成或放弃当前训练。") }
        try validateTemplate(template)
        let exercises = template.exerciseIDs.compactMap { id -> LoggedExercise? in
            guard let exercise = ExerciseCatalog.find(id) else { return nil }
            let previous = previousSets(for: id)
            let prescription = template.prescription(for: id)
            let sets = prescription.reps.enumerated().map { index, reps -> TrainingSet in
                let weight = previous.flatMap { index < $0.count ? $0[index].weight : nil } ?? "0"
                return TrainingSet(weight: weight, reps: String(reps))
            }
            return LoggedExercise(exerciseID: id, name: exercise.name, sets: sets,
                                  restSeconds: prescription.restSeconds, targetRPE: prescription.targetRPE)
        }
        try commit { $0.draft = Workout(name: template.name, exercises: exercises) }
    }

    func updateDraft(_ workout: Workout) throws {
        guard workout.id == data.draft?.id, workout.finishedAt == nil else {
            throw FitnessError.invalid("这次训练已经结束，请返回首页。")
        }
        for exercise in workout.exercises {
            for set in exercise.sets where set.isCompleted { try set.validate() }
        }
        try commit { $0.draft = workout }
    }

    func finish() throws {
        guard var workout = data.draft, workout.completedSetCount > 0 else {
            throw FitnessError.invalid("请至少完成一组后再保存训练。")
        }
        workout.exercises = try workout.exercises.compactMap { exercise in
            var completed = exercise
            completed.sets = exercise.sets.filter(\.isCompleted)
            for set in completed.sets { try set.validate() }
            return completed.sets.isEmpty ? nil : completed
        }
        workout.finishedAt = Date()
        workout.restUntil = nil
        try commit {
            $0.workouts.insert(workout, at: 0)
            $0.draft = nil
        }
    }

    func discardDraft() throws { try commit { $0.draft = nil } }

    func deleteWorkout(id: UUID) throws { try commit { $0.workouts.removeAll { $0.id == id } } }

    func previousSets(for exerciseID: String) -> [TrainingSet]? {
        data.workouts.sorted { ($0.finishedAt ?? $0.startedAt) > ($1.finishedAt ?? $1.startedAt) }
            .lazy.compactMap { $0.exercises.first { $0.exerciseID == exerciseID }?.sets }.first
    }

    private func validateTemplate(_ template: WorkoutTemplate) throws {
        guard !template.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              !template.exerciseIDs.isEmpty, template.exerciseIDs.allSatisfy({ ExerciseCatalog.find($0) != nil }),
              Set(template.exerciseIDs).count == template.exerciseIDs.count,
              (1...10).contains(template.setCount) else {
            throw FitnessError.invalid("请填写计划名称，选择至少一个不重复的动作，默认组数为 1-10。")
        }
        for id in template.exerciseIDs { try template.prescription(for: id).validate() }
    }

    func saveTemplate(_ template: WorkoutTemplate) throws {
        try validateTemplate(template)
        var trimmed = template
        trimmed.name = template.name.trimmingCharacters(in: .whitespacesAndNewlines)
        try commit {
            if let index = $0.templates.firstIndex(where: { $0.id == trimmed.id }) {
                $0.templates[index] = trimmed
            } else {
                $0.templates.append(trimmed)
            }
        }
    }

    func deleteTemplate(id: UUID) throws { try commit { $0.templates.removeAll { $0.id == id } } }

    func saveBody(_ record: BodyRecord) throws {
        try record.validate()
        try commit {
            $0.bodyRecords.removeAll { $0.id == record.id }
            $0.bodyRecords.append(record)
            $0.bodyRecords.sort { $0.date > $1.date }
        }
    }

    func deleteBody(id: UUID) throws { try commit { $0.bodyRecords.removeAll { $0.id == id } } }

    func workoutsThisWeek(now: Date = Date(), calendar: Calendar = .current) -> [Workout] {
        guard let interval = calendar.dateInterval(of: .weekOfYear, for: now) else { return [] }
        return data.workouts.filter { interval.contains($0.finishedAt ?? $0.startedAt) }
    }
}
