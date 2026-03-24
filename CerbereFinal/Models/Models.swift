import Foundation

struct User: Identifiable, Codable {
    var id: Int
    var nom: String
    var prenom: String
    var email: String
    var statut: String
    var role: String
    var badge: String
    var actif: Bool
}

struct Badge: Identifiable, Codable {
    var id: String { uid }
    var uid: String
    var type: String
    var user: String
    var attribution: String?
    var expiration: String?
    var actif: Bool
    var perdu: Bool
}

struct Log: Identifiable, Codable {
    var id = UUID()
    var ts: String
    var porte: String
    var user: String?
    var uid: String
    var event: String
    var methode: String
    var detail: String
}

struct Door: Identifiable, Codable {
    var id: Int
    var nom: String
    var localisation: String
    var etat: String
    var actif: Bool
}

struct DashboardStats: Codable {
    var totalUsers: Int
    var activeBadges: Int
    var expiredBadges: Int
    var accessDenied24h: Int
    var totalEvents24h: Int
}
