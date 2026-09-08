import Foundation

enum FitnessError: LocalizedError {
    case invalid(String)

    var errorDescription: String? {
        switch self {
        case .invalid(let message): return message
        }
    }
}

enum InputNumber {
    static func decimal(_ text: String) -> Double? {
        Double(text.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: ",", with: "."))
    }
}

struct TrainingSet: Codable, Identifiable, Equatable {
    var id = UUID()
    var weight = "0"
    var reps = "10"
    var isCompleted = false
    var rpe: Double?

    func validate() throws {
        if let rpe, !rpe.isFinite || !(1...10).contains(rpe) {
            throw FitnessError.invalid("RPE 需为 1-10，或不填写。")
        }
        guard let kg = InputNumber.decimal(weight), kg.isFinite, (0...1000).contains(kg),
              let count = Int(reps.trimmingCharacters(in: .whitespaces)), (1...999).contains(count) else {
            throw FitnessError.invalid("重量需为 0-1000 kg，次数需为 1-999 的整数。自重动作重量填 0。")
        }
    }

    var volume: Double {
        guard isCompleted, (try? validate()) != nil else { return 0 }
        return (InputNumber.decimal(weight) ?? 0) * Double(Int(reps.trimmingCharacters(in: .whitespaces)) ?? 0)
    }
}

struct WorkoutTemplate: Codable, Identifiable, Equatable {
    var id = UUID()
    var name: String
    var exerciseIDs: [String]
    var setCount = 3
    var prescriptions: [String: ExercisePrescription]?

    func prescription(for id: String) -> ExercisePrescription {
        prescriptions?[id] ?? ExercisePrescription(reps: Array(repeating: 10, count: setCount))
    }

    var plannedSetCount: Int { exerciseIDs.reduce(0) { $0 + prescription(for: $1).reps.count } }
}

struct LoggedExercise: Codable, Identifiable, Equatable {
    var id = UUID()
    var exerciseID: String
    var name: String
    var sets: [TrainingSet]
    var restSeconds: Int?
    var targetRPE: Double?
}

struct Workout: Codable, Identifiable, Equatable {
    var id = UUID()
    var name: String
    var startedAt = Date()
    var finishedAt: Date?
    var exercises: [LoggedExercise]
    var restUntil: Date?

    var completedSetCount: Int {
        exercises.reduce(0) { $0 + $1.sets.filter(\.isCompleted).count }
    }

    var volume: Double {
        exercises.reduce(0) { $0 + $1.sets.reduce(0) { $0 + $1.volume } }
    }

    var durationMinutes: Int {
        max(1, Int((finishedAt ?? Date()).timeIntervalSince(startedAt) / 60))
    }
}

struct BodyRecord: Codable, Identifiable, Equatable {
    var id = UUID()
    var date: Date
    var weight: Double
    var bodyFat: Double?
    var waist: Double?

    func validate() throws {
        guard weight.isFinite, weight > 0, weight <= 500 else {
            throw FitnessError.invalid("请输入大于 0 且不超过 500 kg 的体重。")
        }
        if let bodyFat, !bodyFat.isFinite || bodyFat <= 0 || bodyFat > 100 {
            throw FitnessError.invalid("体脂率需大于 0 且不超过 100%。")
        }
        if let waist, !waist.isFinite || waist <= 0 || waist > 300 {
            throw FitnessError.invalid("腰围需大于 0 且不超过 300 cm。")
        }
    }
}

struct FitnessData: Codable {
    var version = 1
    var templates = ExerciseCatalog.templates
    var workouts: [Workout] = []
    var bodyRecords: [BodyRecord] = []
    var draft: Workout?
    var wellness: WellnessData?
}
