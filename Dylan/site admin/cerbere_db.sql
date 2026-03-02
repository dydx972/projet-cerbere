-- ============================================================================
-- Base de données CERBÈRE - Système de Contrôle d'Accès Intelligent
-- Projet BTS CIEL IR - Session 2026
-- Lycée Joseph Gaillard - Fort-de-France, Martinique
-- ============================================================================
-- Étudiant responsable : Dylan FRANCIS (Étudiant 2)
-- Date de création : Janvier 2026
-- Version : 1.0
-- ============================================================================

-- Suppression de la base si elle existe déjà
DROP DATABASE IF EXISTS cerbere_db;

-- Création de la base de données
CREATE DATABASE cerbere_db 
CHARACTER SET utf8mb4 
COLLATE utf8mb4_unicode_ci;

USE cerbere_db;

-- ============================================================================
-- TABLE : roles
-- Description : Définit les différents rôles d'utilisateurs du système
-- ============================================================================
CREATE TABLE roles (
    id_role INT AUTO_INCREMENT PRIMARY KEY,
    nom_role VARCHAR(50) NOT NULL UNIQUE,
    description_role TEXT,
    date_creation TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_nom_role (nom_role)
) ENGINE=InnoDB;

-- ============================================================================
-- TABLE : utilisateurs
-- Description : Stocke les informations des personnes autorisées à accéder
-- ============================================================================
CREATE TABLE utilisateurs (
    id_utilisateur INT AUTO_INCREMENT PRIMARY KEY,
    nom VARCHAR(100) NOT NULL,
    prenom VARCHAR(100) NOT NULL,
    email VARCHAR(150) UNIQUE,
    telephone VARCHAR(20),
    etablissement VARCHAR(150) DEFAULT 'Lycée Joseph Gaillard',
    statut ENUM('etudiant', 'enseignant', 'professionnel', 'visiteur') NOT NULL,
    id_role INT NOT NULL,
    photo_path VARCHAR(255),
    actif BOOLEAN DEFAULT TRUE,
    date_creation TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    date_modification TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (id_role) REFERENCES roles(id_role) ON DELETE RESTRICT,
    INDEX idx_nom_prenom (nom, prenom),
    INDEX idx_email (email),
    INDEX idx_statut (statut),
    INDEX idx_actif (actif)
) ENGINE=InnoDB;

-- ============================================================================
-- TABLE : badges_rfid
-- Description : Gère les badges RFID et leur association aux utilisateurs
-- ============================================================================
CREATE TABLE badges_rfid (
    id_badge INT AUTO_INCREMENT PRIMARY KEY,
    uid_badge VARCHAR(50) NOT NULL UNIQUE COMMENT 'Identifiant unique du badge RFID',
    id_utilisateur INT,
    type_badge ENUM('Mifare_Classic', 'Mifare_Ultralight', 'Autre') DEFAULT 'Mifare_Classic',
    cle_cryptage VARCHAR(100) COMMENT 'Clé de cryptage Mifare si applicable',
    date_attribution DATE,
    date_expiration DATE,
    actif BOOLEAN DEFAULT TRUE,
    perdu BOOLEAN DEFAULT FALSE,
    date_creation TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    date_modification TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (id_utilisateur) REFERENCES utilisateurs(id_utilisateur) ON DELETE SET NULL,
    INDEX idx_uid_badge (uid_badge),
    INDEX idx_utilisateur (id_utilisateur),
    INDEX idx_actif (actif)
) ENGINE=InnoDB;

-- ============================================================================
-- TABLE : portes
-- Description : Définit les différentes portes du système
-- ============================================================================
CREATE TABLE portes (
    id_porte INT AUTO_INCREMENT PRIMARY KEY,
    nom_porte VARCHAR(100) NOT NULL,
    localisation VARCHAR(150) NOT NULL,
    type_serrure ENUM('gache_electrique', 'ventouse_magnetique') NOT NULL,
    raspberry_pi_id VARCHAR(50) COMMENT 'Identifiant du Raspberry Pi associé',
    adresse_ip VARCHAR(15),
    etat_actuel ENUM('verrouille', 'deverrouille', 'maintenance', 'erreur') DEFAULT 'verrouille',
    actif BOOLEAN DEFAULT TRUE,
    date_creation TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    date_modification TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    INDEX idx_nom_porte (nom_porte),
    INDEX idx_raspberry (raspberry_pi_id)
) ENGINE=InnoDB;

