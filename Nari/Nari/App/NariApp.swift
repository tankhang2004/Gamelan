import SwiftUI

@main
struct NariApp: App {
    @State private var services = AppServices()
    @State private var router = AppRouter()

    var body: some Scene {
        WindowGroup {
            RootView(services: services, router: router)
                .preferredColorScheme(.dark)
                .persistentSystemOverlays(.hidden)
                .statusBarHidden()
        }
    }
}
