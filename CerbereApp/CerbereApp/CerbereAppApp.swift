import SwiftUI

@main
struct CerbereAppApp: App {
    var body: some Scene {
        WindowGroup {
            LoginView()
                .preferredColorScheme(.dark)
        }
    }
}
