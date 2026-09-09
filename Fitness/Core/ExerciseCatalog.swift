import Foundation

struct Exercise: Identifiable {
    let id: String
    let name: String
    let muscle: String
    let equipment: String
    let gifPath: String

    private static let mediaBase = URL(string: "https://cdn.jsdelivr.net/gh/JahelCuadrado/ExerciseGymGifsDB@v1.1.0/")!
    var gifURL: URL { URL(string: Self.mediaBase.absoluteString + gifPath)! }
    var thumbnailURL: URL { URL(string: Self.mediaBase.absoluteString + gifPath.replacingOccurrences(of: ".gif", with: ".thumb.webp"))! }
}

enum ExerciseCatalog {
    static let exercises: [Exercise] = [
        Exercise(id: "bench", name: "杠铃卧推", muscle: "胸部", equipment: "杠铃", gifPath: "pectorals/barbell-bench-press.gif"),
        Exercise(id: "incline", name: "上斜哑铃卧推", muscle: "胸部", equipment: "哑铃", gifPath: "pectorals/dumbbell-incline-bench-press.gif"),
        Exercise(id: "fly", name: "绳索夹胸", muscle: "胸部", equipment: "绳索", gifPath: "pectorals/cable-middle-fly.gif"),
        Exercise(id: "pushup", name: "俯卧撑", muscle: "胸部", equipment: "自重", gifPath: "pectorals/push-up.gif"),
        Exercise(id: "press", name: "哑铃肩推", muscle: "肩部", equipment: "哑铃", gifPath: "delts/dumbbell-seated-shoulder-press.gif"),
        Exercise(id: "lateral", name: "哑铃侧平举", muscle: "肩部", equipment: "哑铃", gifPath: "delts/dumbbell-lateral-raise.gif"),
        Exercise(id: "facepull", name: "绳索面拉", muscle: "肩部", equipment: "绳索", gifPath: "delts/cable-standing-rear-delt-row-with-rope.gif"),
        Exercise(id: "pullup", name: "引体向上", muscle: "背部", equipment: "自重", gifPath: "lats/pull-up.gif"),
        Exercise(id: "pulldown", name: "高位下拉", muscle: "背部", equipment: "器械", gifPath: "lats/cable-pulldown.gif"),
        Exercise(id: "row", name: "坐姿划船", muscle: "背部", equipment: "器械", gifPath: "upper-back/cable-seated-row.gif"),
        Exercise(id: "barbellrow", name: "杠铃划船", muscle: "背部", equipment: "杠铃", gifPath: "upper-back/barbell-bent-over-row.gif"),
        Exercise(id: "squat", name: "杠铃深蹲", muscle: "腿部", equipment: "杠铃", gifPath: "glutes/barbell-full-squat.gif"),
        Exercise(id: "rdl", name: "罗马尼亚硬拉", muscle: "腿部", equipment: "杠铃", gifPath: "glutes/barbell-romanian-deadlift.gif"),
        Exercise(id: "legpress", name: "腿举", muscle: "腿部", equipment: "器械", gifPath: "glutes/sled-45-leg-press.gif"),
        Exercise(id: "legcurl", name: "腿弯举", muscle: "腿部", equipment: "器械", gifPath: "hamstrings/lever-lying-leg-curl.gif"),
        Exercise(id: "calf", name: "站姿提踵", muscle: "腿部", equipment: "器械", gifPath: "calves/lever-standing-calf-raise.gif"),
        Exercise(id: "curl", name: "哑铃弯举", muscle: "手臂", equipment: "哑铃", gifPath: "biceps/dumbbell-alternate-biceps-curl.gif"),
        Exercise(id: "triceps", name: "绳索下压", muscle: "手臂", equipment: "绳索", gifPath: "triceps/cable-pushdown.gif"),
        Exercise(id: "crunch", name: "卷腹", muscle: "核心", equipment: "自重", gifPath: "abs/crunch-floor.gif"),
        Exercise(id: "kneeraise", name: "悬垂举膝", muscle: "核心", equipment: "自重", gifPath: "abs/hanging-leg-raise.gif")
    ]

    static let muscles = ["胸部", "背部", "肩部", "腿部", "手臂", "核心"]

    static func find(_ id: String) -> Exercise? {
        exercises.first { $0.id == id }
    }

    static let templates = [
        WorkoutTemplate(name: "推 · 胸肩三头", exerciseIDs: ["bench", "incline", "press", "triceps"]),
        WorkoutTemplate(name: "拉 · 背部二头", exerciseIDs: ["pulldown", "row", "facepull", "curl"]),
        WorkoutTemplate(name: "腿 · 下肢核心", exerciseIDs: ["squat", "rdl", "legcurl", "crunch"])
    ]
}
