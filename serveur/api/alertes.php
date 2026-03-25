<?php
require_once "db.php";
$method = $_SERVER["REQUEST_METHOD"];
if ($method === "GET") {
    $sql = "SELECT a.*, p.nom_porte FROM alertes a LEFT JOIN portes p ON a.id_porte=p.id_porte ORDER BY a.acquittee ASC, a.timestamp_alerte DESC LIMIT 50";
    echo json_encode(["success"=>true,"data"=>$pdo->query($sql)->fetchAll()]);
} elseif ($method === "POST") {
    $d = json_decode(file_get_contents("php://input"), true);
    $stmt = $pdo->prepare("INSERT INTO alertes (type_alerte,niveau_gravite,id_porte,message) VALUES (?,?,?,?)");
    $stmt->execute([$d["type_alerte"]??"autre",$d["niveau_gravite"]??"warning",$d["id_porte"]??null,$d["message"]]);
    echo json_encode(["success"=>true,"id"=>$pdo->lastInsertId()]);
} elseif ($method === "PUT") {
    $id = (int)($_GET["id"] ?? 0);
    $pdo->prepare("UPDATE alertes SET acquittee=1, timestamp_acquittement=NOW() WHERE id_alerte=?")->execute([$id]);
    echo json_encode(["success"=>true]);
} else { echo json_encode(["error"=>"Method not allowed"]); }
