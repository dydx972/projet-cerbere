import SwiftUI

struct DoorControlView: View {
    @State private var selectedDuree = "5"
    @State private var isOpening = false
    @State private var isOpen = false
    @State private var statusMessage = ""
    @State private var statusColor = "8b949e"
    @State private var countdown = 0
    @State private var timer: Timer?

    let durees = ["5", "10", "15", "30"]

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                Spacer(minLength: 30)

                // Door icon
                ZStack {
                    Circle()
                        .fill(isOpen ? Color(hex: "3fb950").opacity(0.15) : Color(hex: "1f6feb").opacity(0.1))
                        .frame(width: 180, height: 180)
                    Circle()
                        .stroke(isOpen ? Color(hex: "3fb950").opacity(0.4) : Color(hex: "30363d"), lineWidth: 2)
                        .frame(width: 180, height: 180)
                    VStack(spacing: 8) {
                        Image(systemName: isOpen ? "door.left.hand.open" : "door.left.hand.closed")
                            .font(.system(size: 56))
                            .foregroundColor(isOpen ? Color(hex: "3fb950") : Color(hex: "58a6ff"))
                        if isOpen && countdown > 0 {
                            Text("\(countdown)s")
                                .font(.system(size: 22, weight: .bold, design: .monospaced))
                                .foregroundColor(Color(hex: "3fb950"))
                        }
                    }
                }

                VStack(spacing: 4) {
                    Text("Porte Salle W13")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(.white)
                    Text("192.168.1.49 - Gache + Ventouse")
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundColor(Color(hex: "484f58"))
                }

                // Duree selector
                VStack(spacing: 8) {
                    Text("DUREE D'OUVERTURE")
                        .font(.system(size: 10, weight: .semibold, design: .monospaced))
                        .foregroundColor(Color(hex: "8b949e"))

                    HStack(spacing: 8) {
                        ForEach(durees, id: \.self) { d in
                            Button(action: { selectedDuree = d }) {
                                Text("\(d)s")
                                    .font(.system(size: 14, weight: .semibold, design: .monospaced))
                                    .foregroundColor(selectedDuree == d ? .white : Color(hex: "8b949e"))
                                    .frame(width: 70, height: 40)
                                    .background(selectedDuree == d ? Color(hex: "1f6feb") : Color(hex: "21262d"))
                                    .cornerRadius(8)
                            }
                            .buttonStyle(.plain)
                            .disabled(isOpening || isOpen)
                        }
                    }
                }

                // Bouton ouverture
                Button(action: { Task { await ouvrirPorte() } }) {
                    HStack(spacing: 10) {
                        if isOpening {
                            ProgressView()
                                .controlSize(.small)
                                .tint(.white)
                        }
                        Text(isOpen ? "PORTE OUVERTE" : isOpening ? "OUVERTURE..." : "OUVRIR LA PORTE")
                            .font(.system(size: 15, weight: .bold, design: .monospaced))
                            .tracking(2)
                    }
                    .foregroundColor(.white)
                    .frame(width: 350, height: 50)
                    .background(isOpen ? Color(hex: "3fb950") : isOpening ? Color(hex: "484f58") : Color(hex: "1f6feb"))
                    .cornerRadius(12)
                }
                .buttonStyle(.plain)
                .disabled(isOpening || isOpen)

                // Status
                if !statusMessage.isEmpty {
                    Text(statusMessage)
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundColor(Color(hex: statusColor))
                }

                Spacer(minLength: 30)
            }
            .frame(maxWidth: .infinity)
        }
        .background(Color(hex: "0d1117"))
    }

    func startCountdown() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { t in
            countdown -= 1
            if countdown <= 0 {
                t.invalidate()
                isOpen = false
                statusMessage = "Porte verrouillee"
                statusColor = "8b949e"
            }
        }
    }

    func ouvrirPorte() async {
        isOpening = true
        statusMessage = "Envoi de la commande..."
        statusColor = "58a6ff"

        do {
            let result = try await APIService.shared.post("porte_ouvrir.php", body: [
                "duree": Int(selectedDuree) ?? 5
            ])

            if result["success"] as? Bool == true {
                isOpening = false
                isOpen = true
                statusColor = "3fb950"
                statusMessage = "Porte ouverte pour \(selectedDuree) secondes"
                countdown = Int(selectedDuree) ?? 5
                startCountdown()
            } else {
                isOpening = false
                statusColor = "f85149"
                statusMessage = result["error"] as? String ?? "Erreur inconnue"
            }
        } catch {
            isOpening = false
            statusColor = "f85149"
            statusMessage = "Erreur de connexion"
        }
    }
}
