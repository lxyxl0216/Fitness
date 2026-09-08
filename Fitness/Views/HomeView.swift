import SwiftUI

struct HomeView: View {
    @Environment(FitnessStore.self) private var store
    @State private var training: Workout?
    @State private var addingFood = false
    @State private var error: String?
    @State private var selectedDate = Date()
    @State private var pendingMeal: Meal?

    var body: some View {
        ScreenContent {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(selectedDate.dayText).font(.title2.bold())
                    Text("吃好每一餐，认真练每一组。")
                        .font(.subheadline).foregroundStyle(Palette.muted)
                }
                Spacer()
                DatePicker("查看日期", selection: $selectedDate, in: ...Date(), displayedComponents: .date)
                    .labelsHidden().datePickerStyle(.compact).frame(maxWidth: 110)
            }
            NutritionSummary(intake: store.intake(on: selectedDate), targets: store.wellness.targets,
                             title: Calendar.current.isDateInToday(selectedDate) ? "今日摄入" : "当日摄入")
            HStack {
                if let target = store.wellness.targets {
                    let remaining = target.calories - store.intake(on: selectedDate).calories
                    Label(remaining >= 0 ? "距目标还有 \(remaining.fitnessText) kcal" : "超出目标 \((-remaining).fitnessText) kcal",
                          systemImage: "leaf")
                        .font(.subheadline).foregroundStyle(Palette.accent)
                } else {
                    NavigationLink("设置我的饮食目标") { TargetsEditor() }
                }
                Spacer()
            }.padding(.horizontal, 2)
            Button { addingFood = true } label: { Label("记录饮食", systemImage: "plus") }
                .buttonStyle(PrimaryButton()).accessibilityIdentifier("logFood")

            SectionHeading(title: "训练安排", subtitle: "本周已完成 \(store.workoutsThisWeek().count) 次训练")
            TrainingCard(date: selectedDate, training: $training)

            if let plan = store.activeMealPlan {
                HStack { SectionHeading(title: "今日餐单", subtitle: plan.name); Spacer()
                    NavigationLink("管理") { MealPlansView() }.font(.subheadline)
                }
                Surface {
                    VStack(spacing: 18) {
                        ForEach(Meal.allCases) { meal in
                            let items = plan.items.filter { $0.meal == meal }
                            if !items.isEmpty {
                                HStack(alignment: .top, spacing: 14) {
                                    Image(systemName: meal.symbol).foregroundStyle(Palette.accent).frame(width: 24)
                                    VStack(alignment: .leading, spacing: 5) {
                                        Text(meal.rawValue).font(.subheadline.bold())
                                        Text(items.map { "\($0.food.name) \($0.servings.fitnessText)份" }.joined(separator: "、"))
                                            .font(.caption).foregroundStyle(Palette.muted)
                                    }
                                    Spacer()
                                    Button("记入") { pendingMeal = meal }.font(.subheadline).frame(minHeight: 44)
                                }
                            }
                        }
                    }
                }
            } else {
                NavigationLink { MealPlansView() } label: {
                    Surface { HStack(spacing: 14) {
                        Image(systemName: "fork.knife").font(.title2).foregroundStyle(Palette.accent)
                        SectionHeading(title: "把常吃的组合存成餐单", subtitle: "按餐次安排，一次记入，自动生成采购清单")
                        Spacer(); Image(systemName: "chevron.right").foregroundStyle(Palette.muted)
                    } }
                }.buttonStyle(.plain)
            }
            SectionHeading(title: "当日饮食", subtitle: "记录包含食物及已打卡补剂")
            let logs = store.foodLogs(on: selectedDate)
            if logs.isEmpty {
                Surface { Text("还没有饮食记录。先添加食物标签，再记录实际吃下的份量。")
                    .font(.subheadline).foregroundStyle(Palette.muted) }
            } else {
                ForEach(Meal.allCases) { meal in
                    let entries = logs.filter { $0.meal == meal }
                    if !entries.isEmpty {
                        Surface { VStack(alignment: .leading, spacing: 14) {
                            Text(meal.rawValue).font(.headline)
                            ForEach(entries) { entry in
                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(entry.food.name).font(.subheadline)
                                        Text("\(entry.servings.fitnessText) 份 / 每份 \(entry.food.servingName)")
                                            .font(.caption).foregroundStyle(Palette.muted)
                                    }
                                    Spacer()
                                    Text("\(entry.nutrition.calories.fitnessText) kcal").font(.subheadline.monospacedDigit())
                                    Menu {
                                        Button("删除这条记录", role: .destructive) {
                                            do { try store.deleteFoodLog(id: entry.id) } catch { self.error = error.localizedDescription }
                                        }
                                    } label: { Image(systemName: "ellipsis").frame(width: 44, height: 44) }
                                }.accessibilityIdentifier("foodLogRow")
                            }
                        } }
                    }
                }
            }
        }
        .navigationTitle("Fitness").navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $addingFood) { FoodLogger(date: selectedDate) }
        .fullScreenCover(item: $training) { _ in TrainingView() }
        .fitnessError($error)
        .confirmationDialog("将这餐记入当日饮食？", isPresented: Binding(
            get: { pendingMeal != nil }, set: { if !$0 { pendingMeal = nil } }
        ), titleVisibility: .visible) {
            Button("确认记入") {
                guard let meal = pendingMeal, let plan = store.activeMealPlan else { return }
                do { try store.logMeal(planID: plan.id, meal: meal, date: selectedDate) }
                catch { self.error = error.localizedDescription }
                pendingMeal = nil
            }
        } message: { Text("将按餐单份量新增记录；重复操作会再记录一次。") }
    }
}