-- ============================================================================
-- TABLE : autorisations_acces
-- Description : Définit les autorisations d'accès par porte et utilisateur
-- ============================================================================
CREATE TABLE autorisations_acces (
    id_autorisation INT AUTO_INCREMENT PRIMARY KEY,
    id_utilisateur INT NOT NULL,
    id_porte INT NOT NULL,
    heure_debut TIME DEFAULT '08:00:00',
    heure_fin TIME DEFAULT '18:00:00',
    jours_semaine SET('lundi', 'mardi', 'mercredi', 'jeudi', 'vendredi', 'samedi', 'dimanche') 
        DEFAULT 'lundi,mardi,mercredi,jeudi,vendredi',
    date_debut_validite DATE NOT NULL,
    date_fin_validite DATE,
    actif BOOLEAN DEFAULT TRUE,
    date_creation TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    date_modification TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (id_utilisateur) REFERENCES utilisateurs(id_utilisateur) ON DELETE CASCADE,
    FOREIGN KEY (id_porte) REFERENCES portes(id_porte) ON DELETE CASCADE,
    UNIQUE KEY unique_user_door (id_utilisateur, id_porte),
    INDEX idx_utilisateur_porte (id_utilisateur, id_porte),
    INDEX idx_actif (actif)
) ENGINE=InnoDB;

-- ============================================================================
-- TABLE : logs_acces
-- Description : Enregistre tous les événements d'accès (réussis ou refusés)
-- ============================================================================
CREATE TABLE logs_acces (
    id_log INT AUTO_INCREMENT PRIMARY KEY,
    id_porte INT NOT NULL,
    id_utilisateur INT,
    uid_badge VARCHAR(50),
    type_evenement ENUM('acces_accorde', 'acces_refuse', 'badge_inconnu', 'badge_expire', 
                        'hors_horaire', 'erreur_systeme') NOT NULL,
    methode_acces ENUM('badge_rfid', 'application_mobile', 'manuel') DEFAULT 'badge_rfid',
    timestamp_evenement TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    adresse_ip_source VARCHAR(15),
    details_supplementaires TEXT,
    FOREIGN KEY (id_porte) REFERENCES portes(id_porte) ON DELETE CASCADE,
    FOREIGN KEY (id_utilisateur) REFERENCES utilisateurs(id_utilisateur) ON DELETE SET NULL,
    INDEX idx_porte (id_porte),
    INDEX idx_utilisateur (id_utilisateur),
    INDEX idx_timestamp (timestamp_evenement),
    INDEX idx_type_evenement (type_evenement),
    INDEX idx_uid_badge (uid_badge)
) ENGINE=InnoDB;

-- ============================================================================
-- TABLE : capteurs_presence
-- Description : Gère les capteurs PIR de détection de présence
-- ============================================================================
CREATE TABLE capteurs_presence (
    id_capteur INT AUTO_INCREMENT PRIMARY KEY,
    nom_capteur VARCHAR(100) NOT NULL,
    type_capteur ENUM('PIR_HC-SR501', 'Ultrason_HC-SR04', 'Radar_RCWL-0516', 'Autre') 
        DEFAULT 'PIR_HC-SR501',
    id_porte INT NOT NULL,
    gpio_pin INT COMMENT 'Numéro de la broche GPIO du Raspberry Pi',
    portee_metres DECIMAL(4,2) DEFAULT 5.00,
    angle_detection INT DEFAULT 120 COMMENT 'Angle de détection en degrés',
    sensibilite INT DEFAULT 50 COMMENT 'Niveau de sensibilité (0-100)',
    temps_maintien_secondes INT DEFAULT 10,
    etat_actuel ENUM('actif', 'inactif', 'maintenance', 'erreur') DEFAULT 'actif',
    derniere_detection TIMESTAMP NULL,
    actif BOOLEAN DEFAULT TRUE,
    date_creation TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    date_modification TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (id_porte) REFERENCES portes(id_porte) ON DELETE CASCADE,
    INDEX idx_porte (id_porte),
    INDEX idx_type_capteur (type_capteur)
) ENGINE=InnoDB;

-- ============================================================================
-- TABLE : logs_detections
-- Description : Enregistre les détections de présence par les capteurs
-- ============================================================================
CREATE TABLE logs_detections (
    id_detection INT AUTO_INCREMENT PRIMARY KEY,
    id_capteur INT NOT NULL,
    timestamp_detection TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    duree_detection_secondes INT,
    alerte_generee BOOLEAN DEFAULT FALSE,
    details TEXT,
    FOREIGN KEY (id_capteur) REFERENCES capteurs_presence(id_capteur) ON DELETE CASCADE,
    INDEX idx_capteur (id_capteur),
    INDEX idx_timestamp (timestamp_detection)
) ENGINE=InnoDB;

