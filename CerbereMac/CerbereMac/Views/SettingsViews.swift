import SwiftUI

// MARK: - Detections PIR
struct DetectionsView: View {
    @State private var detections: [Detection] = []
    @State private var isLoading = true

    var body: some View {
        Group {
            if isLoading {
                ProgressView().tint(Color(hex: "58a6ff"))
            } else {
                List(detections) { det in
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Image(systemName: det.isAlerte ? "exclamationmark.triangle.fill" : "sensor")
                                .foregroundColor(Color(hex: det.isAlerte ? "f85149" : "3fb950"))
                            Text(det.nom_capteur ?? "Capteur")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(.white)
                            Spacer()
                            if let duree = det.duree_detection_secondes {
                                Text("\(duree) s")
                                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                                    .foregroundColor(Color(hex: "58a6ff"))
                            }
                        }
                        HStack {
                            Text("\(det.jour_detection ?? "") \(det.heure_detection ?? "")")
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundColor(Color(hex: "484f58"))
                            Spacer()
                            if let details = det.details {
                                Text(details)
                                    .font(.system(size: 10, design: .monospaced))
                                    .foregroundColor(Color(hex: "8b949e"))
                            }
                        }
                        if let url = det.capture_url {
                            AsyncImage(url: URL(string: "http://192.168.1.199\(url)")) { phase in
                                switch phase {
                                case .success(let image):
                                    image.resizable().aspectRatio(contentMode: .fill)
                                        .frame(height: 150)
                                        .clipped()
                                        .cornerRadius(6)
                                default:
                                    EmptyView()
                                }
                            }
                        }
                    }
                    .padding(.vertical, 4)
                    .listRowBackground(Color(hex: "0d1117"))
                    .listRowSeparatorTint(Color(hex: "21262d"))
                }
                .listStyle(.plain)
            }
        }
        .background(Color(hex: "0d1117"))
        .task { await loadDetections() }
    }

    func loadDetections() async {
        isLoading = true
        do {
            let resp: APIResponse<[Detection]> = try await APIService.shared.get("detections.php")
            detections = resp.data ?? []
        } catch { print("Error: \(error)") }
        isLoading = false
    }
}

// MARK: - Camera
struct CameraFullView: View {
    var body: some View {
        VStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Circle().fill(Color(hex: "3fb950")).frame(width: 8, height: 8)
                    Text("Camera Entree W13")
                        .font(.system(size: 13, weight: .semibold, design: .monospaced))
                        .foregroundColor(.white)
                    Spacer()
                    Text("LIVE")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color(hex: "f85149"))
                        .cornerRadius(4)
                }
                CameraStreamView()
                    .frame(height: 400)
                    .cornerRadius(8)
                HStack {
                    Text("640x480 - 15fps - MJPEG")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(Color(hex: "484f58"))
                    Spacer()
                    Text("192.168.1.138:8090")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(Color(hex: "484f58"))
                }
            }
            .padding(12)
            .background(Color(hex: "161b22"))
            .cornerRadius(10)
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color(hex: "30363d")))
            .padding(.horizontal)
            Spacer()
        }
        .background(Color(hex: "0d1117"))
    }
}

// MARK: - Raspberry Pi
struct RaspberryPiView: View {
    let pis = [
        ("Controleur RFID / Gache / Ventouse", "192.168.1.49", "kyriann@", "LECTEUR RFID - GACHE - VENTOUSE"),
        ("Capteur de Presence", "192.168.1.89", "cerbere@", "CAPTEUR PIR - DETECTION DE PRESENCE"),
        ("Serveur / Camera", "192.168.1.199", "pi@", "SERVEUR PRINCIPAL - CAMERA - MYSQL - APACHE")
    ]

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                ForEach(pis, id: \.1) { pi in
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Circle().fill(Color(hex: "3fb950")).frame(width: 8, height: 8)
                            Text(pi.0)
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(.white)
                        }
                        Text(pi.1)
                            .font(.system(size: 16, weight: .bold, design: .monospaced))
                            .foregroundColor(Color(hex: "58a6ff"))
                        Text(pi.3)
                            .font(.system(size: 9, weight: .medium, design: .monospaced))
                            .foregroundColor(Color(hex: "8b949e"))
                        HStack {
                            Text("SSH: \(pi.2)")
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundColor(Color(hex: "3fb950"))
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(14)
                    .background(Color(hex: "161b22"))
                    .cornerRadius(10)
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color(hex: "30363d")))
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
        .background(Color(hex: "0d1117"))
    }
}

// MARK: - Autorisations
struct AutorisationsView: View {
    @State private var autorisations: [AutorisationAcces] = []
    @State private var isLoading = true