struct TrainingCard: View {
    @Environment(FitnessStore.self) private var store
    var date = Date()
    @Binding var training: Workout?
    @State private var error: String?

    @State private var chosenTemplateID: UUID?

    private var planned: WorkoutTemplate? {
        if let chosen = store.data.templates.first(where: { $0.id == chosenTemplateID }) { return chosen }
        return store.wellness.schedule == nil ? store.data.templates.first : store.scheduledTemplate(on: date)
    }

    var body: some View {
        Surface {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .top) {
                    Image(systemName: "dumbbell.fill").font(.title2).foregroundStyle(Palette.accent)
                        .padding(12).background(Palette.accent.opacity(0.08), in: RoundedRectangle(cornerRadius: 14))
                    VStack(alignment: .leading, spacing: 6) {
                        Text(store.data.draft?.name ?? planned?.name ?? "休息与恢复").font(.headline)
                        Text(store.data.draft.map { "已完成 \($0.completedSetCount) 组，随时继续" }
                             ?? planned.map { "\($0.exerciseIDs.count) 个动作，共 \($0.plannedSetCount) 组" }
                             ?? "今天没有训练安排，可以在训练页调整周期。")
                            .font(.caption).foregroundStyle(Palette.muted)
                    }
                }
                if let draft = store.data.draft {
                    Button("继续训练") { training = draft }.buttonStyle(PrimaryButton()).accessibilityIdentifier("resumeTraining")
                } else if let planned {
                    Button("开始训练") {
                        do { try store.start(template: planned); training = store.data.draft }
                        catch { self.error = error.localizedDescription }
                    }.buttonStyle(PrimaryButton()).accessibilityIdentifier("start-\(planned.exerciseIDs.first ?? "empty")")
                    .disabled(!Calendar.current.isDateInToday(date))
                    if !Calendar.current.isDateInToday(date) {
                        Text("当前为日期预览，请返回今天开始训练。")
                            .font(.caption).foregroundStyle(Palette.muted)
                    }
                }
                if store.data.draft == nil && !store.data.templates.isEmpty {
                    Menu("选择其他模板") {
                        ForEach(store.data.templates) { template in
                            Button(template.name) { chosenTemplateID = template.id }
                        }
                    }.font(.subheadline).frame(minHeight: 44)
                }
            }
        }.fitnessError($error)
        .onChange(of: date) { _, _ in chosenTemplateID = nil }
    }
}
