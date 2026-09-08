import SwiftUI

struct PlansView: View {
    @Environment(FitnessStore.self) private var store
    @State private var editing: WorkoutTemplate?
    @State private var deleting: WorkoutTemplate?
    @State private var error: String?

    var body: some View {
        List {
            Section {
                Text("模板决定动作顺序。修改模板不会改变正在进行或已完成的训练。")
                    .font(.subheadline).foregroundStyle(.secondary)
            }
            ForEach(store.data.templates) { template in
                Button { editing = template } label: {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(template.name).font(.headline).foregroundStyle(.primary)
                        Text("\(template.exerciseIDs.count) 个动作 / 共 \(template.plannedSetCount) 组")
                            .font(.subheadline).foregroundStyle(.secondary)
                        Text(template.exerciseIDs.compactMap { ExerciseCatalog.find($0)?.name }.joined(separator: " · "))
                            .font(.caption).foregroundStyle(.secondary)
                    }.padding(.vertical, 6)
                }
                .buttonStyle(.plain)
                .swipeActions {
                    Button("删除", role: .destructive) { deleting = template }
                }
            }
        }
        .overlay {
            if store.data.templates.isEmpty {
                ContentUnavailableView("建立自己的节奏", systemImage: "list.bullet.clipboard",
                                       description: Text("点击右上角 +，创建训练计划。"))
            }
        }
        .navigationTitle("训练计划")
        .scrollContentBackground(.hidden).background(Palette.canvas)
        .toolbar {
            Button { editing = WorkoutTemplate(name: "", exerciseIDs: []) } label: {
                Image(systemName: "plus")
            }.accessibilityLabel("新建计划")
        }
        .sheet(item: $editing) { template in TemplateEditor(template: template) }
        .confirmationDialog("删除这个计划？", isPresented: Binding(
            get: { deleting != nil }, set: { if !$0 { deleting = nil } }
        ), titleVisibility: .visible) {
            Button("删除计划", role: .destructive) {
                guard let deleting else { return }
                do { try store.deleteTemplate(id: deleting.id) }
                catch { self.error = error.localizedDescription }
                self.deleting = nil
            }
        } message: { Text("训练历史仍会保留。") }
        .fitnessError($error)
    }
}

struct TemplateEditor: View {
    @Environment(FitnessStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State var template: WorkoutTemplate
    @State private var query = ""
    @State private var error: String?

    private var filtered: [Exercise] {
        ExerciseCatalog.exercises.filter {
            query.isEmpty || "\($0.name) \($0.muscle) \($0.equipment)".localizedCaseInsensitiveContains(query)
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("计划设置") {
                    TextField("计划名称", text: $template.name)
                        .accessibilityIdentifier("templateName")
                    Stepper("每个动作 \(template.setCount) 组", value: $template.setCount, in: 1...10)
                }
                if !template.exerciseIDs.isEmpty {
                    Section("动作顺序 · 拖动右侧排序") {
                        ForEach(template.exerciseIDs, id: \.self) { id in
                            Text(ExerciseCatalog.find(id)?.name ?? id)
                        }
                        .onMove { template.exerciseIDs.move(fromOffsets: $0, toOffset: $1) }
                        .onDelete { template.exerciseIDs.remove(atOffsets: $0) }
                    }
                    .environment(\.editMode, .constant(.active))
                }
                Section("逐组目标与休息") {
                    ForEach(template.exerciseIDs, id: \.self) { id in
                        NavigationLink(ExerciseCatalog.find(id)?.name ?? id) {
                            PrescriptionEditor(prescription: Binding(
                                get: { template.prescription(for: id) },
                                set: { value in
                                    if template.prescriptions == nil { template.prescriptions = [:] }
                                    template.prescriptions?[id] = value
                                }
                            ), name: ExerciseCatalog.find(id)?.name ?? id)
                        }
                    }
                }
                Section("动作库 · 点击添加或移除") {
                    ForEach(filtered) { exercise in
                        Button {
                            if template.exerciseIDs.contains(exercise.id) {
                                template.exerciseIDs.removeAll { $0 == exercise.id }
                            } else {
                                template.exerciseIDs.append(exercise.id)
                            }
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(exercise.name).foregroundStyle(.primary)
                                    Text("\(exercise.muscle) · \(exercise.equipment)")
                                        .font(.caption).foregroundStyle(.secondary)
                                }
                                Spacer()
                                Image(systemName: template.exerciseIDs.contains(exercise.id) ? "checkmark.circle.fill" : "plus.circle")
                            }
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("exercise-\(exercise.id)")
                    }
                }
            }
            .searchable(text: $query, prompt: "搜索动作、肌群或器械")
            .scrollContentBackground(.hidden).background(Palette.canvas)
            .navigationTitle("编辑计划").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        do { try store.saveTemplate(template); dismiss() }
                        catch { self.error = error.localizedDescription }
                    }.accessibilityIdentifier("saveTemplate")
                }
            }
            .fitnessError($error)
        }
        .interactiveDismissDisabled()
    }
}