-- ============================================================================
-- TABLE : cameras
-- Description : Gère les caméras Raspberry Pi du système
-- ============================================================================
CREATE TABLE cameras (
    id_camera INT AUTO_INCREMENT PRIMARY KEY,
    nom_camera VARCHAR(100) NOT NULL,
    id_porte INT NOT NULL,
    type_camera VARCHAR(50) DEFAULT 'Raspberry Pi Camera Module',
    resolution VARCHAR(20) DEFAULT '1080p',
    adresse_stream VARCHAR(255),
    actif BOOLEAN DEFAULT TRUE,
    enregistrement_actif BOOLEAN DEFAULT FALSE,
    date_creation TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    date_modification TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (id_porte) REFERENCES portes(id_porte) ON DELETE CASCADE,
    INDEX idx_porte (id_porte)
) ENGINE=InnoDB;

-- ============================================================================
-- TABLE : photos_horodatees
-- Description : Stocke les photos capturées lors des événements
-- ============================================================================
CREATE TABLE photos_horodatees (
    id_photo INT AUTO_INCREMENT PRIMARY KEY,
    id_camera INT NOT NULL,
    id_log_acces INT,
    chemin_fichier VARCHAR(255) NOT NULL,
    timestamp_photo TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    taille_fichier_ko INT,
    type_evenement ENUM('acces_normal', 'acces_refuse', 'alerte', 'manuel') DEFAULT 'acces_normal',
    FOREIGN KEY (id_camera) REFERENCES cameras(id_camera) ON DELETE CASCADE,
    FOREIGN KEY (id_log_acces) REFERENCES logs_acces(id_log) ON DELETE SET NULL,
    INDEX idx_camera (id_camera),
    INDEX idx_timestamp (timestamp_photo),
    INDEX idx_log_acces (id_log_acces)
) ENGINE=InnoDB;

-- ============================================================================
-- TABLE : alertes
-- Description : Gère les alertes et notifications du système
-- ============================================================================
CREATE TABLE alertes (
    id_alerte INT AUTO_INCREMENT PRIMARY KEY,
    type_alerte ENUM('intrusion', 'badge_inconnu', 'erreur_materiel', 'tentative_forcage', 
                     'presence_suspecte', 'maintenance', 'autre') NOT NULL,
    niveau_gravite ENUM('info', 'warning', 'error', 'critical') DEFAULT 'warning',
    id_porte INT,
    id_capteur INT,
    id_log_acces INT,
    message TEXT NOT NULL,
    timestamp_alerte TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    acquittee BOOLEAN DEFAULT FALSE,
    acquittee_par INT,
    timestamp_acquittement TIMESTAMP NULL,
    notification_envoyee BOOLEAN DEFAULT FALSE,
    FOREIGN KEY (id_porte) REFERENCES portes(id_porte) ON DELETE SET NULL,
    FOREIGN KEY (id_capteur) REFERENCES capteurs_presence(id_capteur) ON DELETE SET NULL,
    FOREIGN KEY (id_log_acces) REFERENCES logs_acces(id_log) ON DELETE SET NULL,
    FOREIGN KEY (acquittee_par) REFERENCES utilisateurs(id_utilisateur) ON DELETE SET NULL,
    INDEX idx_type_alerte (type_alerte),
    INDEX idx_timestamp (timestamp_alerte),
    INDEX idx_acquittee (acquittee),
    INDEX idx_niveau_gravite (niveau_gravite)
) ENGINE=InnoDB;

-- ============================================================================
-- TABLE : administrateurs
-- Description : Comptes administrateurs pour l'interface web
-- ============================================================================
CREATE TABLE administrateurs (
    id_admin INT AUTO_INCREMENT PRIMARY KEY,
    username VARCHAR(50) NOT NULL UNIQUE,
    password_hash VARCHAR(255) NOT NULL COMMENT 'Hash bcrypt du mot de passe',
    id_utilisateur INT,
    niveau_acces ENUM('super_admin', 'admin', 'operateur') DEFAULT 'operateur',
    derniere_connexion TIMESTAMP NULL,
    actif BOOLEAN DEFAULT TRUE,
    date_creation TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    date_modification TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (id_utilisateur) REFERENCES utilisateurs(id_utilisateur) ON DELETE CASCADE,
    INDEX idx_username (username)
) ENGINE=InnoDB;

