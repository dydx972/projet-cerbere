<?php
require_once "db.php";

header("Access-Control-Allow-Origin: *");
header("Access-Control-Allow-Methods: POST, OPTIONS");
header("Access-Control-Allow-Headers: Content-Type");
if ($_SERVER["REQUEST_METHOD"] === "OPTIONS") { http_response_code(200); exit; }

if ($_SERVER["REQUEST_METHOD"] !== "POST") {
    http_response_code(405);
    echo json_encode(["error" => "Methode non autorisee"]);
    exit;
}

$d = json_decode(file_get_contents("php://input"), true);
$duree = min((int)($d["duree"] ?? 5), 30);

// Envoyer la commande au Pi RFID (192.168.1.49)
$payload = json_encode(["secret" => "cerbere2026", "duree" => $duree]);
$ctx = stream_context_create([
    "http" => [
        "method" => "POST",
        "header" => "Content-Type: application/json\r\n",
        "content" => $payload,
        "timeout" => 5
    ]
]);

$result = @file_get_contents("http://192.168.1.49:5000/ouvrir", false, $ctx);

if ($result === false) {
    http_response_code(502);
    echo json_encode(["success" => false, "error" => "Impossible de contacter le controleur de porte"]);
    exit;
}

$response = json_decode($result, true);

// Log dans la BDD
$pdo->prepare(
    "INSERT INTO logs_acces (id_porte, type_evenement, methode_acces, details_supplementaires)
     VALUES (1, 'acces_accorde', 'ouverture_distance', ?)"
)->execute(["Ouverture a distance — duree {$duree}s"]);

echo json_encode([
    "success" => true,
    "message" => "Porte ouverte pour {$duree} secondes",
    "id_log" => $pdo->lastInsertId()
]);
