import SwiftUI

@main
struct CuraApp: App {
    @State private var container = ServiceContainer.mock
    @State private var session   = AppSession()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(container)
                .environment(session)
        }
    }
}