    var body: some View {
        Group {
            if isLoading {
                ProgressView().tint(Color(hex: "58a6ff"))
            } else {
                List(autorisations) { auth in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("\(auth.nom ?? "") \(auth.prenom ?? "")")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(.white)
                            Spacer()
                            Circle()
                                .fill(auth.isActif ? Color(hex: "3fb950") : Color(hex: "f85149"))
                                .frame(width: 8, height: 8)
                        }
                        Text(auth.nom_porte ?? "")
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundColor(Color(hex: "58a6ff"))
                        HStack(spacing: 12) {
                            Text("\(auth.heure_debut ?? "") - \(auth.heure_fin ?? "")")
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundColor(Color(hex: "8b949e"))
                            Text(auth.jours_semaine ?? "")
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundColor(Color(hex: "484f58"))
                        }
                    }
                    .padding(.vertical, 4)
                    .listRowBackground(Color(hex: "0d1117"))
                    .listRowSeparatorTint(Color(hex: "21262d"))
                }
                .listStyle(.plain)
            }
        }
        .background(Color(hex: "0d1117"))
        .task { await loadData() }
    }

    func loadData() async {
        isLoading = true
        do {
            let resp: APIResponse<[AutorisationAcces]> = try await APIService.shared.get("acces.php")
            autorisations = resp.data ?? []
        } catch { print("Error: \(error)") }
        isLoading = false
    }
}

// MARK: - Configuration
struct ConfigView: View {
    @State private var configs: [ConfigItem] = []
    @State private var isLoading = true

    var body: some View {
        Group {
            if isLoading {
                ProgressView().tint(Color(hex: "58a6ff"))
            } else {
                List(configs) { config in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(config.cle_config ?? "")
                            .font(.system(size: 12, weight: .semibold, design: .monospaced))
                            .foregroundColor(Color(hex: "58a6ff"))
                        Text(config.valeur_config ?? "—")
                            .font(.system(size: 14))
                            .foregroundColor(.white)
                        if let desc = config.description_config {
                            Text(desc)
                                .font(.system(size: 10))
                                .foregroundColor(Color(hex: "484f58"))
                        }
                    }
                    .padding(.vertical, 4)
                    .listRowBackground(Color(hex: "0d1117"))
                    .listRowSeparatorTint(Color(hex: "21262d"))
                }
                .listStyle(.plain)
            }
        }
        .background(Color(hex: "0d1117"))
        .task { await loadConfig() }
    }

    func loadConfig() async {
        isLoading = true
        do {
            let resp: APIResponse<[ConfigItem]> = try await APIService.shared.get("config.php")
            configs = resp.data ?? []
        } catch { print("Error: \(error)") }
        isLoading = false
    }
}

// MARK: - Audit
struct AuditView: View {
    @State private var audits: [AuditLog] = []
    @State private var isLoading = true

    var body: some View {
        Group {
            if isLoading {
                ProgressView().tint(Color(hex: "58a6ff"))
            } else {
                List(audits) { audit in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(audit.type_operation ?? "")
                                .font(.system(size: 10, weight: .bold, design: .monospaced))
                                .foregroundColor(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(operationColor(audit.type_operation))
                                .cornerRadius(3)
                            Text(audit.table_modifiee ?? "")
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundColor(Color(hex: "58a6ff"))
                            Spacer()
                        }
                        if let details = audit.nouvelles_valeurs {
                            Text(details)
                                .font(.system(size: 12))
                                .foregroundColor(Color(hex: "8b949e"))
                        }
                        if let date = audit.date_modification {
                            Text(date)
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundColor(Color(hex: "484f58"))
                        }
                    }
                    .padding(.vertical, 4)
                    .listRowBackground(Color(hex: "0d1117"))
                    .listRowSeparatorTint(Color(hex: "21262d"))
                }
                .listStyle(.plain)
            }
        }
        .background(Color(hex: "0d1117"))
        .task { await loadAudit() }
    }

    func operationColor(_ op: String?) -> Color {
        switch op {
        case "INSERT": return Color(hex: "3fb950").opacity(0.3)
        case "UPDATE": return Color(hex: "f0883e").opacity(0.3)
        case "DELETE": return Color(hex: "f85149").opacity(0.3)
        default: return Color(hex: "30363d")
        }
    }

    func loadAudit() async {
        isLoading = true
        do {
            let resp: APIResponse<[AuditLog]> = try await APIService.shared.get("audit.php")
            audits = resp.data ?? []
        } catch { print("Error: \(error)") }
        isLoading = false
    }
}
