import SwiftUI

struct ContentView: View {
    @State private var store: FitnessStore?
    @State private var loadError: String?

    var body: some View {
        Group {
            if let store {
                AppTabs().environment(store)
            } else if let loadError {
                ContentUnavailableView {
                    Label("暂时无法读取记录", systemImage: "externaldrive.badge.exclamationmark")
                } description: {
                    Text("原文件已保留，不会覆盖。\n\(loadError)")
                } actions: {
                    Button("重试", action: load)
                }
            } else {
                ProgressView("读取记录…")
            }
        }
        .tint(.orange)
        .task { if store == nil { load() } }
    }

    private func load() {
        do {
            let directory = try FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask,
                                                         appropriateFor: nil, create: true)
            store = try FitnessStore(url: directory.appendingPathComponent("Fitness/fitness.json"))
            loadError = nil
        } catch {
            loadError = error.localizedDescription
        }
    }
}

private struct AppTabs: View {
    var body: some View {
        TabView {
            NavigationStack { HomeView() }
                .tabItem { Label("今日", systemImage: "sun.max") }
            NavigationStack { PlansView() }
                .tabItem { Label("计划", systemImage: "list.bullet.clipboard") }
            NavigationStack { HistoryView() }
                .tabItem { Label("历史", systemImage: "clock.arrow.circlepath") }
            NavigationStack { BodyView() }
                .tabItem { Label("身体", systemImage: "figure.stand") }
        }
    }
}

#Preview {
    ContentView()
}
