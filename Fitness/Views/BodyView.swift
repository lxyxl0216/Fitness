import SwiftUI
import Charts

struct BodyView: View {
    @Environment(FitnessStore.self) private var store
    @State private var editing: BodyRecord?
    @State private var deleting: BodyRecord?
    @State private var error: String?

    private var chartRecords: [BodyRecord] {
        Array(store.data.bodyRecords.prefix(30).reversed())
    }

    var body: some View {
        List {
            Section {
                Button {
                    editing = BodyRecord(date: Date(), weight: 0)
                } label: {
                    Label("记录身体数据", systemImage: "plus.circle.fill")
                        .font(.headline).frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical, 8)
                }.accessibilityIdentifier("addBodyRecord")
            }
            if let latest = store.data.bodyRecords.first {
                Section("最近体重") {
                    HStack(alignment: .firstTextBaseline) {
                        Text(latest.weight.fitnessText).font(.largeTitle.bold()).monospacedDigit()
                        Text("kg").foregroundStyle(.secondary)
                        Spacer()
                        Text(latest.date, format: .dateTime.month().day()).font(.caption).foregroundStyle(.secondary)
                    }
                    if chartRecords.count > 1 {
                        Chart(chartRecords) { record in
                            LineMark(x: .value("日期", record.date), y: .value("体重", record.weight))
                            PointMark(x: .value("日期", record.date), y: .value("体重", record.weight))
                        }
                        .foregroundStyle(Palette.accent)
                        .chartYScale(domain: .automatic(includesZero: false))
                        .frame(height: 180)
                        .accessibilityLabel("最近 \(chartRecords.count) 条体重记录，最新 \(latest.weight.fitnessText) 千克")
                        Text("展示最近 30 条记录。")
                            .font(.caption).foregroundStyle(.secondary)
                    } else {
                        Text("再记录一次，就能看到体重趋势。")
                            .font(.subheadline).foregroundStyle(.secondary)
                    }
                }
                Section("全部记录 · 点击修改") {
                    ForEach(store.data.bodyRecords) { record in
                        Button { editing = record } label: {
                            VStack(alignment: .leading, spacing: 6) {
                                HStack {
                                    Text(record.date.formatted(date: .abbreviated, time: .shortened))
                                        .font(.subheadline)
                                    Spacer()
                                    Text("\(record.weight.fitnessText) kg").font(.headline)
                                }
                                if record.bodyFat != nil || record.waist != nil {
                                    Text([
                                        record.bodyFat.map { "体脂 \($0.fitnessText)%" },
                                        record.waist.map { "腰围 \($0.fitnessText) cm" }
                                    ].compactMap { $0 }.joined(separator: " · "))
                                    .font(.caption).foregroundStyle(.secondary)
                                }
                            }.foregroundStyle(.primary).padding(.vertical, 4).contentShape(Rectangle())
                        }
                        .accessibilityIdentifier("bodyRecord")
                        .buttonStyle(.plain)
                        .swipeActions {
                            Button("删除", role: .destructive) { deleting = record }
                        }
                    }
                }
            } else {
                Section {
                    ContentUnavailableView("看见自己的变化", systemImage: "chart.xyaxis.line",
                                           description: Text("从记录第一次体重开始，体脂和腰围可选。"))
                }
            }
        }
        .navigationTitle("身体数据")
        .scrollContentBackground(.hidden).background(Palette.canvas)
        .sheet(item: $editing) { record in BodyEditor(record: record) }
        .confirmationDialog("删除这条身体记录？", isPresented: Binding(
            get: { deleting != nil }, set: { if !$0 { deleting = nil } }
        ), titleVisibility: .visible) {
            Button("删除记录", role: .destructive) {
                guard let deleting else { return }
                do { try store.deleteBody(id: deleting.id) }
                catch { self.error = error.localizedDescription }
                self.deleting = nil
            }
        }
        .fitnessError($error)
    }
}

struct BodyEditor: View {
    @Environment(FitnessStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    private let id: UUID
    @State private var date: Date
    @State private var weight: String
    @State private var bodyFat: String
    @State private var waist: String
    @State private var error: String?
    @FocusState private var inputFocused: Bool

    init(record: BodyRecord) {
        id = record.id
        _date = State(initialValue: record.date)
        _weight = State(initialValue: record.weight == 0 ? "" : String(record.weight))
        _bodyFat = State(initialValue: record.bodyFat.map { String($0) } ?? "")
        _waist = State(initialValue: record.waist.map { String($0) } ?? "")
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("测量日期") {
                    DatePicker("日期", selection: $date, in: ...Date(), displayedComponents: .date)
                }
                Section("体重 · 必填") {
                    HStack {
                        TextField("输入体重", text: $weight)
                            .keyboardType(.decimalPad).focused($inputFocused)
                            .accessibilityIdentifier("bodyWeight")
                        Text("kg").foregroundStyle(.secondary)
                    }
                }
                Section("可选记录") {
                    HStack {
                        TextField("体脂率", text: $bodyFat).keyboardType(.decimalPad).focused($inputFocused)
                        Text("%").foregroundStyle(.secondary)
                    }
                    HStack {
                        TextField("腰围", text: $waist).keyboardType(.decimalPad).focused($inputFocused)
                        Text("cm").foregroundStyle(.secondary)
                    }
                }
                Section {
                    Text("尽量在相近时间和条件下记录，方便比较。数据仅保存在本机。")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            .navigationTitle("身体记录").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存", action: save).accessibilityIdentifier("saveBodyRecord")
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("收起键盘") { inputFocused = false }
                }
            }
            .fitnessError($error)
        }
        .interactiveDismissDisabled()
    }

    private func save() {
        do {
            guard let kg = InputNumber.decimal(weight) else {
                throw FitnessError.invalid("请填写有效体重。")
            }
            func optional(_ value: String, name: String) throws -> Double? {
                if value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return nil }
                guard let number = InputNumber.decimal(value) else {
                    throw FitnessError.invalid("\(name)格式不正确，也可以留空。")
                }
                return number
            }
            let record = try BodyRecord(id: id, date: date, weight: kg,
                                        bodyFat: optional(bodyFat, name: "体脂率"),
                                        waist: optional(waist, name: "腰围"))
            try store.saveBody(record)
            dismiss()
        } catch { self.error = error.localizedDescription }
    }
}
