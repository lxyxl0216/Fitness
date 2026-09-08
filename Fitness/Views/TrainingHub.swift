import SwiftUI

struct TrainingHub: View {
    @Environment(FitnessStore.self) private var store
    @State private var page = "计划"
    @State private var date = Date()
    @State private var training: Workout?
    @State private var cycleEditor = false

    var body: some View {
        VStack(spacing: 0) {
            Picker("训练页面", selection: $page) {
                ForEach(["计划", "动作", "记录"], id: \.self) { Text($0).tag($0) }
            }.pickerStyle(.segmented).padding(.horizontal, 20).padding(.vertical, 12)
            if page == "动作" { ExerciseLibraryView() }
            else if page == "记录" { HistoryView() }
            else {
                ScreenContent {
                    HStack {
                        SectionHeading(title: "我的训练节奏", subtitle: store.wellness.schedule.map { "\($0.days.count) 天循环" } ?? "选择模板开始，或安排训练周期")
                        Spacer()
                        Button("排周期") { cycleEditor = true }.font(.subheadline.bold()).frame(minHeight: 44)
                    }
                    WeekStrip(selection: $date)
                    TrainingCard(date: date, training: $training)
                    if let template = store.scheduledTemplate(on: date) ?? (store.wellness.schedule == nil ? store.data.templates.first : nil) {
                        SectionHeading(title: "当日动作")
                        Surface {
                            VStack(alignment: .leading, spacing: 18) {
                                ForEach(template.exerciseIDs, id: \.self) { id in
                                    let prescription = template.prescription(for: id)
                                    HStack(alignment: .top) {
                                        VStack(alignment: .leading, spacing: 6) {
                                            Text(ExerciseCatalog.find(id)?.name ?? id).font(.headline)
                                            Text(prescription.reps.map(String.init).joined(separator: " / ") + " 次")
                                                .font(.subheadline.monospacedDigit()).foregroundStyle(Palette.muted)
                                        }
                                        Spacer()
                                        Text("休息 \(prescription.restSeconds)秒").font(.caption).foregroundStyle(Palette.accent)
                                    }
                                }
                            }
                        }
                    }
                    NavigationLink { PlansView() } label: {
                        Surface { HStack { SectionHeading(title: "全部训练模板", subtitle: "编辑动作顺序、逐组次数与 RPE"); Spacer(); Image(systemName: "chevron.right") } }
                    }.buttonStyle(.plain).accessibilityIdentifier("manageTemplates")
                }
            }
        }
        .background(Palette.canvas)
        .navigationTitle("训练").navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $cycleEditor) { ScheduleEditor() }
        .fullScreenCover(item: $training) { _ in TrainingView() }
    }
}

struct WeekStrip: View {
    @Binding var selection: Date
    private var dates: [Date] {
        let cal = Calendar.current
        let start = cal.dateInterval(of: .weekOfYear, for: selection)?.start ?? selection
        return (0..<7).compactMap { cal.date(byAdding: .day, value: $0, to: start) }
    }
    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Text(selection.shortText).font(.headline)
                Spacer()
                DatePicker("选择训练日期", selection: $selection, displayedComponents: .date).labelsHidden()
            }
            HStack(spacing: 6) {
                ForEach(dates, id: \.self) { day in
                    let selected = Calendar.current.isDate(day, inSameDayAs: selection)
                    Button { selection = day } label: {
                        VStack(spacing: 10) {
                            Text(day.formatted(.dateTime.weekday(.narrow).locale(Locale(identifier: "zh_CN")))).font(.caption)
                            Text(day.formatted(.dateTime.day())).font(.subheadline.bold())
                        }.frame(maxWidth: .infinity).frame(minHeight: 66)
                            .foregroundStyle(selected ? Color.white : Palette.muted)
                            .background(selected ? Palette.button : Palette.surface, in: RoundedRectangle(cornerRadius: 14))
                    }.buttonStyle(.plain).accessibilityLabel(day.dayText)
                }
            }
        }
    }
}

struct ScheduleEditor: View {
    @Environment(FitnessStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var start = Date()
    @State private var days: [ScheduleDay] = []
    @State private var loaded = false
    @State private var error: String?

    var body: some View {
        NavigationStack {
            Form {
                Section("循环设置") {
                    DatePicker("第一天", selection: $start, displayedComponents: .date)
                    Text("训练日和休息日按此顺序循环，不按自然周重置。")
                        .font(.caption).foregroundStyle(Palette.muted)
                }
                Section("每日安排") {
                    ForEach(Array(days.enumerated()), id: \.element.id) { index, _ in
                        Picker("第 \(index + 1) 天", selection: $days[index].templateID) {
                            Text("休息").tag(Optional<UUID>.none)
                            ForEach(store.data.templates) { Text($0.name).tag(Optional($0.id)) }
                        }
                    }.onDelete { days.remove(atOffsets: $0) }
                    Button("添加一天") { days.append(ScheduleDay(templateID: nil)) }.disabled(days.count >= 14)
                }
                if let error { Text(error).foregroundStyle(.red) }
            }
            .scrollContentBackground(.hidden).background(Palette.canvas)
            .navigationTitle("训练周期").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        do { try store.saveSchedule(TrainingSchedule(startDate: start, days: days)); dismiss() }
                        catch { self.error = error.localizedDescription }
                    }
                }
            }
            .onAppear {
                guard !loaded else { return }; loaded = true
                start = store.wellness.schedule?.startDate ?? Date()
                days = store.wellness.schedule?.days ?? (store.data.templates.map { ScheduleDay(templateID: $0.id) } + [ScheduleDay(templateID: nil)])
            }
        }.interactiveDismissDisabled()
    }
}

