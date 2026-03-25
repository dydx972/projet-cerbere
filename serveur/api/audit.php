<?php
require_once "db.php";
$sql = "SELECT * FROM logs_modifications ORDER BY date_modification DESC LIMIT 100";
echo json_encode(["success"=>true,"data"=>$pdo->query($sql)->fetchAll()]);
