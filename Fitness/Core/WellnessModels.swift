import Foundation

struct NutritionValues: Codable, Equatable {
    var calories: Double = 0
    var protein: Double = 0
    var carbs: Double = 0
    var fat: Double = 0
    var sodium: Double?

    func validate() throws {
        guard [calories, protein, carbs, fat].allSatisfy({ $0.isFinite && (0...100000).contains($0) }),
              sodium == nil || (sodium!.isFinite && (0...100000).contains(sodium!)) else {
            throw FitnessError.invalid("营养数值需为 0-100000 之间的有效数字。")
        }
    }

    func scaled(_ factor: Double) -> NutritionValues {
        NutritionValues(calories: calories * factor, protein: protein * factor, carbs: carbs * factor,
                        fat: fat * factor, sodium: sodium.map { $0 * factor })
    }

    static func + (lhs: Self, rhs: Self) -> Self {
        NutritionValues(calories: lhs.calories + rhs.calories, protein: lhs.protein + rhs.protein,
                        carbs: lhs.carbs + rhs.carbs, fat: lhs.fat + rhs.fat,
                        sodium: lhs.sodium == nil && rhs.sodium == nil ? nil : (lhs.sodium ?? 0) + (rhs.sodium ?? 0))
    }
}

enum Meal: String, Codable, CaseIterable, Identifiable {
    case breakfast = "早餐", lunch = "午餐", dinner = "晚餐", snack = "加餐"
    var id: String { rawValue }
    var symbol: String {
        switch self {
        case .breakfast: return "sunrise"
        case .lunch: return "sun.max"
        case .dinner: return "moon"
        case .snack: return "cup.and.saucer"
        }
    }
}

struct FoodItem: Codable, Identifiable, Equatable {
    var id = UUID()
    var name: String
    var servingName = "100 g"
    var nutrition = NutritionValues()
    var isSupplement = false
    var notes = ""

    func validate() throws {
        guard !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              !servingName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw FitnessError.invalid("请填写名称和每份大小。")
        }
        try nutrition.validate()
    }
}

struct FoodLog: Codable, Identifiable {
    var id = UUID()
    var food: FoodItem
    var servings: Double
    var meal: Meal
    var date: Date
    var nutrition: NutritionValues { food.nutrition.scaled(servings) }
}

struct PlannedFood: Codable, Identifiable, Equatable {
    var id = UUID()
    var food: FoodItem
    var servings: Double
    var meal: Meal
}

struct MealPlan: Codable, Identifiable, Equatable {
    var id = UUID()
    var name: String
    var items: [PlannedFood] = []
    var instructions = ""
    var nutrition: NutritionValues { items.reduce(NutritionValues()) { $0 + $1.food.nutrition.scaled($1.servings) } }
}

struct ShoppingItem: Identifiable {
    var id: UUID { food.id }
    var food: FoodItem
    var servings: Double
}

enum ProfileSex: String, Codable, CaseIterable, Identifiable {
    case unspecified = "不填写", male = "男", female = "女"
    var id: String { rawValue }
}

struct BodyProfile: Codable, Equatable {
    var name = ""
    var age: Int?
    var height: Double?
    var sex: ProfileSex = .unspecified
    var targetWeight: Double?

    func restingEnergy(weight: Double) -> Double? {
        guard let age, let height, sex != .unspecified, weight > 0, weight.isFinite else { return nil }
        // Mifflin-St Jeor, AJCN 1990, PMID 2305711. Estimate, not a daily intake target.
        return 10 * weight + 6.25 * height - 5 * Double(age) + (sex == .male ? 5 : -161)
    }
}

struct ExercisePrescription: Codable, Equatable {
    var reps: [Int] = [10, 10, 10]
    var restSeconds = 90
    var targetRPE: Double?

    func validate() throws {
        guard !reps.isEmpty, reps.count <= 20, reps.allSatisfy({ (1...999).contains($0) }),
              (0...1800).contains(restSeconds),
              targetRPE == nil || (targetRPE!.isFinite && (1...10).contains(targetRPE!)) else {
            throw FitnessError.invalid("每个动作需 1-20 组、每组 1-999 次，休息 0-1800 秒，RPE 为 1-10 或留空。")
        }
    }
}

struct ScheduleDay: Codable, Identifiable, Equatable {
    var id = UUID()
    var templateID: UUID?
}

struct TrainingSchedule: Codable, Equatable {
    var startDate: Date
    var days: [ScheduleDay]
}

struct WellnessData: Codable {
    var foods: [FoodItem] = []
    var logs: [FoodLog] = []
    var mealPlans: [MealPlan] = []
    var activeMealPlanID: UUID?
    var targets: NutritionValues?
    var profile = BodyProfile()
    var schedule: TrainingSchedule?
    var purchasedIDs: [UUID] = []
    var exerciseLinks: [String: String] = [:]
}
