<?php
require_once "db.php";
$method = $_SERVER["REQUEST_METHOD"];
if ($method === "GET") {
    $sql = "SELECT u.*, r.nom_role, b.uid_badge FROM utilisateurs u LEFT JOIN roles r ON u.id_role=r.id_role LEFT JOIN badges_rfid b ON b.id_utilisateur=u.id_utilisateur AND b.actif=1 ORDER BY u.nom, u.prenom";
    echo json_encode(["success"=>true,"data"=>$pdo->query($sql)->fetchAll()]);
} elseif ($method === "POST") {
    $d = json_decode(file_get_contents("php://input"), true);
    $stmt = $pdo->prepare("INSERT INTO utilisateurs (nom,prenom,email,telephone,statut,id_role,etablissement) VALUES (?,?,?,?,?,?,?)");
    $stmt->execute([$d["nom"],$d["prenom"],$d["email"]??null,$d["telephone"]??null,$d["statut"]??"etudiant",(int)($d["id_role"]??1),$d["etablissement"]??"Lycee Joseph Gaillard"]);
    $id = $pdo->lastInsertId();
    $pdo->prepare("INSERT INTO logs_modifications (table_modifiee,id_enregistrement,type_operation,nouvelles_valeurs) VALUES (?,?,?,?)")->execute(["utilisateurs",$id,"INSERT","Nouvel utilisateur: ".$d["nom"]." ".$d["prenom"]]);
    echo json_encode(["success"=>true,"id"=>$id]);
} elseif ($method === "DELETE") {
    $id = (int)($_GET["id"] ?? 0);
    $pdo->prepare("UPDATE utilisateurs SET actif=0 WHERE id_utilisateur=?")->execute([$id]);
    $pdo->prepare("INSERT INTO logs_modifications (table_modifiee,id_enregistrement,type_operation,nouvelles_valeurs) VALUES (?,?,?,?)")->execute(["utilisateurs",$id,"UPDATE","Utilisateur desactive"]);
    echo json_encode(["success"=>true]);
} else { echo json_encode(["error"=>"Method not allowed"]); }
