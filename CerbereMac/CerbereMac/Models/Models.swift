import Foundation

struct Utilisateur: Codable, Identifiable {
    var id: String { id_utilisateur }
    let id_utilisateur: String
    let nom: String?
    let prenom: String?
    let email: String?
    let telephone: String?
    let statut: String?
    let etablissement: String?
    let actif: String?
    let nom_role: String?
    let uid_badge: String?

    var isActif: Bool { actif == "1" }
}

struct LogAcces: Codable, Identifiable {
    var id: String { id_log }
    let id_log: String
    let id_porte: String?
    let id_utilisateur: String?
    let uid_badge: String?
    let type_evenement: String?
    let methode_acces: String?
    let details_supplementaires: String?
    let timestamp_evenement: String?
    let nom_porte: String?
    let nom: String?
    let prenom: String?
}

struct Alerte: Codable, Identifiable {
    var id: String { id_alerte }
    let id_alerte: String
    let type_alerte: String?
    let niveau_gravite: String?
    let id_porte: String?
    let id_capteur: String?
    let message: String?
    let acquittee: String?
    let timestamp_alerte: String?
    let timestamp_acquittement: String?
    let nom_porte: String?

    var isAcquittee: Bool { acquittee == "1" }
}

struct AutorisationAcces: Codable, Identifiable {
    var id: String { id_autorisation }
    let id_autorisation: String
    let id_utilisateur: String?
    let id_porte: String?
    let heure_debut: String?
    let heure_fin: String?
    let jours_semaine: String?
    let date_debut_validite: String?
    let date_fin_validite: String?
    let actif: String?
    let nom: String?
    let prenom: String?
    let nom_porte: String?

    var isActif: Bool { actif == "1" }
}

struct Detection: Codable, Identifiable {
    var id: String { id_detection }
    let id_detection: String
    let id_capteur: String?
    let jour_detection: String?
    let heure_detection: String?
    let duree_detection_secondes: String?
    let alerte_generee: String?
    let details: String?
    let nom_capteur: String?
    let capture_url: String?
    let capture_taille_ko: String?

    var isAlerte: Bool { alerte_generee == "1" }
}

struct ConfigItem: Codable, Identifiable {
    var id: String { id_config }
    let id_config: String
    let cle_config: String?
    let valeur_config: String?
    let description_config: String?
    let type_valeur: String?
    let modifiable: String?
}

struct AuditLog: Codable, Identifiable {
    var id: String { id_modification }
    let id_modification: String
    let table_modifiee: String?
    let id_enregistrement: String?
    let type_operation: String?
    let nouvelles_valeurs: String?
    let date_modification: String?
}
