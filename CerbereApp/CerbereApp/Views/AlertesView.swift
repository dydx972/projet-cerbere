import SwiftUI

struct AlertesView: View {
    @State private var alertes: [Alerte] = []
    @State private var isLoading = true

    var body: some View {
        NavigationView {
            Group {
                if isLoading {
                    ProgressView().tint(Color(hex: "58a6ff"))
                } else if alertes.isEmpty {
                    VStack(spacing: 8) {
                        Image(systemName: "checkmark.shield")
                            .font(.system(size: 40))
                            .foregroundColor(Color(hex: "3fb950"))
                        Text("Aucune alerte")
                            .font(.system(size: 13, design: .monospaced))
                            .foregroundColor(Color(hex: "484f58"))
                    }
                } else {
                    List(alertes) { alerte in
                        AlerteRow(alerte: alerte, onAcquitter: { await acquitter(alerte) })
                            .listRowBackground(Color(hex: "0d1117"))
                            .listRowSeparatorTint(Color(hex: "21262d"))
                    }
                    .listStyle(.plain)
                }
            }
            .background(Color(hex: "0d1117"))
            .navigationTitle("Alertes")
            .navigationBarTitleDisplayMode(.inline)
            .refreshable { await loadAlertes() }
            .task { await loadAlertes() }
        }
    }

    func loadAlertes() async {
        isLoading = true
        do {
            let resp: APIResponse<[Alerte]> = try await APIService.shared.get("alertes.php")
            alertes = resp.data ?? []
        } catch {
            print("Error: \(error)")
        }
        isLoading = false
    }

    func acquitter(_ alerte: Alerte) async {
        do {
            _ = try await APIService.shared.put("alertes.php?id=\(alerte.id_alerte)")
            await loadAlertes()
        } catch {
            print("Error: \(error)")
        }
    }
}

struct AlerteRow: View {
    let alerte: Alerte
    let onAcquitter: () async -> Void

    var graviteColor: String {
        switch alerte.niveau_gravite {
        case "critical": return "f85149"
        case "error": return "f85149"
        case "warning": return "f0883e"
        default: return "58a6ff"
        }
    }

    var graviteIcon: String {
        switch alerte.niveau_gravite {
        case "critical", "error": return "exclamationmark.octagon.fill"
        case "warning": return "exclamationmark.triangle.fill"
        default: return "info.circle.fill"
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top) {
                Image(systemName: graviteIcon)
                    .foregroundColor(Color(hex: graviteColor))
                    .font(.system(size: 20))

                VStack(alignment: .leading, spacing: 4) {
                    Text(alerte.message ?? "Alerte")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.white)

                    HStack(spacing: 8) {
                        Text(alerte.type_alerte?.replacingOccurrences(of: "_", with: " ").uppercased() ?? "")
                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                            .foregroundColor(Color(hex: graviteColor))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color(hex: graviteColor).opacity(0.15))
                            .cornerRadius(3)

                        if let porte = alerte.nom_porte {
                            Text(porte)
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundColor(Color(hex: "8b949e"))
                        }
                    }

                    if let ts = alerte.timestamp_alerte {
                        Text(ts)
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundColor(Color(hex: "484f58"))
                    }
                }
                Spacer()
            }

            if !alerte.isAcquittee {
                Button(action: { Task { await onAcquitter() } }) {
                    Text("Acquitter")
                        .font(.system(size: 11, weight: .semibold, design: .monospaced))
                        .foregroundColor(Color(hex: "58a6ff"))
                        .frame(maxWidth: .infinity)
                        .padding(8)
                        .background(Color(hex: "1f6feb").opacity(0.15))
                        .cornerRadius(6)
                        .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color(hex: "1f6feb").opacity(0.4)))
                }
            } else {
                HStack {
                    Image(systemName: "checkmark.circle")
                        .foregroundColor(Color(hex: "3fb950"))
                        .font(.system(size: 12))
                    Text("Acquittee")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(Color(hex: "3fb950"))
                }
            }
        }
        .padding(.vertical, 4)
    }
}
