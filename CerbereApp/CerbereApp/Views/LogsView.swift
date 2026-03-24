import SwiftUI

struct LogsView: View {
    @State private var logs: [LogAcces] = []
    @State private var isLoading = true
    @State private var filter = "all"

    let filters = ["all", "acces_accorde", "acces_refuse", "badge_inconnu", "hors_horaire"]
    let filterLabels = ["Tous", "Accordes", "Refuses", "Inconnus", "Hors horaire"]

    var filteredLogs: [LogAcces] {
        if filter == "all" { return logs }
        return logs.filter { $0.type_evenement == filter }
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Filter bar
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(Array(zip(filters, filterLabels)), id: \.0) { key, label in
                            Button(action: { filter = key }) {
                                Text(label)
                                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                                    .foregroundColor(filter == key ? .white : Color(hex: "8b949e"))
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(filter == key ? Color(hex: "1f6feb") : Color(hex: "21262d"))
                                    .cornerRadius(4)
                            }
                        }
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                }
                .background(Color(hex: "161b22"))

                if isLoading {
                    Spacer()
                    ProgressView().tint(Color(hex: "58a6ff"))
                    Spacer()
                } else if filteredLogs.isEmpty {
                    Spacer()
                    VStack(spacing: 8) {
                        Image(systemName: "doc.text.magnifyingglass")
                            .font(.system(size: 40))
                            .foregroundColor(Color(hex: "30363d"))
                        Text("Aucun evenement")
                            .font(.system(size: 13, design: .monospaced))
                            .foregroundColor(Color(hex: "484f58"))
                    }
                    Spacer()
                } else {
                    List(filteredLogs) { log in
                        LogRow(log: log)
                            .listRowBackground(Color(hex: "0d1117"))
                            .listRowSeparatorTint(Color(hex: "21262d"))
                    }
                    .listStyle(.plain)
                }
            }
            .background(Color(hex: "0d1117"))
            .navigationTitle("Journaux d'acces")
            .navigationBarTitleDisplayMode(.inline)
            .refreshable { await loadLogs() }
            .task { await loadLogs() }
        }
    }

    func loadLogs() async {
        isLoading = true
        do {
            let resp: APIResponse<[LogAcces]> = try await APIService.shared.get("logs.php")
            logs = resp.data ?? []
        } catch {
            print("Error: \(error)")
        }
        isLoading = false
    }
}

struct LogRow: View {
    let log: LogAcces

    var eventColor: String {
        switch log.type_evenement {
        case "acces_accorde": return "3fb950"
        case "acces_refuse", "badge_inconnu": return "f85149"
        case "hors_horaire", "badge_expire": return "f0883e"
        default: return "8b949e"
        }
    }

    var eventIcon: String {
        switch log.type_evenement {
        case "acces_accorde": return "checkmark.circle.fill"
        case "acces_refuse", "badge_inconnu": return "xmark.circle.fill"
        case "hors_horaire": return "clock.badge.exclamationmark"
        default: return "questionmark.circle"
        }
    }

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: eventIcon)
                .foregroundColor(Color(hex: eventColor))
                .font(.system(size: 18))

            VStack(alignment: .leading, spacing: 3) {
                HStack {
                    if let nom = log.nom, let prenom = log.prenom {
                        Text("\(nom) \(prenom)")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.white)
                    } else {
                        Text("Inconnu")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(Color(hex: "484f58"))
                    }
                    Spacer()
                    Text(log.type_evenement?.replacingOccurrences(of: "_", with: " ").uppercased() ?? "")
                        .font(.system(size: 8, weight: .bold, design: .monospaced))
                        .foregroundColor(Color(hex: eventColor))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color(hex: eventColor).opacity(0.15))
                        .cornerRadius(3)
                }
                HStack {
                    Text(log.nom_porte ?? "")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(Color(hex: "8b949e"))
                    Spacer()
                    if let uid = log.uid_badge {
                        Text(uid)
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundColor(Color(hex: "58a6ff"))
                    }
                }
                if let ts = log.timestamp_evenement {
                    Text(ts)
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(Color(hex: "484f58"))
                }
            }
        }
        .padding(.vertical, 4)
    }
}