-- ============================================================================
-- TABLE : sessions_admin
-- Description : Gère les sessions de connexion des administrateurs
-- ============================================================================
CREATE TABLE sessions_admin (
    id_session INT AUTO_INCREMENT PRIMARY KEY,
    id_admin INT NOT NULL,
    token_session VARCHAR(255) NOT NULL UNIQUE,
    adresse_ip VARCHAR(15),
    user_agent VARCHAR(255),
    timestamp_debut TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    timestamp_expiration TIMESTAMP NOT NULL,
    active BOOLEAN DEFAULT TRUE,
    FOREIGN KEY (id_admin) REFERENCES administrateurs(id_admin) ON DELETE CASCADE,
    INDEX idx_token (token_session),
    INDEX idx_admin (id_admin),
    INDEX idx_expiration (timestamp_expiration)
) ENGINE=InnoDB;

-- ============================================================================
-- TABLE : logs_modifications
-- Description : Audit trail de toutes les modifications dans le système
-- ============================================================================
CREATE TABLE logs_modifications (
    id_log_modif INT AUTO_INCREMENT PRIMARY KEY,
    id_admin INT,
    table_modifiee VARCHAR(50) NOT NULL,
    id_enregistrement INT NOT NULL,
    type_operation ENUM('INSERT', 'UPDATE', 'DELETE') NOT NULL,
    anciennes_valeurs JSON,
    nouvelles_valeurs JSON,
    timestamp_modification TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    adresse_ip VARCHAR(15),
    FOREIGN KEY (id_admin) REFERENCES administrateurs(id_admin) ON DELETE SET NULL,
    INDEX idx_admin (id_admin),
    INDEX idx_table (table_modifiee),
    INDEX idx_timestamp (timestamp_modification)
) ENGINE=InnoDB;

-- ============================================================================
-- TABLE : configurations_systeme
-- Description : Paramètres de configuration du système CERBÈRE
-- ============================================================================
CREATE TABLE configurations_systeme (
    id_config INT AUTO_INCREMENT PRIMARY KEY,
    cle_config VARCHAR(100) NOT NULL UNIQUE,
    valeur_config TEXT,
    type_donnee ENUM('string', 'integer', 'boolean', 'json') DEFAULT 'string',
    description_config TEXT,
    modifiable BOOLEAN DEFAULT TRUE,
    date_modification TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    INDEX idx_cle (cle_config)
) ENGINE=InnoDB;

-- ============================================================================
-- DONNÉES D'INITIALISATION
-- ============================================================================

-- Insertion des rôles par défaut
INSERT INTO roles (nom_role, description_role) VALUES
('Étudiant BTS', 'Étudiant en formation BTS CIEL'),
('Enseignant', 'Professeur du lycée'),
('Personnel Administratif', 'Personnel administratif du lycée'),
('Professionnel Externe', 'Professionnel partenaire du lycée'),
('Visiteur Temporaire', 'Visiteur ponctuel avec accès limité'),
('Administrateur Système', 'Administrateur du système CERBÈRE');

-- Insertion des portes du système
INSERT INTO portes (nom_porte, localisation, type_serrure, raspberry_pi_id, etat_actuel) VALUES
('Porte Salle W13', 'Salle W13 - Entrée principale', 'gache_electrique', 'RPI_W13_001', 'verrouille'),
('Porte Laboratoire', 'Laboratoire - Accès sécurisé', 'ventouse_magnetique', 'RPI_LAB_001', 'verrouille');

-- Insertion des capteurs de présence
INSERT INTO capteurs_presence (nom_capteur, type_capteur, id_porte, gpio_pin, portee_metres, angle_detection) VALUES
('PIR Salle W13', 'PIR_HC-SR501', 1, 17, 5.00, 120),
('PIR Laboratoire', 'PIR_HC-SR501', 2, 18, 5.00, 120);

-- Insertion des caméras
INSERT INTO cameras (nom_camera, id_porte, resolution, actif) VALUES
('Caméra Entrée W13', 1, '1080p', TRUE),
('Caméra Laboratoire', 2, '1080p', TRUE);

-- Insertion des configurations système par défaut
INSERT INTO configurations_systeme (cle_config, valeur_config, type_donnee, description_config) VALUES
('nom_systeme', 'CERBÈRE', 'string', 'Nom du système de contrôle d''accès'),
('version', '1.0', 'string', 'Version du système'),
('etablissement', 'Lycée Joseph Gaillard', 'string', 'Nom de l''établissement'),
('duree_session_admin', '3600', 'integer', 'Durée de session administrateur en secondes'),
('tentatives_max_connexion', '5', 'integer', 'Nombre maximum de tentatives de connexion'),
('delai_blocage_badge', '300', 'integer', 'Durée de blocage après tentatives échouées (secondes)'),
('temps_ouverture_porte', '5', 'integer', 'Temps d''ouverture de la porte en secondes'),
('conservation_logs_jours', '90', 'integer', 'Durée de conservation des logs en jours'),
('alerte_email_actif', 'true', 'boolean', 'Activation des alertes par email'),
('alerte_email_destinataire', 'admin@josephgaillard.fr', 'string', 'Email destinataire des alertes'),
('mode_maintenance', 'false', 'boolean', 'Mode maintenance du système');

