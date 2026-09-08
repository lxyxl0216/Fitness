import SwiftUI

struct HistoryView: View {
    @Environment(FitnessStore.self) private var store
    @State private var deleting: Workout?
    @State private var error: String?

    var body: some View {
        List {
            ForEach(store.data.workouts.sorted { $0.startedAt > $1.startedAt }) { workout in
                NavigationLink {
                    WorkoutDetailView(workout: workout)
                } label: {
                    WorkoutSummary(workout: workout)
                }
                .accessibilityIdentifier("historyWorkout")
                .swipeActions {
                    Button("删除", role: .destructive) { deleting = workout }
                }
            }
        }
        .overlay {
            if store.data.workouts.isEmpty {
                ContentUnavailableView("第一步，从今天开始", systemImage: "clock.arrow.circlepath",
                                       description: Text("完成一次训练后，在这里回看每一组进步。"))
            }
        }
        .navigationTitle("训练历史")
        .scrollContentBackground(.hidden).background(Palette.canvas)
        .confirmationDialog("删除这次训练？", isPresented: Binding(
            get: { deleting != nil }, set: { if !$0 { deleting = nil } }
        ), titleVisibility: .visible) {
            Button("删除训练", role: .destructive) {
                guard let deleting else { return }
                do { try store.deleteWorkout(id: deleting.id) }
                catch { self.error = error.localizedDescription }
                self.deleting = nil
            }
        } message: { Text("这次训练的动作和组记录将一并删除，统计也会更新。") }
        .fitnessError($error)
    }
}

struct WorkoutDetailView: View {
    let workout: Workout

    var body: some View {
        List {
            Section {
                WorkoutSummary(workout: workout)
                Text("容量 = 已完成组的记录重量 × 次数之和。自重动作以完成次数为参考；哑铃沿用录入的单只重量。")
                    .font(.caption).foregroundStyle(.secondary)
            }
            ForEach(workout.exercises) { exercise in
                Section(exercise.name) {
                    ForEach(Array(exercise.sets.enumerated()), id: \.element.id) { index, set in
                        HStack {
                            Text("第 \(index + 1) 组").foregroundStyle(.secondary)
                            Spacer()
                            Text("\(set.weight) kg × \(set.reps) 次").monospacedDigit()
                            if let rpe = set.rpe { Text("RPE \(rpe.fitnessText)").font(.caption).foregroundStyle(Palette.muted) }
                            Image(systemName: "checkmark.circle.fill").foregroundStyle(Palette.accent)
                        }
                    }
                }
            }
        }
        .navigationTitle("训练详情").navigationBarTitleDisplayMode(.inline)
    }
}
