import SwiftUI

struct UtilisateursView: View {
    @State private var utilisateurs: [Utilisateur] = []
    @State private var isLoading = true
    @State private var showAddSheet = false

    var body: some View {
        NavigationView {
            Group {
                if isLoading {
                    ProgressView().tint(Color(hex: "58a6ff"))
                } else if utilisateurs.isEmpty {
                    VStack(spacing: 8) {
                        Image(systemName: "person.2.slash")
                            .font(.system(size: 40))
                            .foregroundColor(Color(hex: "30363d"))
                        Text("Aucun utilisateur")
                            .font(.system(size: 13, design: .monospaced))
                            .foregroundColor(Color(hex: "484f58"))
                    }
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
            .background(Color(hex: "0d1117"))
            .navigationTitle("Utilisateurs")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showAddSheet = true }) {
                        Image(systemName: "plus.circle.fill")
                            .foregroundColor(Color(hex: "58a6ff"))
                    }
                }
            }
            .sheet(isPresented: $showAddSheet) {
                AddUserView(onSaved: {
                    showAddSheet = false
                    Task { await loadUsers() }
                })
            }
            .refreshable { await loadUsers() }
            .task { await loadUsers() }
        }
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
        .navigationTitle("Profil")
        .navigationBarTitleDisplayMode(.inline)
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
        NavigationView {
            Form {
                Section("Identite") {
                    TextField("Nom", text: $nom)
                    TextField("Prenom", text: $prenom)
                }
                Section("Contact") {
                    TextField("Email", text: $email)
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)
                    TextField("Telephone", text: $telephone)
                        .keyboardType(.phonePad)
                }
                Section("Statut") {
                    Picker("Statut", selection: $statut) {
                        ForEach(statuts, id: \.self) { s in
                            Text(s.capitalized).tag(s)
                        }
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color(hex: "0d1117"))
            .navigationTitle("Nouvel utilisateur")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Annuler") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Enregistrer") {
                        Task { await saveUser() }
                    }
                    .disabled(nom.isEmpty || prenom.isEmpty || isSaving)
                }
            }
        }
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
