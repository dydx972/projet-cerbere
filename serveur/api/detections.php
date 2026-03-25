<?php
require_once "db.php";

$method = $_SERVER["REQUEST_METHOD"];

// ─── GET : Liste les dernières détections avec captures associées ─────────────
if ($method === "GET") {
    $sql = "SELECT ld.id_detection, ld.id_capteur, ld.jour_detection, ld.heure_detection,
                   ld.duree_detection_secondes, ld.alerte_generee, ld.details,
                   cp.nom_capteur,
                   ph.chemin_fichier AS capture_url, ph.taille_fichier_ko AS capture_taille_ko
            FROM logs_detections ld
            LEFT JOIN capteurs_presence cp ON ld.id_capteur = cp.id_capteur
            LEFT JOIN photos_horodatees ph ON ph.id_detection = ld.id_detection
            ORDER BY ld.jour_detection DESC, ld.heure_detection DESC
            LIMIT 50";
    $data = $pdo->query($sql)->fetchAll();
    echo json_encode(["success" => true, "data" => $data]);
    exit;
}

// ─── POST : Enregistre une détection + capture caméra automatique ─────────────
if ($method !== "POST") {
    http_response_code(405);
    echo json_encode(["error" => "Méthode non autorisée."]);
    exit;
}

$d = json_decode(file_get_contents("php://input"), true);

if (empty($d["id_capteur"])) {
    http_response_code(400);
    echo json_encode(["error" => "Champ obligatoire manquant : id_capteur"]);
    exit;
}

$id_capteur = (int) $d["id_capteur"];
$duree      = isset($d["duree_detection_secondes"]) ? (int) $d["duree_detection_secondes"] : null;
$alerte     = !empty($d["alerte_generee"]) ? 1 : 0;
$details    = $d["details"] ?? null;

// Vérifie que le capteur existe (+ récupère id_porte)
$stmt = $pdo->prepare("SELECT id_capteur, nom_capteur, id_porte FROM capteurs_presence WHERE id_capteur = ? AND actif = 1");
$stmt->execute([$id_capteur]);
$capteur = $stmt->fetch();

if (!$capteur) {
    http_response_code(404);
    echo json_encode(["error" => "Capteur ID=$id_capteur introuvable ou inactif."]);
    exit;
}

// Enregistre la détection
$stmt = $pdo->prepare(
    "INSERT INTO logs_detections
       (id_capteur, jour_detection, heure_detection, duree_detection_secondes, alerte_generee, details)
     VALUES (?, CURDATE(), CURTIME(), ?, ?, ?)"
);
$stmt->execute([$id_capteur, $duree, $alerte, $details]);
$id_detection = $pdo->lastInsertId();

// Met à jour la dernière détection du capteur
$pdo->prepare("UPDATE capteurs_presence SET derniere_detection = NOW() WHERE id_capteur = ?")
    ->execute([$id_capteur]);

// Si alerte : insère dans la table alertes
if ($alerte) {
    $pdo->prepare(
        "INSERT INTO alertes (type_alerte, niveau_gravite, id_capteur, message)
         VALUES ('presence_suspecte', 'warning', ?, ?)"
    )->execute([$id_capteur, $details ?? "Présence prolongée — " . $capteur["nom_capteur"]]);
}

// ─── CAPTURE CAMÉRA AUTOMATIQUE ───────────────────────────────────────────────
$capture_info = null;
$stmt = $pdo->prepare("SELECT * FROM cameras WHERE id_porte = ? AND actif = 1 AND adresse_stream IS NOT NULL LIMIT 1");
$stmt->execute([$capteur["id_porte"]]);
$cam = $stmt->fetch();

if ($cam && $cam["adresse_stream"]) {
    // Utilise /snapshot au lieu de /stream pour obtenir un JPEG directement
    $snapshot_url = str_replace('/stream', '/snapshot', $cam["adresse_stream"]);
    $ctx = stream_context_create(["http" => ["timeout" => 8, "method" => "GET"]]);
    $jpeg = @file_get_contents($snapshot_url, false, $ctx);

    if ($jpeg !== false && strlen($jpeg) > 1000) {
        $captures_dir = "/var/www/html/captures/";
        $safe = preg_replace('/[^a-z0-9]/', '_', strtolower($cam["nom_camera"]));
        $filename = "detection_" . $safe . "_" . date("Ymd_His") . ".jpg";
        $filepath = $captures_dir . $filename;
        file_put_contents($filepath, $jpeg);
        $size_ko = (int) round(strlen($jpeg) / 1024);

        $stmt = $pdo->prepare(
            "INSERT INTO photos_horodatees (id_camera, id_detection, chemin_fichier, taille_fichier_ko, type_evenement)
             VALUES (?, ?, ?, ?, 'alerte')"
        );
        $stmt->execute([$cam["id_camera"], $id_detection, "/captures/" . $filename, $size_ko]);

        $capture_info = [
            "id_photo"    => $pdo->lastInsertId(),
            "fichier"     => $filename,
            "taille_ko"   => $size_ko,
            "url"         => "/captures/" . $filename
        ];
    }
}

echo json_encode([
    "success"      => true,
    "id_detection" => $id_detection,
    "capteur"      => $capteur["nom_capteur"],
    "alerte"       => (bool) $alerte,
    "capture"      => $capture_info
]);
