import SwiftUI

struct ContentView: View {
    var body: some View {
        NavigationStack {
            ContentUnavailableView(
                "准备开始训练",
                systemImage: "figure.strengthtraining.traditional",
                description: Text("健身记录 App 的第一版即将从这里开始。")
            )
            .navigationTitle("Fitness")
        }
    }
}

#Preview {
    ContentView()
}
