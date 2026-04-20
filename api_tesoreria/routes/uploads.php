<?php
/**
 * Ruta de Subida de Archivos Blindada - Tesorería API
 * Migrada del index.php original
 */

$target_dir = "uploads/";
if (!is_dir($target_dir)) {
    mkdir($target_dir, 0755, true);
    // Auto-generador del .htaccess de seguridad en la carpeta uploads
    $htaccess_path = $target_dir . ".htaccess";
    if (!file_exists($htaccess_path)) {
        $htaccess_content = "php_flag engine 0\n" .
                            "RemoveHandler .phtml .php .php3 .php4 .php5 .php6 .phps .cgi .exe .pl .asp .aspx .shtml .shtm .fcgi .fpl .jsp .htm .html .wml\n" .
                            "AddType application/x-httpd-php-source .phtml .php .php3 .php4 .php5 .php6 .phps .cgi .exe .pl .asp .aspx .shtml .shtm .fcgi .fpl .jsp .htm .html .wml\n" .
                            "Options -Indexes -ExecCGI\n";
        file_put_contents($htaccess_path, $htaccess_content);
    }
}

if (!isset($_FILES['archivo']) || $_FILES['archivo']['error'] !== UPLOAD_ERR_OK) {
    http_response_code(400);
    echo json_encode(['ok' => false, 'msj' => 'No se recibió ningún archivo o hubo un error.']);
    exit;
}

$file = $_FILES['archivo'];
$max_size = 15 * 1024 * 1024; // 15 MB
if ($file['size'] > $max_size) {
    http_response_code(400);
    echo json_encode(['ok' => false, 'msj' => 'Archivo demasiado grande (Máx 15MB).']);
    exit;
}

$allowed_extensions = ['jpg', 'jpeg', 'png', 'webp', 'pdf', 'mp4', 'mp3', 'mpeg'];
$file_info = pathinfo($file['name']);
$extension = strtolower($file_info['extension'] ?? '');

if (!in_array($extension, $allowed_extensions)) {
    http_response_code(400);
    echo json_encode(['ok' => false, 'msj' => 'Tipo de archivo no permitido.']);
    exit;
}

$finfo = finfo_open(FILEINFO_MIME_TYPE);
$mime_type = finfo_file($finfo, $file['tmp_name']);
finfo_close($finfo);

$allowed_mime_types = ['image/jpeg', 'image/png', 'image/webp', 'application/pdf', 'video/mp4', 'audio/mpeg'];
if (!in_array($mime_type, $allowed_mime_types)) {
    http_response_code(400);
    echo json_encode(['ok' => false, 'msj' => 'Contenido interno no permitido.']);
    exit;
}

$clean_name = bin2hex(random_bytes(16)) . '_' . time() . '.' . $extension;
$target_path = $target_dir . $clean_name;

if (move_uploaded_file($file['tmp_name'], $target_path)) {
    $protocol = (isset($_SERVER['HTTPS']) && $_SERVER['HTTPS'] === 'on') ? "https" : "http";
    $host = $_SERVER['HTTP_HOST'];
    $dir = rtrim(dirname($_SERVER['PHP_SELF']), '/\\');
    echo json_encode([
        'ok' => true, 
        'msj' => 'Archivo subido y blindado exitosamente.',
        'url' => $protocol . "://" . $host . $dir . "/" . $target_dir . $clean_name,
        'filename' => $clean_name
    ]);
} else {
    http_response_code(500);
    echo json_encode(['ok' => false, 'msj' => 'Error de escritura en el servidor.']);
}
