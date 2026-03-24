import Foundation
import Combine

class DataService: ObservableObject {
    @Published var users: [User] = []
    @Published var badges: [Badge] = []
    @Published var logs: [Log] = []
    @Published var doors: [Door] = []
    @Published var stats: DashboardStats = DashboardStats(totalUsers: 24, activeBadges: 28, expiredBadges: 3, accessDenied24h: 7, totalEvents24h: 142)
    
    init() {
        loadMockData()
    }
    
    func loadMockData() {
        self.users = [
            User(id: 1, nom: "FRANCIS", prenom: "Dylan", email: "d.francis@josephgaillard.fr", statut: "etudiant", role: "Étudiant BTS", badge: "A1B2C3D4", actif: true),
            User(id: 2, nom: "RAVION", prenom: "Philippe", email: "p.ravion@josephgaillard.fr", statut: "enseignant", role: "Enseignant", badge: "E5F6A7B8", actif: true)
        ]
        self.badges = [
            Badge(uid: "A1B2C3D4", type: "Mifare_Classic", user: "FRANCIS Dylan", attribution: "2026-01-15", expiration: "2027-01-15", actif: true, perdu: false)
        ]
        self.logs = [
            Log(ts: "2026/03/24 08:30:12", porte: "Porte Salle W13", user: "FRANCIS Dylan", uid: "A1B2C3D4", event: "acces_accorde", methode: "badge_rfid", detail: "Accès autorisé")
        ]
        self.doors = [
            Door(id: 1, nom: "Porte Salle W13", localisation: "Salle W13 - Entrée principale", etat: "verrouille", actif: true),
            Door(id: 2, nom: "Porte Laboratoire", localisation: "Laboratoire - Accès sécurisé", etat: "verrouille", actif: true)
        ]
    }
}