-- ============================================================================
-- CRÉATION DES VUES POUR FACILITER LES REQUÊTES
-- ============================================================================

-- Vue : Accès récents avec informations complètes
CREATE VIEW vue_acces_recents AS
SELECT 
    l.id_log,
    l.timestamp_evenement,
    l.type_evenement,
    l.methode_acces,
    p.nom_porte,
    p.localisation,
    CONCAT(u.prenom, ' ', u.nom) AS nom_complet_utilisateur,
    u.statut AS statut_utilisateur,
    b.uid_badge,
    l.details_supplementaires
FROM logs_acces l
JOIN portes p ON l.id_porte = p.id_porte
LEFT JOIN utilisateurs u ON l.id_utilisateur = u.id_utilisateur
LEFT JOIN badges_rfid b ON l.uid_badge = b.uid_badge
ORDER BY l.timestamp_evenement DESC;

-- Vue : Alertes non traitées
CREATE VIEW vue_alertes_actives AS
SELECT 
    a.id_alerte,
    a.type_alerte,
    a.niveau_gravite,
    a.message,
    a.timestamp_alerte,
    p.nom_porte,
    c.nom_capteur
FROM alertes a
LEFT JOIN portes p ON a.id_porte = p.id_porte
LEFT JOIN capteurs_presence c ON a.id_capteur = c.id_capteur
WHERE a.acquittee = FALSE
ORDER BY 
    FIELD(a.niveau_gravite, 'critical', 'error', 'warning', 'info'),
    a.timestamp_alerte DESC;

-- Vue : Statistiques d'accès par utilisateur
CREATE VIEW vue_stats_utilisateurs AS
SELECT 
    u.id_utilisateur,
    CONCAT(u.prenom, ' ', u.nom) AS nom_complet,
    u.statut,
    u.etablissement,
    COUNT(DISTINCT l.id_log) AS nombre_acces_total,
    SUM(CASE WHEN l.type_evenement = 'acces_accorde' THEN 1 ELSE 0 END) AS acces_accordes,
    SUM(CASE WHEN l.type_evenement = 'acces_refuse' THEN 1 ELSE 0 END) AS acces_refuses,
    MAX(l.timestamp_evenement) AS dernier_acces
FROM utilisateurs u
LEFT JOIN logs_acces l ON u.id_utilisateur = l.id_utilisateur
GROUP BY u.id_utilisateur, u.prenom, u.nom, u.statut, u.etablissement;

-- Vue : État actuel du système
CREATE VIEW vue_etat_systeme AS
SELECT 
    'Portes' AS composant,
    COUNT(*) AS total,
    SUM(CASE WHEN actif = TRUE THEN 1 ELSE 0 END) AS actifs,
    SUM(CASE WHEN etat_actuel = 'erreur' THEN 1 ELSE 0 END) AS en_erreur
FROM portes
UNION ALL
SELECT 
    'Capteurs' AS composant,
    COUNT(*) AS total,
    SUM(CASE WHEN actif = TRUE THEN 1 ELSE 0 END) AS actifs,
    SUM(CASE WHEN etat_actuel = 'erreur' THEN 1 ELSE 0 END) AS en_erreur
FROM capteurs_presence
UNION ALL
SELECT 
    'Caméras' AS composant,
    COUNT(*) AS total,
    SUM(CASE WHEN actif = TRUE THEN 1 ELSE 0 END) AS actifs,
    0 AS en_erreur
FROM cameras
UNION ALL
SELECT 
    'Utilisateurs' AS composant,
    COUNT(*) AS total,
    SUM(CASE WHEN actif = TRUE THEN 1 ELSE 0 END) AS actifs,
    0 AS en_erreur
FROM utilisateurs;

-- ============================================================================
-- PROCÉDURES STOCKÉES
-- ============================================================================

DELIMITER $$

