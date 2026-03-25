<?php
require_once "db.php";
$method = $_SERVER["REQUEST_METHOD"];
define("CAPTURES_DIR", "/var/www/html/captures/");

function captureFrame($stream_url) {
    $ctx = stream_context_create(["http" => ["timeout" => 6, "method" => "GET"]]);
    $handle = @fopen($stream_url, "r", false, $ctx);
    if (!$handle) return false;

    $buf = "";
    $read = 0;
    $jpeg_start = -1;

    while (!feof($handle) && $read < 1000000) {
        $chunk = fread($handle, 8192);
        if ($chunk === false || $chunk === "") break;
        $buf .= $chunk;
        $read += strlen($chunk);

        // Cherche le marqueur de début JPEG : FF D8 FF
        if ($jpeg_start === -1) {
            for ($i = 0; $i < strlen($buf) - 2; $i++) {
                if (ord($buf[$i]) === 0xFF && ord($buf[$i+1]) === 0xD8 && ord($buf[$i+2]) === 0xFF) {
                    $jpeg_start = $i;
                    break;
                }
            }
        }

        // Une fois le début trouvé, cherche le marqueur de fin : FF D9
        if ($jpeg_start !== -1) {
            $search_from = max(0, strlen($buf) - 3);
            for ($i = $jpeg_start + 2; $i < strlen($buf) - 1; $i++) {
                if (ord($buf[$i]) === 0xFF && ord($buf[$i+1]) === 0xD9) {
                    $jpeg = substr($buf, $jpeg_start, $i - $jpeg_start + 2);
                    fclose($handle);
                    if (strlen($jpeg) > 5000) return $jpeg;
                    // Frame trop petite, cherche la suivante
                    $buf = substr($buf, $i + 2);
                    $jpeg_start = -1;
                    break;
                }
            }
        }
    }
    fclose($handle);
    return false;
}

if ($method === "GET") {
    $sql = "SELECT ph.*, c.nom_camera
            FROM photos_horodatees ph
            LEFT JOIN cameras c ON ph.id_camera = c.id_camera
            ORDER BY ph.timestamp_photo DESC
            LIMIT 50";
    echo json_encode(["success" => true, "data" => $pdo->query($sql)->fetchAll()]);

} elseif ($method === "POST") {
    $d = json_decode(file_get_contents("php://input"), true);
    $cam_name = $d["camera_name"] ?? "";

    // Récupère la caméra en BDD
    $stmt = $pdo->prepare("SELECT * FROM cameras WHERE nom_camera = ? LIMIT 1");
    $stmt->execute([$cam_name]);
    $cam = $stmt->fetch();
    if (!$cam) {
        echo json_encode(["success" => false, "error" => "Caméra inconnue : $cam_name"]);
        exit;
    }

    $stream_url = $cam["adresse_stream"];
    if (!$stream_url) {
        echo json_encode(["success" => false, "error" => "Aucun flux configuré pour cette caméra"]);
        exit;
    }

    // Capture le frame JPEG
    $jpeg = captureFrame($stream_url);
    if (!$jpeg) {
        echo json_encode(["success" => false, "error" => "Impossible de capturer un frame depuis : $stream_url"]);
        exit;
    }

    // Sauvegarde le fichier
    $safe     = preg_replace('/[^a-z0-9]/', '_', strtolower($cam_name));
    $filename = "capture_{$safe}_" . date("Ymd_His") . ".jpg";
    $filepath = CAPTURES_DIR . $filename;
    file_put_contents($filepath, $jpeg);
    $size_ko  = (int) round(strlen($jpeg) / 1024);

    // Enregistrement dans photos_horodatees
    $stmt = $pdo->prepare(
        "INSERT INTO photos_horodatees (id_camera, chemin_fichier, taille_fichier_ko, type_evenement)
         VALUES (?, ?, ?, 'manuel')"
    );
    $stmt->execute([$cam["id_camera"], "/captures/" . $filename, $size_ko]);
    $id = $pdo->lastInsertId();

    echo json_encode([
        "success"   => true,
        "id"        => $id,
        "fichier"   => $filename,
        "taille_ko" => $size_ko,
        "url"       => "/captures/" . $filename
    ]);

} else {
    echo json_encode(["error" => "Method not allowed"]);
}
