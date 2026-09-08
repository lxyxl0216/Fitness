import SwiftUI

struct FoodLibraryView: View {
    @Environment(FitnessStore.self) private var store
    var supplements = false
    @State private var query = ""
    @State private var editing: FoodItem?
    @State private var deleting: FoodItem?
    @State private var error: String?

    private var foods: [FoodItem] {
        store.wellness.foods.filter { $0.isSupplement == supplements && (query.isEmpty || $0.name.localizedCaseInsensitiveContains(query)) }
    }

    var body: some View {
        List {
            Section {
                Text("按包装标签填写每份营养。每份可定义为 100 g、一袋或一勺，记录时按相同口径填写份数。")
                    .font(.subheadline).foregroundStyle(Palette.muted)
            }
            if foods.isEmpty {
                ContentUnavailableView("建立自己的\(supplements ? "补剂" : "食物")库", systemImage: supplements ? "pills" : "carrot",
                                       description: Text("点击 + 添加常用项目，数值以实际标签为准。"))
            }
            ForEach(foods) { food in
                Button { editing = food } label: {
                    FoodLabel(food: food)
                }.buttonStyle(.plain)
                .swipeActions { Button("删除", role: .destructive) { deleting = food } }
            }
        }
        .scrollContentBackground(.hidden).background(Palette.canvas)
        .navigationTitle(supplements ? "我的补剂" : "我的食物")
        .searchable(text: $query, prompt: "搜索名称")
        .toolbar { Button { editing = FoodItem(name: "", isSupplement: supplements) } label: {
            Image(systemName: "plus")
        }.accessibilityIdentifier("addFood") }
        .sheet(item: $editing) { FoodEditor(food: $0) }
        .confirmationDialog("删除这个项目？", isPresented: Binding(
            get: { deleting != nil }, set: { if !$0 { deleting = nil } }
        ), titleVisibility: .visible) {
            Button("删除", role: .destructive) {
                guard let deleting else { return }
                do { try store.deleteFood(id: deleting.id) } catch { self.error = error.localizedDescription }
                self.deleting = nil
            }
        } message: { Text("已记录的饮食与已保存的餐单不会改变。") }
        .fitnessError($error)
    }
}

struct FoodLabel: View {
    let food: FoodItem
    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: food.isSupplement ? "pills" : "fork.knife")
                .foregroundStyle(Palette.accent).frame(width: 38, height: 42)
                .background(Palette.accent.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
            VStack(alignment: .leading, spacing: 5) {
                Text(food.name).font(.headline).foregroundStyle(Color.primary)
                Text("每份 \(food.servingName) / \(food.nutrition.calories.fitnessText) kcal")
                    .font(.caption).foregroundStyle(Palette.muted)
            }
        }.padding(.vertical, 5)
    }
}

struct FoodEditor: View {
    @Environment(FitnessStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State var food: FoodItem
    @State private var calories: String
    @State private var protein: String
    @State private var carbs: String
    @State private var fat: String
    @State private var sodium: String
    @State private var error: String?

    init(food: FoodItem) {
        _food = State(initialValue: food)
        let new = food.name.isEmpty
        _calories = State(initialValue: new ? "" : String(food.nutrition.calories))
        _protein = State(initialValue: new ? "" : String(food.nutrition.protein))
        _carbs = State(initialValue: new ? "" : String(food.nutrition.carbs))
        _fat = State(initialValue: new ? "" : String(food.nutrition.fat))
        _sodium = State(initialValue: food.nutrition.sodium.map(String.init(describing:)) ?? "")
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("基本信息") {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("名称").font(.caption).foregroundStyle(Palette.muted)
                        TextField("例如：原味酸奶", text: $food.name).accessibilityIdentifier("foodName")
                    }
                    VStack(alignment: .leading, spacing: 6) {
                        Text("每份大小").font(.caption).foregroundStyle(Palette.muted)
                        TextField("例如：100 g、一袋 250 ml", text: $food.servingName)
                    }
                    Toggle("这是补剂", isOn: $food.isSupplement)
                }
                Section("每份营养 · 按实际标签填写") {
                    ValueField(label: "热量", text: $calories, unit: "kcal", identifier: "foodCalories")
                    ValueField(label: "蛋白质", text: $protein, unit: "g", identifier: "foodProtein")
                    ValueField(label: "碳水", text: $carbs, unit: "g", identifier: "foodCarbs")
                    ValueField(label: "脂肪", text: $fat, unit: "g", identifier: "foodFat")
                    ValueField(label: "钠（可选）", text: $sodium, unit: "mg")
                }
                Section("来源或备注") { TextField("品牌、包装标签或数据来源", text: $food.notes, axis: .vertical) }
                if let error { Section { Text(error).foregroundStyle(.red) } }
            }
            .scrollContentBackground(.hidden).background(Palette.canvas)
            .navigationTitle("编辑\(food.isSupplement ? "补剂" : "食物")").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("保存", action: save).accessibilityIdentifier("saveFood") }
            }
        }.interactiveDismissDisabled()
    }

    private func save() {
        do {
            guard let kcal = InputNumber.decimal(calories), let p = InputNumber.decimal(protein),
                  let c = InputNumber.decimal(carbs), let f = InputNumber.decimal(fat) else {
                throw FitnessError.invalid("请填写热量和三大营养素的数字；没有的项目填 0。")
            }
            let s = sodium.trimmingCharacters(in: .whitespacesAndNewlines)
            guard s.isEmpty || InputNumber.decimal(s) != nil else { throw FitnessError.invalid("钠需为数字或留空。") }
            food.nutrition = NutritionValues(calories: kcal, protein: p, carbs: c, fat: f, sodium: InputNumber.decimal(s))
            try store.saveFood(food)
            dismiss()
        } catch { self.error = error.localizedDescription }
    }
}

