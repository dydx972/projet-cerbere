import SwiftUI
import CoreNFC

struct DoorControlView: View {
    @State private var selectedDuree = "5"
    @State private var isOpening = false
    @State private var isOpen = false
    @State private var statusMessage = ""
    @State private var statusColor = "8b949e"
    @State private var countdown = 0
    @State private var timer: Timer?
    @StateObject private var nfcService = NFCService()

    let durees = ["5", "10", "15", "30"]

    var body: some View {
        NavigationView {
            ZStack {
                Color(hex: "0d1117").ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 24) {

                        // Door icon
                        ZStack {
                            Circle()
                                .fill(doorOpen ? Color(hex: "3fb950").opacity(0.15) : Color(hex: "1f6feb").opacity(0.1))
                                .frame(width: 150, height: 150)
                            Circle()
                                .stroke(doorOpen ? Color(hex: "3fb950").opacity(0.4) : Color(hex: "30363d"), lineWidth: 2)
                                .frame(width: 150, height: 150)
                            VStack(spacing: 8) {
                                Image(systemName: doorOpen ? "door.left.hand.open" : "door.left.hand.closed")
                                    .font(.system(size: 46))
                                    .foregroundColor(doorOpen ? Color(hex: "3fb950") : Color(hex: "58a6ff"))
                                if isOpen && countdown > 0 {
                                    Text("\(countdown)s")
                                        .font(.system(size: 18, weight: .bold, design: .monospaced))
                                        .foregroundColor(Color(hex: "3fb950"))
                                }
                            }
                        }
                        .padding(.top, 20)

                        VStack(spacing: 4) {
                            Text("Porte Salle W13")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(.white)
                            Text("192.168.1.49 - Gache + Ventouse")
                                .font(.system(size: 11, design: .monospaced))
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
                                            .frame(width: 60, height: 40)
                                            .background(selectedDuree == d ? Color(hex: "1f6feb") : Color(hex: "21262d"))
                                            .cornerRadius(8)
                                    }
                                    .disabled(isOpening || doorOpen)
                                }
                            }
                        }

                        // Bouton ouverture manuelle
                        Button(action: { Task { await ouvrirPorte() } }) {
                            HStack(spacing: 10) {
                                if isOpening {
                                    ProgressView()
                                        .tint(.white)
                                        .scaleEffect(0.8)
                                }
                                Text(isOpen ? "PORTE OUVERTE" : isOpening ? "OUVERTURE..." : "OUVRIR LA PORTE")
                                    .font(.system(size: 15, weight: .bold, design: .monospaced))
                                    .tracking(2)
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(14)
                            .background(isOpen ? Color(hex: "3fb950") : isOpening ? Color(hex: "484f58") : Color(hex: "1f6feb"))
                            .cornerRadius(12)
                        }
                        .disabled(isOpening || doorOpen)
                        .padding(.horizontal, 30)

                        // Separateur
                        HStack {
                            Rectangle().fill(Color(hex: "30363d")).frame(height: 1)
                            Text("OU")
                                .font(.system(size: 10, weight: .bold, design: .monospaced))
                                .foregroundColor(Color(hex: "484f58"))
                            Rectangle().fill(Color(hex: "30363d")).frame(height: 1)
                        }
                        .padding(.horizontal, 30)

                        // Bouton NFC
                        Button(action: { startNFC() }) {
                            HStack(spacing: 12) {
                                Image(systemName: "wave.3.right")
                                    .font(.system(size: 22))
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("OUVRIR AVEC NFC")
                                        .font(.system(size: 15, weight: .bold, design: .monospaced))
                                        .tracking(1)
                                    Text("Approchez l'iPhone du lecteur")
                                        .font(.system(size: 10, design: .monospaced))
                                        .opacity(0.7)
                                }
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(14)
                            .background(
                                LinearGradient(
                                    colors: [Color(hex: "f0883e"), Color(hex: "d2691e")],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .cornerRadius(12)
                        }
                        .disabled(doorOpen || nfcService.isScanning)
                        .padding(.horizontal, 30)

                        // Status
                        if !currentStatus.isEmpty {
                            HStack(spacing: 6) {
                                if nfcService.isScanning {
                                    ProgressView()
                                        .tint(Color(hex: "58a6ff"))
                                        .scaleEffect(0.7)
                                }
                                Text(currentStatus)
                                    .font(.system(size: 12, design: .monospaced))
                                    .foregroundColor(Color(hex: currentStatusColor))
                            }
                        }

                        // Info NFC
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(spacing: 6) {
                                Image(systemName: "info.circle")
                                    .foregroundColor(Color(hex: "58a6ff"))
                                    .font(.system(size: 12))
                                Text("MODE NFC")
                                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                                    .foregroundColor(Color(hex: "58a6ff"))
                            }
                            Text("Placez un tag NFC (NTAG213) pres du lecteur RFID. Quand vous appuyez sur \"Ouvrir avec NFC\" et approchez votre iPhone, la porte s'ouvre automatiquement.")
                                .font(.system(size: 11))
                                .foregroundColor(Color(hex: "8b949e"))
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(12)
                        .background(Color(hex: "161b22"))
                        .cornerRadius(8)
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color(hex: "30363d")))
                        .padding(.horizontal, 20)

                        Spacer(minLength: 30)
                    }
                }
            }
            .navigationTitle("Ouverture Porte")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                nfcService.onDoorOpen = {
                    isOpen = true
                    countdown = Int(selectedDuree) ?? 5
                    startCountdown()
                }
            }
        }
    }

    var doorOpen: Bool { isOpen || nfcService.doorOpened }

    var currentStatus: String {
        if !nfcService.lastStatus.isEmpty && nfcService.lastStatus != statusMessage {
            return nfcService.lastStatus
        }
        return statusMessage
    }

    var currentStatusColor: String {
        if !nfcService.lastStatus.isEmpty && nfcService.lastStatus != statusMessage {
            return nfcService.lastStatusColor
        }
        return statusColor
    }

    func startNFC() {
        nfcService.startScanning(duree: Int(selectedDuree) ?? 5)
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
                nfcService.lastStatus = ""
            }
        }
    }

    func ouvrirPorte() async {
        isOpening = true
        statusMessage = "Envoi de la commande..."
        statusColor = "58a6ff"
        nfcService.lastStatus = ""

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
