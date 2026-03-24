import SwiftUI

struct ContentView: View {
    @StateObject var service = DataService()
    @State private var isLoggedIn = false
    
    var body: some View {
        Group {
            if isLoggedIn {
                MainTabView(service: service)
            } else {
                LoginView(isLoggedIn: $isLoggedIn)
            }
        }
    }
}