-- Procédure : Vérifier l'autorisation d'accès
CREATE PROCEDURE sp_verifier_acces(
    IN p_uid_badge VARCHAR(50),
    IN p_id_porte INT,
    OUT p_autorisation BOOLEAN,
    OUT p_id_utilisateur INT,
    OUT p_message VARCHAR(255)
)
BEGIN
    DECLARE v_badge_actif BOOLEAN;
    DECLARE v_badge_perdu BOOLEAN;
    DECLARE v_date_expiration DATE;
    DECLARE v_autorisation_active BOOLEAN;
    DECLARE v_jour_actuel VARCHAR(20);
    DECLARE v_heure_actuelle TIME;
    DECLARE v_heure_debut TIME;
    DECLARE v_heure_fin TIME;
    DECLARE v_jours_autorises VARCHAR(100);
    
    -- Initialisation
    SET p_autorisation = FALSE;
    SET p_id_utilisateur = NULL;
    SET p_message = 'Accès refusé';
    
    -- Récupération du jour actuel en français
    SET v_jour_actuel = LOWER(DATE_FORMAT(NOW(), '%W'));
    SET v_jour_actuel = CASE v_jour_actuel
        WHEN 'monday' THEN 'lundi'
        WHEN 'tuesday' THEN 'mardi'
        WHEN 'wednesday' THEN 'mercredi'
        WHEN 'thursday' THEN 'jeudi'
        WHEN 'friday' THEN 'vendredi'
        WHEN 'saturday' THEN 'samedi'
        WHEN 'sunday' THEN 'dimanche'
    END;
    SET v_heure_actuelle = CURTIME();
    
    -- Vérification du badge
    SELECT 
        b.actif,
        b.perdu,
        b.date_expiration,
        b.id_utilisateur
    INTO 
        v_badge_actif,
        v_badge_perdu,
        v_date_expiration,
        p_id_utilisateur
    FROM badges_rfid b
    WHERE b.uid_badge = p_uid_badge;
    
    -- Badge inexistant
    IF p_id_utilisateur IS NULL THEN
        SET p_message = 'Badge inconnu';
        LEAVE sp_verifier_acces;
    END IF;
    
    -- Badge perdu
    IF v_badge_perdu = TRUE THEN
        SET p_message = 'Badge déclaré perdu';
        LEAVE sp_verifier_acces;
    END IF;
    
    -- Badge inactif
    IF v_badge_actif = FALSE THEN
        SET p_message = 'Badge inactif';
        LEAVE sp_verifier_acces;
    END IF;
    
    -- Badge expiré
    IF v_date_expiration IS NOT NULL AND v_date_expiration < CURDATE() THEN
        SET p_message = 'Badge expiré';
        LEAVE sp_verifier_acces;
    END IF;
    
    -- Vérification de l'utilisateur
    SELECT actif INTO v_badge_actif
    FROM utilisateurs
    WHERE id_utilisateur = p_id_utilisateur;
    
    IF v_badge_actif = FALSE THEN
        SET p_message = 'Utilisateur inactif';
        LEAVE sp_verifier_acces;
    END IF;
    
    -- Vérification des autorisations d'accès
    SELECT 
        a.actif,
        a.heure_debut,
        a.heure_fin,
        a.jours_semaine
    INTO 
        v_autorisation_active,
        v_heure_debut,
        v_heure_fin,
        v_jours_autorises
    FROM autorisations_acces a
    WHERE a.id_utilisateur = p_id_utilisateur
        AND a.id_porte = p_id_porte
        AND (a.date_debut_validite IS NULL OR a.date_debut_validite <= CURDATE())
        AND (a.date_fin_validite IS NULL OR a.date_fin_validite >= CURDATE());
    
    -- Pas d'autorisation pour cette porte
    IF v_autorisation_active IS NULL THEN
        SET p_message = 'Aucune autorisation pour cette porte';
        LEAVE sp_verifier_acces;
    END IF;
    
    -- Autorisation inactive
    IF v_autorisation_active = FALSE THEN
        SET p_message = 'Autorisation désactivée';
        LEAVE sp_verifier_acces;
    END IF;
    
    -- Vérification du jour
    IF FIND_IN_SET(v_jour_actuel, v_jours_autorises) = 0 THEN
        SET p_message = 'Accès non autorisé ce jour';
        LEAVE sp_verifier_acces;
    END IF;
    
    -- Vérification de l'horaire
    IF v_heure_actuelle < v_heure_debut OR v_heure_actuelle > v_heure_fin THEN
        SET p_message = 'Hors plage horaire autorisée';
        LEAVE sp_verifier_acces;
    END IF;
    
    -- Toutes les vérifications passées : accès autorisé
    SET p_autorisation = TRUE;
    SET p_message = 'Accès accordé';
    
END$$

