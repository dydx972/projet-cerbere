import SwiftUI

struct UtilisateursView: View {
    @State private var utilisateurs: [Utilisateur] = []
    @State private var isLoading = true
    @State private var showAddSheet = false

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Spacer()
                Button(action: { showAddSheet = true }) {
                    Label("Ajouter", systemImage: "plus.circle.fill")
                        .foregroundColor(Color(hex: "58a6ff"))
                }
                .buttonStyle(.plain)
                .padding(.horizontal)
                .padding(.vertical, 8)
            }
            .background(Color(hex: "161b22"))

            Group {
                if isLoading {
                    Spacer()
                    ProgressView().tint(Color(hex: "58a6ff"))
                    Spacer()
                } else if utilisateurs.isEmpty {
                    Spacer()
                    VStack(spacing: 8) {
                        Image(systemName: "person.2.slash")
                            .font(.system(size: 40))
                            .foregroundColor(Color(hex: "30363d"))
                        Text("Aucun utilisateur")
                            .font(.system(size: 13, design: .monospaced))
                            .foregroundColor(Color(hex: "484f58"))
                    }
                    Spacer()
                } else {
                    List(utilisateurs) { user in
                        NavigationLink(destination: UserDetailView(user: user)) {
                            UserRow(user: user)
                        }
                        .listRowBackground(Color(hex: "0d1117"))
                        .listRowSeparatorTint(Color(hex: "21262d"))
                    }
                    .listStyle(.plain)
                }
            }
        }
        .background(Color(hex: "0d1117"))
        .sheet(isPresented: $showAddSheet) {
            AddUserView(onSaved: {
                showAddSheet = false
                Task { await loadUsers() }
            })
            .frame(width: 400, height: 350)
        }
        .task { await loadUsers() }
    }

    func loadUsers() async {
        isLoading = true
        do {
            let resp: APIResponse<[Utilisateur]> = try await APIService.shared.get("utilisateurs.php")
            utilisateurs = resp.data ?? []
        } catch {
            print("Error: \(error)")
        }
        isLoading = false
    }
}

struct UserRow: View {
    let user: Utilisateur

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color(hex: "1f6feb").opacity(0.2))
                    .frame(width: 40, height: 40)
                Text(String((user.prenom ?? "?").prefix(1)) + String((user.nom ?? "?").prefix(1)))
                    .font(.system(size: 14, weight: .bold, design: .monospaced))
                    .foregroundColor(Color(hex: "58a6ff"))
            }

            VStack(alignment: .leading, spacing: 3) {
                Text("\(user.nom ?? "") \(user.prenom ?? "")")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white)
                HStack(spacing: 6) {
                    Text(user.statut ?? "")
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .foregroundColor(Color(hex: "58a6ff"))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color(hex: "1f6feb").opacity(0.15))
                        .cornerRadius(3)
                    if let badge = user.uid_badge {
                        Text(badge)
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundColor(Color(hex: "f0883e"))
                    }
                }
            }
            Spacer()
            Circle()
                .fill(user.isActif ? Color(hex: "3fb950") : Color(hex: "f85149"))
                .frame(width: 8, height: 8)
        }
        .padding(.vertical, 4)
    }
}

struct UserDetailView: View {
    let user: Utilisateur

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(Color(hex: "1f6feb").opacity(0.2))
                        .frame(width: 80, height: 80)
                    Text(String((user.prenom ?? "?").prefix(1)) + String((user.nom ?? "?").prefix(1)))
                        .font(.system(size: 28, weight: .bold, design: .monospaced))
                        .foregroundColor(Color(hex: "58a6ff"))
                }
                .padding(.top)

                Text("\(user.nom ?? "") \(user.prenom ?? "")")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.white)

                VStack(spacing: 0) {
                    DetailRow(label: "Email", value: user.email ?? "—")
                    DetailRow(label: "Telephone", value: user.telephone ?? "—")
                    DetailRow(label: "Statut", value: user.statut ?? "—")
                    DetailRow(label: "Role", value: user.nom_role ?? "—")
                    DetailRow(label: "Etablissement", value: user.etablissement ?? "—")
                    DetailRow(label: "Badge RFID", value: user.uid_badge ?? "Aucun")
                    DetailRow(label: "Actif", value: user.isActif ? "Oui" : "Non")
                }
                .background(Color(hex: "161b22"))
                .cornerRadius(10)
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color(hex: "30363d")))
                .padding(.horizontal)
            }
        }
        .background(Color(hex: "0d1117"))
    }
}

