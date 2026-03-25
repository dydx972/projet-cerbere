<?php
require_once "db.php";
$method = $_SERVER["REQUEST_METHOD"];
if ($method === "GET") {
    $sql = "SELECT b.*, u.nom, u.prenom FROM badges_rfid b LEFT JOIN utilisateurs u ON b.id_utilisateur=u.id_utilisateur ORDER BY b.date_creation DESC";
    echo json_encode(["success"=>true,"data"=>$pdo->query($sql)->fetchAll()]);
} elseif ($method === "POST") {
    $d = json_decode(file_get_contents("php://input"), true);
    $stmt = $pdo->prepare("INSERT INTO badges_rfid (uid_badge,lectures_json,type_badge,id_utilisateur,date_attribution,date_expiration) VALUES (?,?,?,?,?,?)");
    $stmt->execute([
        $d["uid_badge"],
        $d["lectures_json"] ?? null,
        $d["type_badge"]   ?? "Mifare_Classic",
        $d["id_utilisateur"] ?? null,
        $d["date_attribution"] ?? null,
        $d["date_expiration"]  ?? null
    ]);
    $id = $pdo->lastInsertId();
    $pdo->prepare("INSERT INTO logs_modifications (table_modifiee,id_enregistrement,type_operation,nouvelles_valeurs) VALUES (?,?,?,?)")->execute(["badges_rfid",$id,"INSERT","Nouveau badge: ".$d["uid_badge"]]);
    echo json_encode(["success"=>true,"id"=>$id]);
} elseif ($method === "DELETE") {
    $id = (int)($_GET["id"] ?? 0);
    $pdo->prepare("UPDATE badges_rfid SET actif=0 WHERE id_badge=?")->execute([$id]);
    echo json_encode(["success"=>true]);
} else { echo json_encode(["error"=>"Method not allowed"]); }
