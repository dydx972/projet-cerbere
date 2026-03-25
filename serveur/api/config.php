<?php
require_once "db.php";
$method = $_SERVER["REQUEST_METHOD"];
if ($method === "GET") {
    echo json_encode(["success"=>true,"data"=>$pdo->query("SELECT * FROM configurations_systeme ORDER BY id_config")->fetchAll()]);
} elseif ($method === "PUT") {
    $d = json_decode(file_get_contents("php://input"), true);
    $stmt = $pdo->prepare("UPDATE configurations_systeme SET valeur_config=? WHERE cle_config=? AND modifiable=1");
    foreach($d["updates"]??[] as $u) {
        $stmt->execute([$u["val"],$u["key"]]);
        $pdo->prepare("INSERT INTO logs_modifications (table_modifiee,id_enregistrement,type_operation,nouvelles_valeurs) VALUES (?,?,?,?)")->execute(["configurations_systeme",0,"UPDATE",$u["key"]." = ".$u["val"]]);
    }
    echo json_encode(["success"=>true]);
}