-- Procédure : Enregistrer un événement d'accès
CREATE PROCEDURE sp_enregistrer_acces(
    IN p_id_porte INT,
    IN p_id_utilisateur INT,
    IN p_uid_badge VARCHAR(50),
    IN p_type_evenement VARCHAR(50),
    IN p_methode_acces VARCHAR(50),
    IN p_adresse_ip VARCHAR(15),
    IN p_details TEXT
)
BEGIN
    INSERT INTO logs_acces (
        id_porte,
        id_utilisateur,
        uid_badge,
        type_evenement,
        methode_acces,
        adresse_ip_source,
        details_supplementaires
    ) VALUES (
        p_id_porte,
        p_id_utilisateur,
        p_uid_badge,
        p_type_evenement,
        p_methode_acces,
        p_adresse_ip,
        p_details
    );
    
    -- Générer une alerte si accès refusé
    IF p_type_evenement IN ('acces_refuse', 'badge_inconnu', 'tentative_forcage') THEN
        INSERT INTO alertes (
            type_alerte,
            niveau_gravite,
            id_porte,
            message,
            notification_envoyee
        ) VALUES (
            CASE p_type_evenement
                WHEN 'badge_inconnu' THEN 'badge_inconnu'
                WHEN 'tentative_forcage' THEN 'tentative_forcage'
                ELSE 'autre'
            END,
            'warning',
            p_id_porte,
            CONCAT('Tentative d''accès refusée - ', p_details),
            FALSE
        );
    END IF;
END$$

-- Procédure : Nettoyer les anciens logs
CREATE PROCEDURE sp_nettoyer_logs()
BEGIN
    DECLARE v_jours_conservation INT;
    
    -- Récupération du paramètre de conservation
    SELECT CAST(valeur_config AS SIGNED)
    INTO v_jours_conservation
    FROM configurations_systeme
    WHERE cle_config = 'conservation_logs_jours';
    
    -- Suppression des anciens logs d'accès
    DELETE FROM logs_acces
    WHERE timestamp_evenement < DATE_SUB(NOW(), INTERVAL v_jours_conservation DAY);
    
    -- Suppression des anciennes détections
    DELETE FROM logs_detections
    WHERE timestamp_detection < DATE_SUB(NOW(), INTERVAL v_jours_conservation DAY);
    
    -- Suppression des anciennes photos
    DELETE FROM photos_horodatees
    WHERE timestamp_photo < DATE_SUB(NOW(), INTERVAL v_jours_conservation DAY);
    
    -- Suppression des anciennes sessions
    DELETE FROM sessions_admin
    WHERE timestamp_expiration < DATE_SUB(NOW(), INTERVAL 7 DAY);
END$$

DELIMITER ;

-- ============================================================================
-- TRIGGERS POUR L'AUDIT ET LA SÉCURITÉ
-- ============================================================================

DELIMITER $$

-- Trigger : Audit des modifications d'utilisateurs
CREATE TRIGGER trg_audit_utilisateurs_update
AFTER UPDATE ON utilisateurs
FOR EACH ROW
BEGIN
    IF OLD.actif != NEW.actif OR 
       OLD.nom != NEW.nom OR 
       OLD.prenom != NEW.prenom OR 
       OLD.email != NEW.email THEN
        INSERT INTO logs_modifications (
            table_modifiee,
            id_enregistrement,
            type_operation,
            anciennes_valeurs,
            nouvelles_valeurs
        ) VALUES (
            'utilisateurs',
            NEW.id_utilisateur,
            'UPDATE',
            JSON_OBJECT(
                'nom', OLD.nom,
                'prenom', OLD.prenom,
                'email', OLD.email,
                'actif', OLD.actif
            ),
            JSON_OBJECT(
                'nom', NEW.nom,
                'prenom', NEW.prenom,
                'email', NEW.email,
                'actif', NEW.actif
            )
        );
    END IF;
END$$

-- Trigger : Validation des badges RFID
CREATE TRIGGER trg_validate_badge_before_insert
BEFORE INSERT ON badges_rfid
FOR EACH ROW
BEGIN
    -- Vérification du format UID (doit être en hexadécimal)
    IF NEW.uid_badge NOT REGEXP '^[0-9A-Fa-f]+$' THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'UID du badge invalide (doit être hexadécimal)';
    END IF;
    
    -- Si date d'expiration non définie, définir à 1 an par défaut
    IF NEW.date_expiration IS NULL AND NEW.date_attribution IS NOT NULL THEN
        SET NEW.date_expiration = DATE_ADD(NEW.date_attribution, INTERVAL 1 YEAR);
    END IF;
END$$

-- Trigger : Nettoyage automatique des sessions expirées
CREATE TRIGGER trg_clean_expired_sessions
BEFORE INSERT ON sessions_admin
FOR EACH ROW
BEGIN
    DELETE FROM sessions_admin
    WHERE timestamp_expiration < NOW();
END$$

DELIMITER ;

-- ============================================================================
-- ÉVÉNEMENTS PLANIFIÉS
-- ============================================================================

