import Foundation

extension FitnessStore {
    var wellness: WellnessData { data.wellness ?? WellnessData() }

    private func changeWellness(_ change: (inout WellnessData) throws -> Void) throws {
        try commit {
            var next = $0.wellness ?? WellnessData()
            try change(&next)
            $0.wellness = next
        }
    }

    func saveFood(_ food: FoodItem) throws {
        try food.validate()
        try changeWellness { value in
            if let index = value.foods.firstIndex(where: { $0.id == food.id }) { value.foods[index] = food }
            else { value.foods.append(food) }
        }
    }

    func deleteFood(id: UUID) throws { try changeWellness { $0.foods.removeAll { $0.id == id } } }

    func logFood(_ food: FoodItem, servings: Double, meal: Meal, date: Date = Date()) throws {
        try food.validate()
        try validateServings(servings)
        try changeWellness { $0.logs.append(FoodLog(food: food, servings: servings, meal: meal, date: date)) }
    }

    func deleteFoodLog(id: UUID) throws { try changeWellness { $0.logs.removeAll { $0.id == id } } }

    func foodLogs(on date: Date, calendar: Calendar = .current) -> [FoodLog] {
        wellness.logs.filter { calendar.isDate($0.date, inSameDayAs: date) }.sorted { $0.date < $1.date }
    }

    func intake(on date: Date, calendar: Calendar = .current) -> NutritionValues {
        foodLogs(on: date, calendar: calendar).reduce(NutritionValues()) { $0 + $1.nutrition }
    }

    func saveTargets(_ targets: NutritionValues) throws {
        try targets.validate()
        guard targets.calories > 0 else { throw FitnessError.invalid("每日热量目标需大于 0。") }
        try changeWellness { $0.targets = targets }
    }

    func saveProfile(_ profile: BodyProfile) throws {
        guard profile.age == nil || (18...120).contains(profile.age!),
              profile.height == nil || (profile.height!.isFinite && (100...250).contains(profile.height!)),
              profile.targetWeight == nil || (profile.targetWeight!.isFinite && profile.targetWeight! > 0 && profile.targetWeight! <= 500) else {
            throw FitnessError.invalid("年龄支持 18-120 岁，身高 100-250 cm，目标体重大于 0 且不超过 500 kg；可留空。")
        }
        try changeWellness { $0.profile = profile }
    }

    private func validateServings(_ value: Double) throws {
        guard value.isFinite, value > 0, value <= 1000 else {
            throw FitnessError.invalid("份数需大于 0 且不超过 1000，可使用小数。")
        }
    }

    func saveMealPlan(_ plan: MealPlan) throws {
        guard !plan.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, !plan.items.isEmpty else {
            throw FitnessError.invalid("请填写餐单名称并添加至少一项食物。")
        }
        for item in plan.items { try item.food.validate(); try validateServings(item.servings) }
        try changeWellness {
            if let index = $0.mealPlans.firstIndex(where: { $0.id == plan.id }) { $0.mealPlans[index] = plan }
            else { $0.mealPlans.append(plan) }
            if $0.activeMealPlanID == plan.id { $0.purchasedIDs = [] }
        }
    }

    var activeMealPlan: MealPlan? { wellness.mealPlans.first { $0.id == wellness.activeMealPlanID } }

    func activateMealPlan(id: UUID) throws {
        guard wellness.mealPlans.contains(where: { $0.id == id }) else { throw FitnessError.invalid("餐单不存在。") }
        try changeWellness { $0.activeMealPlanID = id; $0.purchasedIDs = [] }
    }

    func deleteMealPlan(id: UUID) throws {
        try changeWellness {
            $0.mealPlans.removeAll { $0.id == id }
            if $0.activeMealPlanID == id { $0.activeMealPlanID = nil; $0.purchasedIDs = [] }
        }
    }

    func logMeal(planID: UUID, meal: Meal, date: Date = Date()) throws {
        guard let plan = wellness.mealPlans.first(where: { $0.id == planID }) else {
            throw FitnessError.invalid("餐单不存在。")
        }
        let items = plan.items.filter { $0.meal == meal }
        guard !items.isEmpty else { throw FitnessError.invalid("这餐还没有安排食物。") }
        try changeWellness { data in
            data.logs += items.map { FoodLog(food: $0.food, servings: $0.servings, meal: meal, date: date) }
        }
    }

    func shoppingList(days: Int) -> [ShoppingItem] {
        guard let plan = activeMealPlan, (1...30).contains(days) else { return [] }
        var result: [ShoppingItem] = []
        for item in plan.items {
            if let index = result.firstIndex(where: { $0.food.id == item.food.id }) {
                result[index].servings += item.servings * Double(days)
            } else { result.append(ShoppingItem(food: item.food, servings: item.servings * Double(days))) }
        }
        return result
    }

    func togglePurchased(id: UUID) throws {
        try changeWellness {
            if $0.purchasedIDs.contains(id) { $0.purchasedIDs.removeAll { $0 == id } }
            else { $0.purchasedIDs.append(id) }
        }
    }

    func saveSchedule(_ schedule: TrainingSchedule) throws {
        guard (1...14).contains(schedule.days.count), schedule.days.allSatisfy({ day in
            day.templateID == nil || data.templates.contains { $0.id == day.templateID }
        }) else { throw FitnessError.invalid("周期支持 1-14 天，请选择有效的训练模板或休息日。") }
        try changeWellness { $0.schedule = schedule }
    }

    func scheduleIndex(on date: Date, calendar: Calendar = .current) -> Int? {
        guard let schedule = wellness.schedule, !schedule.days.isEmpty,
              let difference = calendar.dateComponents([.day], from: calendar.startOfDay(for: schedule.startDate),
                                                        to: calendar.startOfDay(for: date)).day, difference >= 0 else { return nil }
        return difference % schedule.days.count
    }

    func scheduledTemplate(on date: Date, calendar: Calendar = .current) -> WorkoutTemplate? {
        guard let index = scheduleIndex(on: date, calendar: calendar),
              let id = wellness.schedule?.days[index].templateID else { return nil }
        return data.templates.first { $0.id == id }
    }

    func setRestEnd(_ date: Date?) throws {
        guard var draft = data.draft else { throw FitnessError.invalid("请先开始训练。") }
        draft.restUntil = date
        try updateDraft(draft)
    }

    func saveExerciseLink(id: String, link: String) throws {
        let trimmed = link.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            guard let url = URL(string: trimmed), url.scheme == "https", url.host != nil else {
                throw FitnessError.invalid("请输入有效的 HTTPS 演示链接，或留空移除。")
            }
        }
        try changeWellness { $0.exerciseLinks[id] = trimmed.isEmpty ? nil : trimmed }
    }
}
