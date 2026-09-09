import SwiftUI
import UniformTypeIdentifiers

struct ProfileView: View {
    @Environment(FitnessStore.self) private var store
    @AppStorage(AppAppearance.storageKey) private var appearance = AppAppearance.light.rawValue
    @State private var exporting = false
    @State private var backup: FitnessBackup?
    @State private var error: String?

    var body: some View {
        ScreenContent {
            Surface {
                VStack(alignment: .leading, spacing: 20) {
                    HStack {
                        Image(systemName: "person.crop.circle.fill").font(.system(size: 44)).foregroundStyle(Palette.accent)
                        VStack(alignment: .leading, spacing: 5) {
                            Text(store.wellness.profile.name.isEmpty ? "我的健康档案" : store.wellness.profile.name).font(.title2.bold())
                            Text("为自己，积累每一天的改变").font(.caption).foregroundStyle(Palette.muted)
                        }
                    }
                    NavigationLink("编辑个人资料") { ProfileEditor() }
                    Divider()
                    HStack {
                        metric("当前体重", store.data.bodyRecords.first.map { "\($0.weight.fitnessText) kg" } ?? "待记录")
                        Spacer()
                        metric("目标体重", store.wellness.profile.targetWeight.map { "\($0.fitnessText) kg" } ?? "待设置")
                    }
                }
            }
            if let weight = store.data.bodyRecords.first?.weight,
               let energy = store.wellness.profile.restingEnergy(weight: weight) {
                Surface {
                    VStack(alignment: .leading, spacing: 8) {
                        SectionHeading(title: "静息能量估算", subtitle: "\(energy.fitnessText) kcal / 日")
                        Text("根据身体档案与最近体重估算，不等于每日饮食目标。").font(.caption).foregroundStyle(Palette.muted)
                        Link("计算依据 · Mifflin–St Jeor", destination: URL(string: "https://pubmed.ncbi.nlm.nih.gov/2305711/")!).font(.caption)
                    }
                }
            }
            Surface {
                VStack(alignment: .leading, spacing: 14) {
                    SectionHeading(title: "界面外观", subtitle: "选择后立即生效，并在下次打开时保留")
                    Picker("界面外观", selection: $appearance) {
                        ForEach(AppAppearance.allCases) { mode in
                            Text(mode.title).tag(mode.rawValue)
                        }
                    }
                    .pickerStyle(.segmented)
                    .accessibilityIdentifier("appearanceMode")
                }
            }
            Surface {
                VStack(spacing: 0) {
                    row("身体数据", symbol: "figure.stand") { BodyView() }.accessibilityIdentifier("bodyData")
                    Divider()
                    row("每日营养目标", symbol: "scope") { TargetsEditor() }
                    Divider()
                    row("饮食计划", symbol: "calendar") { MealPlansView() }
                }
            }
            Surface {
                VStack(spacing: 0) {
                    row("我的食物", symbol: "fork.knife") { FoodLibraryView() }.accessibilityIdentifier("foodLibrary")
                    Divider()
                    row("我的补剂", symbol: "pills") { FoodLibraryView(supplements: true) }
                    Divider()
                    row("采购清单", symbol: "basket") { ShoppingView() }
                }
            }
            Button {
                do { backup = FitnessBackup(data: try JSONEncoder().encode(store.data)); exporting = true }
                catch { self.error = error.localizedDescription }
            } label: { Label("导出数据备份", systemImage: "square.and.arrow.up").frame(maxWidth: .infinity, minHeight: 44) }
            Text("数据保存在本机。导出文件包含训练、饮食及身体记录，请妥善保存。").font(.caption).foregroundStyle(Palette.muted)
        }
        .navigationTitle("我的")
        .fileExporter(isPresented: $exporting, document: backup, contentType: .json, defaultFilename: "Fitness-backup") { result in
            if case .failure(let failure) = result { error = failure.localizedDescription }
        }
        .fitnessError($error)
    }

    private func metric(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(title).font(.caption).foregroundStyle(Palette.muted)
            Text(value).font(.title3.bold()).monospacedDigit()
        }
    }

    private func row<Destination: View>(_ title: String, symbol: String, @ViewBuilder destination: () -> Destination) -> some View {
        NavigationLink(destination: destination) {
            HStack {
                Image(systemName: symbol).foregroundStyle(Palette.accent).frame(width: 28)
                Text(title).foregroundStyle(.primary)
                Spacer()
                Image(systemName: "chevron.right").font(.caption).foregroundStyle(Palette.muted)
            }.frame(minHeight: 54).contentShape(Rectangle())
        }.buttonStyle(.plain)
    }
}

struct FitnessBackup: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }
    var data: Data
    init(data: Data) { self.data = data }
    init(configuration: ReadConfiguration) throws { data = configuration.file.regularFileContents ?? Data() }
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper { FileWrapper(regularFileWithContents: data) }
}

struct ProfileEditor: View {
    @Environment(FitnessStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var profile = BodyProfile()
    @State private var age = ""
    @State private var height = ""
    @State private var target = ""
    @State private var loaded = false
    @State private var error: String?

    var body: some View {
        Form {
            Section("个人资料 · 均可留空") {
                TextField("称呼", text: $profile.name)
                Picker("生理性别（用于能量公式）", selection: $profile.sex) {
                    ForEach(ProfileSex.allCases) { Text($0.rawValue).tag($0) }
                }
                ValueField(label: "年龄", text: $age, unit: "岁")
                ValueField(label: "身高", text: $height, unit: "cm")
                ValueField(label: "目标体重", text: $target, unit: "kg")
            }
            Text("填写年龄、身高和生理性别，并记录体重后，可以查看成人静息能量估算。").font(.caption).foregroundStyle(Palette.muted)
            if let error { Text(error).foregroundStyle(.red) }
            Button("保存资料") {
                do {
                    func optional(_ value: String) throws -> Double? {
                        if value.trimmingCharacters(in: .whitespaces).isEmpty { return nil }
                        guard let number = InputNumber.decimal(value) else { throw FitnessError.invalid("请填写有效数字或留空。") }
                        return number
                    }
                    let ageValue = try optional(age)
                    guard ageValue == nil || (ageValue! >= 18 && ageValue! <= 120 && ageValue!.rounded() == ageValue!) else { throw FitnessError.invalid("年龄需为 18-120 的整数。") }
                    profile.age = ageValue.map(Int.init)
                    profile.height = try optional(height)
                    profile.targetWeight = try optional(target)
                    try store.saveProfile(profile)
                    dismiss()
                } catch { self.error = error.localizedDescription }
            }
        }
        .navigationTitle("个人资料")
        .onAppear {
            guard !loaded else { return }; loaded = true
            profile = store.wellness.profile
            age = profile.age.map(String.init) ?? ""
            height = profile.height.map { String($0) } ?? ""
            target = profile.targetWeight.map { String($0) } ?? ""
        }
    }
}
