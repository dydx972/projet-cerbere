import SwiftUI

@main
struct CerbereMacApp: App {
    var body: some Scene {
        WindowGroup {
            LoginView()
                .preferredColorScheme(.dark)
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 1100, height: 700)
    }
}
