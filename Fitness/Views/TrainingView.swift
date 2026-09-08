import SwiftUI

struct TrainingView: View {
    @Environment(FitnessStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var error: String?
    @State private var confirmation: Confirmation?
    @FocusState private var inputFocused: Bool

    private enum Confirmation { case finish, discard }

    var body: some View {
        NavigationStack {
            Group {
                if let draft = store.data.draft {
                    List {
                        if let end = draft.restUntil {
                            Section {
                                TimelineView(.periodic(from: Date(), by: 1)) { context in
                                    HStack {
                                        Label(end > context.date ? "组间休息" : "休息结束", systemImage: "timer")
                                        Spacer()
                                        Text("\(max(0, Int(ceil(end.timeIntervalSince(context.date))))) 秒")
                                            .font(.headline.monospacedDigit()).foregroundStyle(Palette.accent)
                                        Button("结束") {
                                            do { try store.setRestEnd(nil) } catch { self.error = error.localizedDescription }
                                        }
                                    }
                                }
                            }
                        }
                        Section {
                            HStack {
                                Label("\(draft.completedSetCount) 组完成", systemImage: "checkmark.circle")
                                Spacer()
                                Text("\(draft.volume.fitnessText) kg").monospacedDigit()
                            }.font(.subheadline)
                            Text("输入自动保存。自重动作填 0 kg；哑铃按单只重量记录，并保持一致。已完成组需先取消勾选才能修改。")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        ForEach(draft.exercises) { exercise in
                            Section {
                                if let previous = store.previousSets(for: exercise.exerciseID) {
                                    Text("上次：" + previous.map { "\($0.weight) kg × \($0.reps)" }.joined(separator: " / "))
                                        .font(.caption).foregroundStyle(.secondary)
                                } else {
                                    Text("首次记录 · 从适合自己的重量开始")
                                        .font(.caption).foregroundStyle(.secondary)
                                }
                                HStack {
                                    Text("组").frame(width: 24)
                                    Text("重量 / kg").frame(maxWidth: .infinity)
                                    Text("次数").frame(maxWidth: .infinity)
                                    Text("完成").frame(width: 48)
                                }.font(.caption).foregroundStyle(.secondary)
                                ForEach(Array(exercise.sets.enumerated()), id: \.element.id) { index, set in
                                    HStack(spacing: 12) {
                                        Text("\(index + 1)").font(.subheadline.monospacedDigit()).frame(width: 24)
                                        TextField("kg", text: valueBinding(exercise.id, set.id, \.weight))
                                            .keyboardType(.decimalPad)
                                            .accessibilityLabel("\(exercise.name) 第 \(index + 1) 组重量")
                                            .accessibilityIdentifier("weight-\(exercise.exerciseID)-\(index)")
                                            .disabled(set.isCompleted)
                                        TextField("次数", text: valueBinding(exercise.id, set.id, \.reps))
                                            .keyboardType(.numberPad)
                                            .accessibilityLabel("\(exercise.name) 第 \(index + 1) 组次数")
                                            .accessibilityIdentifier("reps-\(exercise.exerciseID)-\(index)")
                                            .disabled(set.isCompleted)
                                        Button {
                                            inputFocused = false
                                            change { workout in
                                                guard let e = workout.exercises.firstIndex(where: { $0.id == exercise.id }),
                                                      let s = workout.exercises[e].sets.firstIndex(where: { $0.id == set.id }) else { return }
                                                workout.exercises[e].sets[s].isCompleted.toggle()
                                                if workout.exercises[e].sets[s].isCompleted {
                                                    let seconds = workout.exercises[e].restSeconds ?? 90
                                                    workout.restUntil = seconds > 0 ? Date().addingTimeInterval(Double(seconds)) : nil
                                                }
                                            }
                                        } label: {
                                            Image(systemName: set.isCompleted ? "checkmark.circle.fill" : "circle")
                                                .font(.title2).frame(width: 48, height: 44)
                                        }
                                        .buttonStyle(.borderless)
                                        .accessibilityLabel(set.isCompleted ? "取消完成第 \(index + 1) 组" : "完成第 \(index + 1) 组")
                                        .accessibilityIdentifier("complete-\(exercise.exerciseID)-\(index)")
                                    }
                                    .textFieldStyle(.roundedBorder)
                                    .focused($inputFocused)
                                    .swipeActions {
                                        Button("删除组", role: .destructive) {
                                            change { workout in
                                                guard let e = workout.exercises.firstIndex(where: { $0.id == exercise.id }) else { return }
                                                workout.exercises[e].sets.removeAll { $0.id == set.id }
                                            }
                                        }
                                    }
                                    Menu {
                                        Button("不记录 RPE") { setRPE(nil, exerciseID: exercise.id, setID: set.id) }
                                        ForEach(1...10, id: \.self) { value in
                                            Button("RPE \(value)") { setRPE(Double(value), exerciseID: exercise.id, setID: set.id) }
                                        }
                                    } label: {
                                        Text("第 \(index + 1) 组 RPE：\(set.rpe.map { $0.fitnessText } ?? "未记录")")
                                            .font(.caption).frame(minHeight: 30)
                                    }
                                }
                                Button {
                                    change { workout in
                                        guard let e = workout.exercises.firstIndex(where: { $0.id == exercise.id }) else { return }
                                        let previous = workout.exercises[e].sets.last
                                        workout.exercises[e].sets.append(TrainingSet(weight: previous?.weight ?? "0", reps: previous?.reps ?? "10"))
                                    }
                                } label: { Label("添加一组", systemImage: "plus") }
                            } header: {
                                Text(exercise.name + (exercise.targetRPE.map { " / 目标 RPE \($0.fitnessText)" } ?? ""))
                            }
                        }
                        Section {
                            Button("放弃本次训练", role: .destructive) { confirmation = .discard }
                        }
                    }
                    .scrollDismissesKeyboard(.interactively)
                    .scrollContentBackground(.hidden).background(Palette.canvas)
                    .navigationTitle(draft.name)
                } else {
                    ContentUnavailableView("训练已保存", systemImage: "checkmark.circle")
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("稍后继续") { dismiss() }.accessibilityIdentifier("pauseTraining")
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("结束训练") { inputFocused = false; confirmation = .finish }
                        .disabled((store.data.draft?.completedSetCount ?? 0) == 0)
                        .accessibilityIdentifier("finishTraining")
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("收起键盘") { inputFocused = false }
                }
            }
            .confirmationDialog(confirmation == .discard ? "放弃本次训练？" : "保存本次训练？", isPresented: Binding(
                get: { confirmation != nil }, set: { if !$0 { confirmation = nil } }
            ), titleVisibility: .visible) {
                if confirmation == .discard {
                    Button("放弃训练", role: .destructive) {
                        do { try store.discardDraft(); dismiss() }
                        catch { self.error = error.localizedDescription }
                    }
                } else {
                    Button("保存到历史") {
                        do { try store.finish(); dismiss() }
                        catch { self.error = error.localizedDescription }
                    }
                }
            } message: {
                Text(confirmation == .discard ? "本次未归档的训练记录将被移除。" : "只保存已勾选的有效组，未完成组不会计入统计。")
            }
            .fitnessError($error)
        }
    }

    private func change(_ edit: (inout Workout) -> Void) {
        guard var draft = store.data.draft else { return }
        edit(&draft)
        do { try store.updateDraft(draft) }
        catch { self.error = error.localizedDescription }
    }

    private func setRPE(_ value: Double?, exerciseID: UUID, setID: UUID) {
        change { workout in
            guard let e = workout.exercises.firstIndex(where: { $0.id == exerciseID }),
                  let s = workout.exercises[e].sets.firstIndex(where: { $0.id == setID }) else { return }
            workout.exercises[e].sets[s].rpe = value
        }
    }

    private func valueBinding(_ exerciseID: UUID, _ setID: UUID, _ keyPath: WritableKeyPath<TrainingSet, String>) -> Binding<String> {
        Binding(get: {
            store.data.draft?.exercises.first { $0.id == exerciseID }?.sets.first { $0.id == setID }?[keyPath: keyPath] ?? ""
        }, set: { value in
            change { workout in
                guard let e = workout.exercises.firstIndex(where: { $0.id == exerciseID }),
                      let s = workout.exercises[e].sets.firstIndex(where: { $0.id == setID }) else { return }
                workout.exercises[e].sets[s][keyPath: keyPath] = value
            }
        })
    }
}