-- Activation du planificateur d'événements
SET GLOBAL event_scheduler = ON;

-- Événement : Nettoyage quotidien des logs
CREATE EVENT evt_nettoyage_quotidien
ON SCHEDULE EVERY 1 DAY
STARTS TIMESTAMP(CURDATE() + INTERVAL 1 DAY, '02:00:00')
DO
    CALL sp_nettoyer_logs();

-- Événement : Désactivation automatique des badges expirés
CREATE EVENT evt_desactiver_badges_expires
ON SCHEDULE EVERY 1 HOUR
DO
    UPDATE badges_rfid
    SET actif = FALSE
    WHERE date_expiration < CURDATE()
    AND actif = TRUE;

-- ============================================================================
-- CRÉATION D'UN UTILISATEUR ADMIN PAR DÉFAUT
-- ============================================================================

-- Note : Le mot de passe 'admin123' doit être changé immédiatement
-- Hash bcrypt de 'admin123' : $2y$10$92IXUNpkjO0rOQ5byMi.Ye4oKoEa3Ro9llC/.og/at2.uheWG/igi

INSERT INTO utilisateurs (nom, prenom, email, statut, id_role, actif) VALUES
('Administrateur', 'Système', 'admin@cerbere.local', 'enseignant', 6, TRUE);

INSERT INTO administrateurs (username, password_hash, id_utilisateur, niveau_acces, actif) VALUES
('admin', '$2y$10$92IXUNpkjO0rOQ5byMi.Ye4oKoEa3Ro9llC/.og/at2.uheWG/igi', 1, 'super_admin', TRUE);

-- ============================================================================
-- PERMISSIONS ET SÉCURITÉ
-- ============================================================================

-- Création d'un utilisateur MySQL dédié pour l'application
-- Note : Adapter le mot de passe selon les besoins de sécurité
CREATE USER IF NOT EXISTS 'cerbere_app'@'localhost' IDENTIFIED BY 'CerbereSecure2026!';

-- Attribution des permissions
GRANT SELECT, INSERT, UPDATE ON cerbere_db.* TO 'cerbere_app'@'localhost';
GRANT EXECUTE ON cerbere_db.* TO 'cerbere_app'@'localhost';

-- L'utilisateur ne peut pas supprimer de données (sauf pour le nettoyage automatique)
REVOKE DELETE ON cerbere_db.* FROM 'cerbere_app'@'localhost';

-- Appliquer les permissions
FLUSH PRIVILEGES;

-- ============================================================================
-- FIN DU SCRIPT
-- ============================================================================

-- Affichage d'un résumé
SELECT 'Base de données CERBÈRE créée avec succès!' AS Statut;
SELECT COUNT(*) AS Nombre_Tables FROM information_schema.tables 
WHERE table_schema = 'cerbere_db';

-- ============================================================================
-- DOCUMENTATION ET NOTES
-- ============================================================================
/*
NOTES IMPORTANTES POUR LE DÉPLOIEMENT :

1. SÉCURITÉ :
   - Changer IMMÉDIATEMENT le mot de passe admin par défaut
   - Utiliser des mots de passe forts pour l'utilisateur MySQL
   - Activer le SSL pour les connexions à la base de données
   - Implémenter un système de sauvegarde régulier

2. PERFORMANCE :
   - Les index sont créés sur les colonnes fréquemment utilisées
   - Les vues facilitent les requêtes complexes
   - Les procédures stockées optimisent les opérations répétitives

3. MAINTENANCE :
   - Le nettoyage automatique des logs est planifié quotidiennement
   - Les badges expirés sont désactivés automatiquement
   - L'audit trail conserve toutes les modifications importantes

4. ÉVOLUTIONS FUTURES :
   - Ajouter des tables pour la gestion des horaires complexes
   - Implémenter un système de groupes d'utilisateurs
   - Ajouter des statistiques avancées et tableaux de bord

5. RASPBERRY PI :
   - Chaque Raspberry Pi doit avoir une IP fixe configurée
   - Les identifiants raspberry_pi_id doivent correspondre aux hostnames
   - Prévoir une table de configuration réseau si nécessaire

6. INTÉGRATION :
   - Les API devront utiliser les procédures stockées pour la logique métier
   - Les applications mobiles accèderont via une couche API REST
   - Le dashboard web utilisera les vues pour l'affichage

CONTACT PROJET :
- Établissement : Lycée Joseph Gaillard, Fort-de-France
- Responsable BDD : Dylan FRANCIS (Étudiant 2)
- Superviseurs : Mr Philippe Ravion, Mme Myriam Symphor
- Session : 2026
*/
