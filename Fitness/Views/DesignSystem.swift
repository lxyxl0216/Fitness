import SwiftUI

enum AppAppearance: String, CaseIterable, Identifiable {
    static let storageKey = "appearanceMode"

    case light
    case dark

    var id: String { rawValue }
    var title: String { self == .light ? "浅色" : "深色" }
    var colorScheme: ColorScheme { self == .light ? .light : .dark }
}

enum Palette {
    static let accent = Color(uiColor: UIColor { $0.userInterfaceStyle == .dark
        ? UIColor(red: 0.788, green: 0.659, blue: 0.298, alpha: 1)
        : UIColor(red: 0.549, green: 0.184, blue: 0.243, alpha: 1) })
    static let button = Color(red: 0.549, green: 0.184, blue: 0.243)
    static let buttonText = Color(red: 0.847, green: 0.831, blue: 0.800)
    static let canvas = Color(uiColor: UIColor { $0.userInterfaceStyle == .dark
        ? UIColor(red: 0.055, green: 0.055, blue: 0.071, alpha: 1)
        : UIColor(red: 0.961, green: 0.957, blue: 0.945, alpha: 1) })
    static let surface = Color(uiColor: UIColor { $0.userInterfaceStyle == .dark
        ? UIColor(red: 0.133, green: 0.133, blue: 0.125, alpha: 1)
        : UIColor.white })
    static let ink = Color(uiColor: UIColor { $0.userInterfaceStyle == .dark
        ? UIColor(red: 0.847, green: 0.831, blue: 0.800, alpha: 1)
        : UIColor(red: 0.055, green: 0.055, blue: 0.071, alpha: 1) })
    static let muted = Color(uiColor: UIColor { $0.userInterfaceStyle == .dark
        ? UIColor(red: 0.635, green: 0.616, blue: 0.584, alpha: 1)
        : UIColor(red: 0.373, green: 0.361, blue: 0.380, alpha: 1) })
}

struct Surface<Content: View>: View {
    @ViewBuilder var content: Content
    var body: some View {
        content.frame(maxWidth: .infinity, alignment: .leading).padding(20)
            .background(Palette.surface, in: RoundedRectangle(cornerRadius: 22))
    }
}

struct PrimaryButton: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.font(.headline).frame(maxWidth: .infinity, minHeight: 48)
            .foregroundStyle(Palette.buttonText).background(Palette.button, in: Capsule())
            .opacity(configuration.isPressed ? 0.8 : 1)
    }
}

struct SectionHeading: View {
    var title: String
    var subtitle: String? = nil
    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title).font(.title3.bold()).foregroundStyle(Palette.ink)
            if let subtitle { Text(subtitle).font(.caption).foregroundStyle(Palette.muted) }
        }
    }
}

struct ScreenContent<Content: View>: View {
    @ViewBuilder var content: Content
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) { content }
                .frame(maxWidth: 680).padding(.horizontal, 20).padding(.vertical, 16)
                .frame(maxWidth: .infinity)
        }.background(Palette.canvas)
    }
}

struct ValueField: View {
    var label: String
    @Binding var text: String
    var unit = ""
    var identifier = ""
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label).font(.subheadline).foregroundStyle(Palette.muted)
            HStack {
                TextField("", text: $text).keyboardType(.decimalPad)
                    .accessibilityLabel(label).accessibilityIdentifier(identifier)
                if !unit.isEmpty { Text(unit).font(.subheadline).foregroundStyle(Palette.muted) }
            }
        }.padding(.vertical, 4)
    }
}

extension Date {
    var dayText: String { formatted(.dateTime.month().day().weekday(.wide).locale(Locale(identifier: "zh_CN"))) }
    var shortText: String { formatted(.dateTime.month().day().locale(Locale(identifier: "zh_CN"))) }
}

struct NutritionSummary: View {
    var intake: NutritionValues
    var targets: NutritionValues?
    var title = "今日摄入"
    var body: some View {
        Surface {
            VStack(alignment: .leading, spacing: 22) {
                Text(title).font(.subheadline.weight(.medium)).foregroundStyle(Palette.muted)
                ViewThatFits(in: .horizontal) {
                    HStack(alignment: .center, spacing: 20) { energy; Spacer(); ring }
                    VStack(alignment: .leading, spacing: 16) { energy; ring }
                }
                Divider()
                HStack(alignment: .top) {
                    macro("蛋白质", value: intake.protein, target: targets?.protein)
                    Spacer()
                    macro("碳水", value: intake.carbs, target: targets?.carbs)
                    Spacer()
                    macro("脂肪", value: intake.fat, target: targets?.fat)
                }
            }
        }
    }

    private var energy: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(intake.calories.fitnessText).font(.system(size: 48, weight: .semibold, design: .rounded))
                .monospacedDigit().minimumScaleFactor(0.7).lineLimit(1)
            Text(targets.map { "每日目标 \($0.calories.fitnessText) kcal" } ?? "kcal · 尚未设置目标")
                .font(.caption).foregroundStyle(Palette.muted)
        }
    }

    private var ring: some View {
        let ratio = targets.map { min(1, max(0, intake.calories / max(1, $0.calories))) } ?? 0
        return ZStack {
            Circle().stroke(Palette.accent.opacity(0.12), lineWidth: 9)
            Circle().trim(from: 0, to: ratio).stroke(Palette.accent, style: StrokeStyle(lineWidth: 9, lineCap: .round))
                .rotationEffect(.degrees(-90))
            VStack(spacing: 2) {
                Text(targets == nil ? "未设置" : "\(Int(ratio * 100))%")
                    .font(.headline.monospacedDigit())
                Text("目标进度").font(.caption2).foregroundStyle(Palette.muted)
            }
        }.frame(width: 100, height: 100).padding(5)
        .accessibilityElement(children: .combine)
    }

    private func macro(_ name: String, value: Double, target: Double?) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(name).font(.caption).foregroundStyle(Palette.muted)
            Text("\(value.fitnessText) g").font(.headline.monospacedDigit())
            if let target { Text("目标 \(target.fitnessText) g").font(.caption2).foregroundStyle(Palette.muted) }
        }
    }
}
