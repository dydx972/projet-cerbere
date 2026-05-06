import SwiftUI

struct ContentView: View {
    @State private var isOpening = false
    @State private var isOpen = false
    @State private var countdown = 0
    @State private var statusText = ""
    @State private var timer: Timer?

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: isOpen ? "door.left.hand.open" : "lock.shield")
                .font(.system(size: 36))
                .foregroundColor(isOpen ? .green : .blue)

            Text("CERBERE")
                .font(.system(size: 12, weight: .bold, design: .monospaced))
                .foregroundColor(.blue)

            if isOpen && countdown > 0 {
                Text("\(countdown)s")
                    .font(.system(size: 20, weight: .bold, design: .monospaced))
                    .foregroundColor(.green)
            }

            Button(action: { Task { await ouvrirPorte() } }) {
                if isOpening {
                    ProgressView()
                        .tint(.white)
                } else {
                    Text(isOpen ? "OUVERTE" : "OUVRIR")
                        .font(.system(size: 14, weight: .bold, design: .monospaced))
                }
            }
            .buttonStyle(.borderedProminent)
            .tint(isOpen ? .green : .blue)
            .disabled(isOpening || isOpen)

            if !statusText.isEmpty {
                Text(statusText)
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundColor(isOpen ? .green : .red)
                    .multilineTextAlignment(.center)
            }
        }
    }

    func ouvrirPorte() async {
        isOpening = true
        statusText = ""

        guard let url = URL(string: "http://192.168.1.199/api/porte_ouvrir.php") else {
            isOpening = false
            statusText = "Erreur URL"
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 10
        request.httpBody = try? JSONSerialization.data(withJSONObject: ["duree": 5])

        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]

            if json?["success"] as? Bool == true {
                isOpening = false
                isOpen = true
                statusText = "Porte ouverte 5s"
                countdown = 5
                WKInterfaceDevice.current().play(.success)

                timer?.invalidate()
                timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { t in
                    countdown -= 1
                    if countdown <= 0 {
                        t.invalidate()
                        isOpen = false
                        statusText = ""
                    }
                }
            } else {
                isOpening = false
                statusText = "Erreur serveur"
                WKInterfaceDevice.current().play(.failure)
            }
        } catch {
            isOpening = false
            statusText = "Connexion impossible"
            WKInterfaceDevice.current().play(.failure)
        }
    }
}
