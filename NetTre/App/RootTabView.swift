import SwiftUI

/// タブ（学習・計算・成績・設定）。出題はタブバーを隠すため fullScreenCover（詳細設計 §7.1）
struct RootTabView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        @Bindable var model = model
        TabView {
            NavigationStack { HomeView() }
                .tabItem { Label("学習", systemImage: "book") }
            NavigationStack { CalculatorMenuView() }
                .tabItem { Label("計算", systemImage: "function") }
            NavigationStack { StatsView() }
                .tabItem { Label("成績", systemImage: "chart.bar") }
            NavigationStack { SettingsView() }
                .tabItem { Label("設定", systemImage: "gearshape") }
        }
        .fullScreenCover(item: $model.activeSession, onDismiss: model.historyChanged) { session in
            QuizFlowView(session: session)
        }
    }
}
