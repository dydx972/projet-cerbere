import SwiftUI

struct LoginView: View {
    @State private var username = ""
    @State private var password = ""
    @State private var showError = false
    @Binding var isLoggedIn: Bool
    
    var body: some View {
        ZStack {
            Color(red: 0.03, green: 0.05, blue: 0.07).ignoresSafeArea()
            VStack(spacing: 30) {
                Text("⬡ CERBÈRE").font(.largeTitle).bold().foregroundColor(Color.cyan)
                VStack(spacing: 20) {
                    TextField("Identifiant", text: $username).padding().background(Color.white.opacity(0.1)).cornerRadius(5).foregroundColor(.white)
                    SecureField("Mot de passe", text: $password).padding().background(Color.white.opacity(0.1)).cornerRadius(5).foregroundColor(.white)
                }.padding(.horizontal, 40)
                if showError { Text("Identifiants incorrects").foregroundColor(.red).font(.caption) }
                Button(action: login) {
                    Text("CONNEXION").bold().frame(maxWidth: .infinity).padding().background(Color.cyan).foregroundColor(.black).cornerRadius(5)
                }.padding(.horizontal, 40)
            }
        }
    }
    func login() {
        if username == "admin" && password == "admin123" { isLoggedIn = true }
        else { showError = true }
    }
}