struct DetailRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label.uppercased())
                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                .foregroundColor(Color(hex: "8b949e"))
                .frame(width: 110, alignment: .leading)
            Spacer()
            Text(value)
                .font(.system(size: 13, design: .monospaced))
                .foregroundColor(.white)
                .multilineTextAlignment(.trailing)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .overlay(Divider().background(Color(hex: "21262d")), alignment: .bottom)
    }
}

struct AddUserView: View {
    var onSaved: () -> Void
    @Environment(\.dismiss) var dismiss

    @State private var nom = ""
    @State private var prenom = ""
    @State private var email = ""
    @State private var telephone = ""
    @State private var statut = "etudiant"
    @State private var isSaving = false

    let statuts = ["etudiant", "enseignant", "professionnel", "visiteur"]

    var body: some View {
        VStack(spacing: 16) {
            Text("Nouvel utilisateur")
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(.white)

            VStack(spacing: 12) {
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("NOM").font(.system(size: 9, weight: .bold, design: .monospaced)).foregroundColor(Color(hex: "8b949e"))
                        TextField("Nom", text: $nom)
                            .textFieldStyle(.plain)
                            .padding(8)
                            .background(Color(hex: "161b22"))
                            .cornerRadius(6)
                            .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color(hex: "30363d")))
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        Text("PRENOM").font(.system(size: 9, weight: .bold, design: .monospaced)).foregroundColor(Color(hex: "8b949e"))
                        TextField("Prenom", text: $prenom)
                            .textFieldStyle(.plain)
                            .padding(8)
                            .background(Color(hex: "161b22"))
                            .cornerRadius(6)
                            .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color(hex: "30363d")))
                    }
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("EMAIL").font(.system(size: 9, weight: .bold, design: .monospaced)).foregroundColor(Color(hex: "8b949e"))
                    TextField("Email", text: $email)
                        .textFieldStyle(.plain)
                        .padding(8)
                        .background(Color(hex: "161b22"))
                        .cornerRadius(6)
                        .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color(hex: "30363d")))
                }

                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("TELEPHONE").font(.system(size: 9, weight: .bold, design: .monospaced)).foregroundColor(Color(hex: "8b949e"))
                        TextField("Telephone", text: $telephone)
                            .textFieldStyle(.plain)
                            .padding(8)
                            .background(Color(hex: "161b22"))
                            .cornerRadius(6)
                            .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color(hex: "30363d")))
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        Text("STATUT").font(.system(size: 9, weight: .bold, design: .monospaced)).foregroundColor(Color(hex: "8b949e"))
                        Picker("", selection: $statut) {
                            ForEach(statuts, id: \.self) { s in
                                Text(s.capitalized).tag(s)
                            }
                        }
                    }
                }
            }

            HStack {
                Button("Annuler") { dismiss() }
                    .buttonStyle(.plain)
                    .foregroundColor(Color(hex: "8b949e"))
                Spacer()
                Button(action: { Task { await saveUser() } }) {
                    Text("Enregistrer")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 8)
                        .background(Color(hex: "1f6feb"))
                        .cornerRadius(6)
                }
                .buttonStyle(.plain)
                .disabled(nom.isEmpty || prenom.isEmpty || isSaving)
            }
        }
        .padding(20)
        .background(Color(hex: "0d1117"))
    }

    func saveUser() async {
        isSaving = true
        do {
            _ = try await APIService.shared.post("utilisateurs.php", body: [
                "nom": nom,
                "prenom": prenom,
                "email": email,
                "telephone": telephone,
                "statut": statut,
                "id_role": 1,
                "etablissement": "Lycee Joseph Gaillard"
            ])
            onSaved()
        } catch {
            print("Error: \(error)")
        }
        isSaving = false
    }
}
