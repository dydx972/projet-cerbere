<?php
require_once "db.php";

if ($_SERVER["REQUEST_METHOD"] !== "POST") {
    http_response_code(405);
    echo json_encode(["error" => "Utiliser POST"]);
    exit;
}

$d        = json_decode(file_get_contents("php://input"), true);
$uid      = strtoupper(trim($d["uid"]      ?? ""));
$id_porte = (int)($d["id_porte"]           ?? 0);

if (!$uid || !$id_porte) {
    http_response_code(400);
    echo json_encode(["error" => "Champs obligatoires : uid, id_porte"]);
    exit;
}

// ── 1. Cherche le badge ──────────────────────────────────────────────────────
$stmt = $pdo->prepare(
    "SELECT b.*, u.nom, u.prenom, u.id_utilisateur
     FROM badges_rfid b
     LEFT JOIN utilisateurs u ON b.id_utilisateur = u.id_utilisateur
     WHERE b.uid_badge = ?"
);
$stmt->execute([$uid]);
$badge = $stmt->fetch();

// ── 2. Évalue l'autorisation ─────────────────────────────────────────────────
$autorise       = false;
$type_evenement = "";
$details        = "";
$id_utilisateur = null;

if (!$badge) {
    $type_evenement = "badge_inconnu";
    $details        = "UID non enregistré : $uid";

} elseif (!$badge["actif"] || $badge["perdu"]) {
    $type_evenement = "acces_refuse";
    $details        = $badge["perdu"] ? "Badge signalé perdu/volé" : "Badge désactivé ou expiré";
    $id_utilisateur = $badge["id_utilisateur"];

} elseif ($badge["date_expiration"] && $badge["date_expiration"] < date("Y-m-d")) {
    $type_evenement = "badge_expire";
    $details        = "Badge expiré le " . $badge["date_expiration"];
    $id_utilisateur = $badge["id_utilisateur"];

} else {
    // Vérifie les autorisations d'accès (porte uniquement, sans plage horaire)
    $id_utilisateur = $badge["id_utilisateur"];
    $stmt2 = $pdo->prepare(
        "SELECT * FROM autorisations_acces
         WHERE id_utilisateur = ?
           AND id_porte       = ?
           AND actif          = 1
           AND (date_debut_validite IS NULL OR date_debut_validite <= CURDATE())
           AND (date_fin_validite   IS NULL OR date_fin_validite   >= CURDATE())"
    );
    $stmt2->execute([$id_utilisateur, $id_porte]);
    $autorisation = $stmt2->fetch();

    if ($autorisation) {
        $autorise       = true;
        $type_evenement = "acces_accorde";
        $details        = "Accès normal";
    } else {
        $type_evenement = "acces_refuse";
        $details        = "Aucune autorisation pour cette porte";
    }
}

// ── 3. Log dans logs_acces ───────────────────────────────────────────────────
$pdo->prepare(
    "INSERT INTO logs_acces
       (id_porte, id_utilisateur, uid_badge, type_evenement, methode_acces, details_supplementaires)
     VALUES (?, ?, ?, ?, 'badge_rfid', ?)"
)->execute([$id_porte, $id_utilisateur, $uid, $type_evenement, $details]);

// ── 4. Si badge inconnu → alerte ─────────────────────────────────────────────
if ($type_evenement === "badge_inconnu") {
    $pdo->prepare(
        "INSERT INTO alertes (type_alerte, niveau_gravite, id_porte, message)
         VALUES ('badge_inconnu', 'critical', ?, ?)"
    )->execute([$id_porte, "Badge inconnu présenté — UID: $uid"]);
}

// ── 5. Réponse ───────────────────────────────────────────────────────────────
echo json_encode([
    "autorise"       => $autorise,
    "type_evenement" => $type_evenement,
    "details"        => $details,
    "utilisateur"    => $badge ? trim(($badge["nom"] ?? "") . " " . ($badge["prenom"] ?? "")) : null,
    "uid"            => $uid
]);
