import Foundation

struct Exercise: Identifiable {
    let id: String
    let name: String
    let muscle: String
    let equipment: String
}

enum ExerciseCatalog {
    static let exercises: [Exercise] = [
        Exercise(id: "bench", name: "杠铃卧推", muscle: "胸部", equipment: "杠铃"),
        Exercise(id: "incline", name: "上斜哑铃卧推", muscle: "胸部", equipment: "哑铃"),
        Exercise(id: "fly", name: "绳索夹胸", muscle: "胸部", equipment: "绳索"),
        Exercise(id: "pushup", name: "俯卧撑", muscle: "胸部", equipment: "自重"),
        Exercise(id: "press", name: "哑铃肩推", muscle: "肩部", equipment: "哑铃"),
        Exercise(id: "lateral", name: "哑铃侧平举", muscle: "肩部", equipment: "哑铃"),
        Exercise(id: "facepull", name: "绳索面拉", muscle: "肩部", equipment: "绳索"),
        Exercise(id: "pullup", name: "引体向上", muscle: "背部", equipment: "自重"),
        Exercise(id: "pulldown", name: "高位下拉", muscle: "背部", equipment: "器械"),
        Exercise(id: "row", name: "坐姿划船", muscle: "背部", equipment: "器械"),
        Exercise(id: "barbellrow", name: "杠铃划船", muscle: "背部", equipment: "杠铃"),
        Exercise(id: "squat", name: "杠铃深蹲", muscle: "腿部", equipment: "杠铃"),
        Exercise(id: "rdl", name: "罗马尼亚硬拉", muscle: "腿部", equipment: "杠铃"),
        Exercise(id: "legpress", name: "腿举", muscle: "腿部", equipment: "器械"),
        Exercise(id: "legcurl", name: "腿弯举", muscle: "腿部", equipment: "器械"),
        Exercise(id: "calf", name: "站姿提踵", muscle: "腿部", equipment: "器械"),
        Exercise(id: "curl", name: "哑铃弯举", muscle: "手臂", equipment: "哑铃"),
        Exercise(id: "triceps", name: "绳索下压", muscle: "手臂", equipment: "绳索"),
        Exercise(id: "crunch", name: "卷腹", muscle: "核心", equipment: "自重"),
        Exercise(id: "kneeraise", name: "悬垂举膝", muscle: "核心", equipment: "自重")
    ]

    static func find(_ id: String) -> Exercise? {
        exercises.first { $0.id == id }
    }

    static let templates = [
        WorkoutTemplate(name: "推 · 胸肩三头", exerciseIDs: ["bench", "incline", "press", "triceps"]),
        WorkoutTemplate(name: "拉 · 背部二头", exerciseIDs: ["pulldown", "row", "facepull", "curl"]),
        WorkoutTemplate(name: "腿 · 下肢核心", exerciseIDs: ["squat", "rdl", "legcurl", "crunch"])
    ]
}
