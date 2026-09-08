import SwiftUI

struct PrescriptionEditor: View {
    @Binding var prescription: ExercisePrescription
    let name: String

    var body: some View {
        Form {
            Section("每组目标次数") {
                ForEach(prescription.reps.indices, id: \.self) { index in
                    Stepper("第 \(index + 1) 组：\(prescription.reps[index]) 次", value: $prescription.reps[index], in: 1...999)
                }.onDelete { prescription.reps.remove(atOffsets: $0) }
                Button("添加一组") { prescription.reps.append(prescription.reps.last ?? 10) }.disabled(prescription.reps.count >= 20)
            }
            Section("组间安排") {
                Stepper("休息 \(prescription.restSeconds) 秒", value: $prescription.restSeconds, in: 0...1800, step: 15)
                Picker("目标 RPE", selection: $prescription.targetRPE) {
                    Text("不设置").tag(Optional<Double>.none)
                    ForEach(1...10, id: \.self) { Text("\($0)").tag(Optional(Double($0))) }
                }
                Text("RPE 表示主观用力程度，10 为最大努力。此处只记录你的计划，不自动推荐加重。")
                    .font(.caption).foregroundStyle(Palette.muted)
            }
        }.scrollContentBackground(.hidden).background(Palette.canvas).navigationTitle(name)
    }
}