struct FoodLogger: View {
    @Environment(FitnessStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State var date = Date()
    @State private var meal: Meal = .breakfast
    @State private var selected: UUID?
    @State private var servings = "1"
    @State private var editing: FoodItem?
    @State private var query = ""
    @State private var error: String?

    var body: some View {
        NavigationStack {
            Form {
                Section("这次吃了多少") {
                    DatePicker("日期", selection: $date, in: ...Date(), displayedComponents: .date)
                    Picker("餐次", selection: $meal) { ForEach(Meal.allCases) { Text($0.rawValue).tag($0) } }
                    ValueField(label: "份数", text: $servings, unit: "份", identifier: "foodServings")
                    if let food = store.wellness.foods.first(where: { $0.id == selected }), let amount = InputNumber.decimal(servings), amount.isFinite, amount > 0 {
                        Text("\(food.name)：\((food.nutrition.calories * amount).fitnessText) kcal")
                            .font(.headline).foregroundStyle(Palette.accent)
                    }
                }
                Section("选择食物或补剂") {
                    Button { editing = FoodItem(name: "") } label: { Label("添加新食物", systemImage: "plus") }
                    ForEach(store.wellness.foods.filter { query.isEmpty || $0.name.localizedCaseInsensitiveContains(query) }) { food in
                        Button { selected = food.id } label: {
                            HStack { FoodLabel(food: food); Spacer()
                                if selected == food.id { Image(systemName: "checkmark.circle.fill").foregroundStyle(Palette.accent) }
                            }
                        }.buttonStyle(.plain).accessibilityIdentifier("chooseFood-\(food.name)")
                    }
                    if store.wellness.foods.isEmpty {
                        Text("先添加一个食品标签，即可按份量记录。")
                            .font(.subheadline).foregroundStyle(Palette.muted)
                    }
                }
                if let error { Section { Text(error).foregroundStyle(.red) } }
            }
            .searchable(text: $query, prompt: "搜索食物")
            .scrollContentBackground(.hidden).background(Palette.canvas)
            .navigationTitle("记录饮食").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("记入") {
                        do {
                            guard let food = store.wellness.foods.first(where: { $0.id == selected }), let amount = InputNumber.decimal(servings) else {
                                throw FitnessError.invalid("请选择食物并填写有效份数。")
                            }
                            try store.logFood(food, servings: amount, meal: meal, date: date)
                            dismiss()
                        } catch { self.error = error.localizedDescription }
                    }.accessibilityIdentifier("saveFoodLog")
                }
            }
            .sheet(item: $editing) { FoodEditor(food: $0) }
        }
    }
}

struct TargetsEditor: View {
    @Environment(FitnessStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var calories = ""
    @State private var protein = ""
    @State private var carbs = ""
    @State private var fat = ""
    @State private var error: String?
    @State private var loaded = false

    var body: some View {
        Form {
            Section("每天的目标") {
                ValueField(label: "热量", text: $calories, unit: "kcal", identifier: "targetCalories")
                ValueField(label: "蛋白质", text: $protein, unit: "g", identifier: "targetProtein")
                ValueField(label: "碳水", text: $carbs, unit: "g", identifier: "targetCarbs")
                ValueField(label: "脂肪", text: $fat, unit: "g", identifier: "targetFat")
            }
            Section {
                Text("按你自己的饮食方案填写。静息消耗估算不等于每日摄入目标，训练容量也不会自动折算成热量。")
                    .font(.subheadline).foregroundStyle(Palette.muted)
            }
            if let error { Section { Text(error).foregroundStyle(.red) } }
            Button("保存目标") {
                do {
                    guard let k = InputNumber.decimal(calories), let p = InputNumber.decimal(protein),
                          let c = InputNumber.decimal(carbs), let f = InputNumber.decimal(fat) else {
                        throw FitnessError.invalid("请填写完整的数字目标。")
                    }
                    try store.saveTargets(NutritionValues(calories: k, protein: p, carbs: c, fat: f))
                    dismiss()
                } catch { self.error = error.localizedDescription }
            }.accessibilityIdentifier("saveTargets")
        }
        .scrollContentBackground(.hidden).background(Palette.canvas)
        .navigationTitle("饮食目标")
        .onAppear {
            guard !loaded else { return }; loaded = true
            if let t = store.wellness.targets {
                calories = String(t.calories); protein = String(t.protein); carbs = String(t.carbs); fat = String(t.fat)
            }
        }
    }
}
