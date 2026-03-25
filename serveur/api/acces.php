<?php
require_once "db.php";
$method = $_SERVER["REQUEST_METHOD"];
if ($method === "GET") {
    if (isset($_GET["portes"])) {
        echo json_encode(["success"=>true,"portes"=>$pdo->query("SELECT id_porte,nom_porte FROM portes WHERE actif=1")->fetchAll()]);
        exit;
    }
    $sql = "SELECT a.*, u.nom, u.prenom, p.nom_porte FROM autorisations_acces a JOIN utilisateurs u ON a.id_utilisateur=u.id_utilisateur JOIN portes p ON a.id_porte=p.id_porte ORDER BY u.nom";
    echo json_encode(["success"=>true,"data"=>$pdo->query($sql)->fetchAll()]);
} elseif ($method === "POST") {
    $d = json_decode(file_get_contents("php://input"), true);
    $stmt = $pdo->prepare("INSERT INTO autorisations_acces (id_utilisateur,id_porte,heure_debut,heure_fin,jours_semaine,date_debut_validite,date_fin_validite) VALUES (?,?,?,?,?,?,?)");
    $dfin = (isset($d["date_fin_validite"]) && $d["date_fin_validite"]) ? $d["date_fin_validite"] : null;
    $stmt->execute([$d["id_utilisateur"],$d["id_porte"],$d["heure_debut"]??"08:00:00",$d["heure_fin"]??"18:00:00",$d["jours_semaine"]??"lundi,mardi,mercredi,jeudi,vendredi",$d["date_debut_validite"],$dfin]);
    $id = $pdo->lastInsertId();
    $pdo->prepare("INSERT INTO logs_modifications (table_modifiee,id_enregistrement,type_operation,nouvelles_valeurs) VALUES (?,?,?,?)")->execute(["autorisations_acces",$id,"INSERT","Nouvelle autorisation"]);
    echo json_encode(["success"=>true,"id"=>$id]);
} elseif ($method === "DELETE") {
    $id = (int)($_GET["id"] ?? 0);
    $pdo->prepare("UPDATE autorisations_acces SET actif=0 WHERE id_autorisation=?")->execute([$id]);
    echo json_encode(["success"=>true]);
} else { echo json_encode(["error"=>"Method not allowed"]); }
