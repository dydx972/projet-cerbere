<?php
require_once "db.php";
$method = $_SERVER["REQUEST_METHOD"];
$type = $_GET["type"] ?? "all";
$limit = min((int)($_GET["limit"] ?? 100), 500);
if ($method === "GET") {
    $where = ($type !== "all") ? "WHERE l.type_evenement = ?" : "";
    $params = ($type !== "all") ? [$type] : [];
    $sql = "SELECT l.*, p.nom_porte, u.nom, u.prenom FROM logs_acces l LEFT JOIN portes p ON l.id_porte=p.id_porte LEFT JOIN utilisateurs u ON l.id_utilisateur=u.id_utilisateur $where ORDER BY l.timestamp_evenement DESC LIMIT $limit";
    $stmt = $pdo->prepare($sql); $stmt->execute($params);
    echo json_encode(["success"=>true,"data"=>$stmt->fetchAll()]);
} elseif ($method === "POST") {
    $d = json_decode(file_get_contents("php://input"), true);
    $stmt = $pdo->prepare("INSERT INTO logs_acces (id_porte,id_utilisateur,uid_badge,type_evenement,methode_acces,details_supplementaires) VALUES (?,?,?,?,?,?)");
    $stmt->execute([$d["id_porte"],$d["id_utilisateur"]??null,$d["uid_badge"]??null,$d["type_evenement"],$d["methode_acces"]??"badge_rfid",$d["details"]??null]);
    echo json_encode(["success"=>true,"id"=>$pdo->lastInsertId()]);
}
