import SwiftUI

struct LoginView: View {
    @State private var username = ""
    @State private var password = ""
    @State private var showError = false
    @State private var isLoggedIn = false

    var body: some View {
        if isLoggedIn {
            MainTabView(onLogout: { isLoggedIn = false })
        } else {
            ZStack {
                Color(hex: "0d1117").ignoresSafeArea()

                VStack(spacing: 30) {
                    Spacer()

                    VStack(spacing: 8) {
                        Text("CERBERE")
                            .font(.system(size: 36, weight: .black, design: .monospaced))
                            .foregroundColor(Color(hex: "58a6ff"))
                            .tracking(6)
                        Text("CONTROLE D'ACCES INTELLIGENT")
                            .font(.system(size: 10, weight: .medium, design: .monospaced))
                            .foregroundColor(Color(hex: "8b949e"))
                            .tracking(3)
                    }

                    VStack(spacing: 16) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("IDENTIFIANT")
                                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                                .foregroundColor(Color(hex: "8b949e"))
                            TextField("", text: $username)
                                .textFieldStyle(.plain)
                                .padding(12)
                                .background(Color(hex: "161b22"))
                                .cornerRadius(6)
                                .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color(hex: "30363d")))
                                .foregroundColor(.white)
                                .autocapitalization(.none)
                                .disableAutocorrection(true)
                        }

                        VStack(alignment: .leading, spacing: 6) {
                            Text("MOT DE PASSE")
                                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                                .foregroundColor(Color(hex: "8b949e"))
                            SecureField("", text: $password)
                                .textFieldStyle(.plain)
                                .padding(12)
                                .background(Color(hex: "161b22"))
                                .cornerRadius(6)
                                .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color(hex: "30363d")))
                                .foregroundColor(.white)
                        }

                        if showError {
                            Text("Identifiants incorrects")
                                .font(.system(size: 12, design: .monospaced))
                                .foregroundColor(Color(hex: "f85149"))
                        }

                        Button(action: login) {
                            Text("CONNEXION")
                                .font(.system(size: 14, weight: .bold, design: .monospaced))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(14)
                                .background(Color(hex: "1f6feb"))
                                .cornerRadius(6)
                        }
                    }
                    .padding(.horizontal, 40)

                    Spacer()

                    Text("v1.0 — Lycee Joseph Gaillard")
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundColor(Color(hex: "484f58"))
                        .padding(.bottom, 20)
                }
            }
        }
    }

    func login() {
        if username == "admin" && password == "admin123" {
            isLoggedIn = true
            showError = false
        } else {
            showError = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                showError = false
            }
        }
    }
}

extension Color {
    init(hex: String) {
        let scanner = Scanner(string: hex)
        var rgb: UInt64 = 0
        scanner.scanHexInt64(&rgb)
        self.init(
            red: Double((rgb >> 16) & 0xFF) / 255,
            green: Double((rgb >> 8) & 0xFF) / 255,
            blue: Double(rgb & 0xFF) / 255
        )
    }
}
