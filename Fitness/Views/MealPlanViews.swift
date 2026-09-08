import SwiftUI

struct MealPlansView: View {
    @Environment(FitnessStore.self) private var store
    @State private var editing: MealPlan?
    @State private var deleting: MealPlan?
    @State private var error: String?

    var body: some View {
        List {
            Section {
                Text("把常吃的组合保存成餐单或食谱，填写做法，并选择一份作为当前饮食安排。")
                    .font(.subheadline).foregroundStyle(Palette.muted)
            }
            ForEach(store.wellness.mealPlans) { plan in
                Section {
                    Button { editing = plan } label: {
                        VStack(alignment: .leading, spacing: 7) {
                            Text(plan.name).font(.headline)
                            Text("\(plan.items.count) 项食物 / \(plan.nutrition.calories.fitnessText) kcal")
                                .font(.caption).foregroundStyle(Palette.muted)
                        }.frame(maxWidth: .infinity, alignment: .leading).contentShape(Rectangle())
                    }.buttonStyle(.plain)
                    if store.wellness.activeMealPlanID == plan.id {
                        Label("当前餐单", systemImage: "checkmark.circle.fill").foregroundStyle(Palette.accent)
                    } else {
                        Button("设为当前餐单") {
                            do { try store.activateMealPlan(id: plan.id) } catch { self.error = error.localizedDescription }
                        }.accessibilityIdentifier("activateMealPlan")
                    }
                    Button("删除餐单", role: .destructive) { deleting = plan }
                }
            }
            if store.wellness.mealPlans.isEmpty {
                ContentUnavailableView("常吃的，提前安排", systemImage: "book.closed",
                                       description: Text("先在「我的食物」添加食品，再点 + 组合餐单。"))
            }
        }
        .scrollContentBackground(.hidden).background(Palette.canvas)
        .navigationTitle("餐单与食谱")
        .toolbar { Button { editing = MealPlan(name: "") } label: { Image(systemName: "plus") }.accessibilityIdentifier("addMealPlan") }
        .sheet(item: $editing) { MealPlanEditor(plan: $0) }
        .confirmationDialog("删除餐单？", isPresented: Binding(get: { deleting != nil }, set: { if !$0 { deleting = nil } }), titleVisibility: .visible) {
            Button("删除", role: .destructive) {
                guard let deleting else { return }
                do { try store.deleteMealPlan(id: deleting.id) } catch { self.error = error.localizedDescription }
                self.deleting = nil
            }
        }.fitnessError($error)
    }
}

struct MealPlanEditor: View {
    @Environment(FitnessStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State var plan: MealPlan
    @State private var meal: Meal = .breakfast
    @State private var servings = "1"
    @State private var error: String?

    var body: some View {
        NavigationStack {
            Form {
                Section("餐单名称") { TextField("例如：工作日三餐", text: $plan.name).accessibilityIdentifier("mealPlanName") }
                Section("已安排") {
                    ForEach(plan.items) { item in
                        HStack {
                            Text(item.meal.rawValue).font(.caption).foregroundStyle(Palette.muted)
                            Text(item.food.name)
                            Spacer(); Text("\(item.servings.fitnessText) 份").font(.subheadline)
                        }
                    }.onDelete { plan.items.remove(atOffsets: $0) }
                    Text("合计 \(plan.nutrition.calories.fitnessText) kcal").foregroundStyle(Palette.accent)
                }
                Section("添加食物") {
                    Picker("餐次", selection: $meal) { ForEach(Meal.allCases) { Text($0.rawValue).tag($0) } }
                    ValueField(label: "份数", text: $servings, unit: "份")
                    ForEach(store.wellness.foods) { food in
                        Button {
                            guard let amount = InputNumber.decimal(servings), amount.isFinite, amount > 0, amount <= 1000 else {
                                error = "请填写大于 0 且不超过 1000 的份数。"; return
                            }
                            plan.items.append(PlannedFood(food: food, servings: amount, meal: meal))
                        } label: {
                            HStack { FoodLabel(food: food); Spacer(); Image(systemName: "plus.circle") }.contentShape(Rectangle())
                        }.buttonStyle(.plain).accessibilityIdentifier("planFood-\(food.name)")
                    }
                    if store.wellness.foods.isEmpty { Text("请先在「我的食物」添加食品标签。") }
                }
                Section("做法与备注") { TextField("写下食谱步骤或备餐说明", text: $plan.instructions, axis: .vertical).lineLimit(3...8) }
                if let error { Section { Text(error).foregroundStyle(.red) } }
            }
            .scrollContentBackground(.hidden).background(Palette.canvas)
            .navigationTitle("编辑餐单").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        do { try store.saveMealPlan(plan); dismiss() } catch { self.error = error.localizedDescription }
                    }.accessibilityIdentifier("saveMealPlan")
                }
            }
        }.interactiveDismissDisabled()
    }
}

struct ShoppingView: View {
    @Environment(FitnessStore.self) private var store
    @State private var days = 3
    @State private var error: String?

    var body: some View {
        List {
            Section { Stepper("准备 \(days) 天", value: $days, in: 1...14) }
            if let plan = store.activeMealPlan {
                Section(plan.name) {
                    ForEach(store.shoppingList(days: days)) { item in
                        Button {
                            do { try store.togglePurchased(id: item.id) } catch { self.error = error.localizedDescription }
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: store.wellness.purchasedIDs.contains(item.id) ? "checkmark.circle.fill" : "circle")
                                    .foregroundStyle(Palette.accent)
                                VStack(alignment: .leading, spacing: 5) {
                                    Text(item.food.name).strikethrough(store.wellness.purchasedIDs.contains(item.id))
                                    Text("\(item.servings.fitnessText) 份，每份 \(item.food.servingName)")
                                        .font(.caption).foregroundStyle(Palette.muted)
                                }
                            }.frame(maxWidth: .infinity, alignment: .leading).contentShape(Rectangle())
                        }.buttonStyle(.plain)
                    }
                }
            } else {
                ContentUnavailableView("先选择一份餐单", systemImage: "basket",
                                       description: Text("在「餐单与食谱」设为当前餐单，这里会自动合并食物份量。"))
            }
        }
        .scrollContentBackground(.hidden).background(Palette.canvas)
        .navigationTitle("采购清单").fitnessError($error)
    }
}
