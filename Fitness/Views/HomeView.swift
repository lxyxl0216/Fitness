import SwiftUI

struct HomeView: View {
    @Environment(FitnessStore.self) private var store
    @State private var training: Workout?
    @State private var error: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(Date().formatted(.dateTime.month().day().weekday(.wide)))
                        .font(.subheadline).foregroundStyle(.secondary)
                    Text("每一组，都算数。")
                        .font(.largeTitle.bold())
                    Text("专注今天的训练，记录自己的进步。")
                        .foregroundStyle(.secondary)
                }

                HStack(spacing: 10) {
                    StatTile(title: "本周训练", value: "\(store.workoutsThisWeek().count)", unit: "次")
                    StatTile(title: "本周完成", value: "\(store.workoutsThisWeek().reduce(0) { $0 + $1.completedSetCount })", unit: "组")
                    StatTile(title: "最近体重", value: store.data.bodyRecords.first?.weight.fitnessText ?? "—", unit: "kg")
                }

                if let draft = store.data.draft {
                    VStack(alignment: .leading, spacing: 12) {
                        Label("训练进行中", systemImage: "circle.fill")
                            .font(.caption.bold()).foregroundStyle(.orange)
                        Text(draft.name).font(.title2.bold())
                        Text("已完成 \(draft.completedSetCount) 组 · 草稿已保存在本机")
                            .font(.subheadline).foregroundStyle(.secondary)
                        Button("继续训练") { training = draft }
                            .buttonStyle(.borderedProminent).controlSize(.large)
                            .accessibilityIdentifier("resumeTraining")
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(20)
                    .background(.orange.opacity(0.1), in: RoundedRectangle(cornerRadius: 20))
                }

                Text("今天练什么").font(.title2.bold())
                if store.data.templates.isEmpty {
                    ContentUnavailableView("还没有训练计划", systemImage: "list.bullet.clipboard",
                                           description: Text("到「计划」页创建你的第一个模板。"))
                }
                ForEach(store.data.templates) { template in
                    VStack(alignment: .leading, spacing: 12) {
                        Text(template.name).font(.headline)
                        Text("\(template.exerciseIDs.count) 个动作 · 每个动作 \(template.setCount) 组")
                            .font(.subheadline).foregroundStyle(.secondary)
                        Text(template.exerciseIDs.compactMap { ExerciseCatalog.find($0)?.name }.joined(separator: " / "))
                            .font(.caption).foregroundStyle(.secondary)
                        Button {
                            do {
                                try store.start(template: template)
                                training = store.data.draft
                            } catch { self.error = error.localizedDescription }
                        } label: {
                            Label("开始训练", systemImage: "play.fill").frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(store.data.draft != nil)
                        .accessibilityIdentifier("start-\(template.exerciseIDs.first ?? "empty")")
                    }
                    .padding(20)
                    .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 20))
                }
            }
            .padding(20)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Fitness").navigationBarTitleDisplayMode(.inline)
        .fullScreenCover(item: $training) { _ in TrainingView() }
        .fitnessError($error)
    }
}