struct ExerciseLibraryView: View {
    @State private var muscle = "全部"
    @State private var equipment = "全部"
    @State private var query = ""
    private var filtered: [Exercise] {
        ExerciseCatalog.exercises.filter {
            (muscle == "全部" || $0.muscle == muscle) && (equipment == "全部" || $0.equipment == equipment)
            && (query.isEmpty || $0.name.localizedCaseInsensitiveContains(query))
        }
    }
    var body: some View {
        VStack(spacing: 14) {
            HStack {
                Image(systemName: "magnifyingglass").foregroundStyle(Palette.muted)
                TextField("搜索动作", text: $query).accessibilityLabel("搜索动作")
            }.padding(13).background(Palette.surface, in: RoundedRectangle(cornerRadius: 12)).padding(.horizontal, 20)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(["全部", "胸部", "背部", "肩部", "腿部", "手臂", "核心"], id: \.self) { item in
                        Button { muscle = item } label: {
                            Text(item).font(.subheadline.weight(.medium)).padding(.horizontal, 14).frame(minHeight: 44)
                                .foregroundStyle(muscle == item ? Color.white : Palette.muted)
                                .background(muscle == item ? Palette.button : Palette.surface, in: Capsule())
                        }.buttonStyle(.plain)
                    }
                }.padding(.horizontal, 20)
            }
            HStack {
                Text("\(filtered.count) 个动作").font(.caption).foregroundStyle(Palette.muted)
                Spacer()
                Picker("器械", selection: $equipment) {
                    ForEach(["全部", "杠铃", "哑铃", "绳索", "器械", "自重"], id: \.self) { Text($0).tag($0) }
                }.pickerStyle(.menu)
            }.padding(.horizontal, 20)
            ScrollView {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 12)], spacing: 12) {
                    ForEach(filtered) { exercise in
                        NavigationLink { ExerciseDetail(exercise: exercise) } label: {
                            VStack(alignment: .leading, spacing: 14) {
                                Image(systemName: exercise.equipment == "自重" ? "figure.strengthtraining.functional" : "dumbbell")
                                    .font(.system(size: 36, weight: .light)).foregroundStyle(Palette.accent)
                                    .frame(maxWidth: .infinity, minHeight: 66)
                                    .background(Palette.accent.opacity(0.06), in: RoundedRectangle(cornerRadius: 12))
                                Text(exercise.name).font(.headline).foregroundStyle(Color.primary)
                                Text("\(exercise.muscle) / \(exercise.equipment)").font(.caption).foregroundStyle(Palette.muted)
                            }.padding(14).frame(maxWidth: .infinity, alignment: .leading)
                                .background(Palette.surface, in: RoundedRectangle(cornerRadius: 22))
                        }.buttonStyle(.plain)
                    }
                }.padding(.horizontal, 20).padding(.bottom, 20)
                if filtered.isEmpty { ContentUnavailableView.search(text: query) }
            }
        }
    }
}

struct ExerciseDetail: View {
    @Environment(FitnessStore.self) private var store
    let exercise: Exercise
    @State private var link = ""
    @State private var error: String?
    @State private var saved = false

    var body: some View {
        Form {
            Section {
                Image(systemName: "figure.strengthtraining.traditional").font(.system(size: 62, weight: .ultraLight))
                    .foregroundStyle(Palette.accent).frame(maxWidth: .infinity).padding(24)
                LabeledContent("主要部位", value: exercise.muscle)
                LabeledContent("器械", value: exercise.equipment)
                Text("重量按固定口径记录。动作质量优先于重量；可保存你熟悉的教练演示作为参考。")
                    .font(.subheadline).foregroundStyle(Palette.muted)
            }
            Section("上次完成") {
                if let sets = store.previousSets(for: exercise.id) {
                    ForEach(Array(sets.enumerated()), id: \.element.id) { index, set in
                        LabeledContent("第 \(index + 1) 组", value: "\(set.weight) kg × \(set.reps) 次")
                    }
                } else { Text("尚无此动作的训练记录。").foregroundStyle(Palette.muted) }
            }
            Section("我的演示链接") {
                TextField("HTTPS 视频或 GIF 地址", text: $link).keyboardType(.URL).textInputAutocapitalization(.never).autocorrectionDisabled()
                Button("保存链接") {
                    do { try store.saveExerciseLink(id: exercise.id, link: link); saved = true }
                    catch { self.error = error.localizedDescription }
                }
                if let text = store.wellness.exerciseLinks[exercise.id], let url = URL(string: text) {
                    Link("打开动作演示", destination: url)
                }
                if saved { Text("链接已保存").font(.caption).foregroundStyle(Palette.accent) }
            }
        }
        .scrollContentBackground(.hidden).background(Palette.canvas)
        .navigationTitle(exercise.name).navigationBarTitleDisplayMode(.inline)
        .onAppear { link = store.wellness.exerciseLinks[exercise.id] ?? "" }
        .fitnessError($error)
    }
}
