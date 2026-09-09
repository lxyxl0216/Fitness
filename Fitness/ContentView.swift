import SwiftUI

struct ContentView: View {
    @AppStorage(AppAppearance.storageKey) private var appearance = AppAppearance.light.rawValue
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
        .tint(Palette.accent)
        .preferredColorScheme(AppAppearance(rawValue: appearance)?.colorScheme ?? .light)
        .environment(\.locale, Locale(identifier: "zh_CN"))
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
            NavigationStack { TrainingHub() }
                .tabItem { Label("训练", systemImage: "dumbbell") }
            NavigationStack { TrendsView() }
                .tabItem { Label("趋势", systemImage: "chart.xyaxis.line") }
            NavigationStack { ProfileView() }
                .tabItem { Label("我的", systemImage: "person.crop.circle") }
        }
    }
}

#Preview {
    ContentView()
}
