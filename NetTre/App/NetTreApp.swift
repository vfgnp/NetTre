import SwiftUI

@main
struct NetTreApp: App {
    @State private var model = AppModel()

    var body: some Scene {
        WindowGroup {
            RootTabView()
                .environment(model)
        }
    }
}
