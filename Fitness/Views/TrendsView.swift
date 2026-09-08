import SwiftUI
import Charts

struct TrendsView: View {
    @Environment(FitnessStore.self) private var store
    @State private var period = 7
    private var dates: [Date] {
        (0..<period).reversed().compactMap { Calendar.current.date(byAdding: .day, value: -$0, to: Calendar.current.startOfDay(for: Date())) }
    }
    private var logs: [FoodLog] { store.wellness.logs.filter { $0.date >= dates[0] && $0.date <= Date() } }
    private var total: NutritionValues { logs.reduce(NutritionValues()) { $0 + $1.nutrition } }
    private var recordedDays: Int { Set(logs.map { Calendar.current.startOfDay(for: $0.date) }).count }

    var body: some View {
        ScreenContent {
            Picker("统计范围", selection: $period) {
                Text("今日").tag(1); Text("近 7 天").tag(7); Text("近 30 天").tag(30)
            }.pickerStyle(.segmented)
            SectionHeading(title: "每一天，都算数", subtitle: "\(dates[0].shortText) - \(Date().shortText) · 已记录饮食 \(recordedDays) 天")
            Surface {
                VStack(alignment: .leading, spacing: 20) {
                    Text("营养摄入").font(.headline)
                    if logs.isEmpty {
                        ContentUnavailableView("从第一餐开始", systemImage: "fork.knife", description: Text("记录饮食后查看摄入趋势。未记录不代表没有摄入。"))
                    } else {
                        Text("\(total.calories.fitnessText) kcal").font(.largeTitle.bold()).monospacedDigit()
                        Text("所选期间的已记录总量").font(.caption).foregroundStyle(Palette.muted)
                        if period > 1 {
                            Chart(dates, id: \.self) { date in
                                if !store.foodLogs(on: date).isEmpty {
                                    BarMark(x: .value("日期", date, unit: .day), y: .value("热量", store.intake(on: date).calories))
                                        .foregroundStyle(Palette.accent).cornerRadius(4)
                                }
                            }.chartXScale(domain: dates[0]...Date()).frame(height: 170)
                        }
                        nutrient("蛋白质", total.protein, goal: store.wellness.targets?.protein)
                        nutrient("碳水", total.carbs, goal: store.wellness.targets?.carbs)
                        nutrient("脂肪", total.fat, goal: store.wellness.targets?.fat)
                        Divider()
                        Text(total.sodium.map { "已知钠摄入 \($0.fitnessText) mg" } ?? "暂无钠数据").font(.subheadline)
                        Text("\(logs.filter { $0.food.nutrition.sodium != nil }.count) / \(logs.count) 条饮食记录填写了钠；缺失部分不按零计算。").font(.caption).foregroundStyle(Palette.muted)
                    }
                }
            }
            SectionHeading(title: "训练积累", subtitle: "本周完成的训练")
            HStack {
                StatTile(title: "训练次数", value: "\(store.workoutsThisWeek().count)", unit: "次")
                StatTile(title: "完成组数", value: "\(store.workoutsThisWeek().reduce(0) { $0 + $1.completedSetCount })", unit: "组")
                StatTile(title: "训练时间", value: "\(store.workoutsThisWeek().reduce(0) { $0 + $1.durationMinutes })", unit: "分钟")
            }
            Surface {
                NavigationLink { BodyView() } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("身体趋势").font(.headline)
                            Text(store.data.bodyRecords.first.map { "最近体重 \($0.weight.fitnessText) kg" } ?? "记录体重，慢慢看见变化")
                                .font(.subheadline).foregroundStyle(Palette.muted)
                        }
                        Spacer(); Image(systemName: "arrow.up.right")
                    }.frame(minHeight: 50)
                }.buttonStyle(.plain)
            }
        }.navigationTitle("趋势")
    }

    private func nutrient(_ name: String, _ value: Double, goal: Double?) -> some View {
        HStack {
            Text(name).foregroundStyle(Palette.muted)
            Spacer()
            VStack(alignment: .trailing, spacing: 4) {
                Text("\(value.fitnessText) g").monospacedDigit()
                if let goal { Text("每日目标 \(goal.fitnessText) g").font(.caption2).foregroundStyle(Palette.muted) }
            }
        }
    }
}
