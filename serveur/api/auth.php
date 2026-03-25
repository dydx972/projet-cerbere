<?php
require_once "db.php";
$d = json_decode(file_get_contents("php://input"), true);
$u = $d["username"] ?? ""; $p = $d["password"] ?? "";
if ($u === "admin" && $p === "admin123") {
    echo json_encode(["success"=>true,"role"=>"SUPER_ADMIN"]);
} else {
    http_response_code(401);
    echo json_encode(["success"=>false,"error"=>"Identifiants incorrects"]);
}
