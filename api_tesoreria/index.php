<?php
// BÚNKER DE SEGURIDAD - API DE SUBIDA
header('Content-Type: application/json; charset=utf-8');

// 1. VERIFICAR LLAVE DE SEGURIDAD (API KEY)
$secret_key = "Insoft2026_SecureKey";
$headers = apache_request_headers();

$auth_header = isset($headers['Authorization']) ? $headers['Authorization'] : 
              (isset($headers['authorization']) ? $headers['authorization'] : '');

if ($auth_header !== "Bearer " . $secret_key) {
    http_response_code(401);
    echo json_encode(['ok' => false, 'msj' => 'Acceso denegado. Credenciales inválidas.']);
    exit;
}

// 2. CONFIGURACIÓN DE SUBIDA
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

// 3. RECIBIR EL ARCHIVO
if (!isset($_FILES['archivo']) || $_FILES['archivo']['error'] !== UPLOAD_ERR_OK) {
    http_response_code(400);
    echo json_encode(['ok' => false, 'msj' => 'No se recibió ningún archivo o hubo un error en la transmisión.']);
    exit;
}

$file = $_FILES['archivo'];

// 4. VALIDACIÓN ESTRICTA DE SEGURIDAD (Lista Blanca y finfo)
$max_size = 15 * 1024 * 1024; // 15 MB limit
if ($file['size'] > $max_size) {
    http_response_code(400);
    echo json_encode(['ok' => false, 'msj' => 'El archivo supera el límite máximo permitido (15MB).']);
    exit;
}

// Lista Blanca Estricta de Extensiones (en minúsculas)
$allowed_extensions = ['jpg', 'jpeg', 'png', 'webp', 'pdf', 'mp4', 'mp3', 'mpeg'];
$file_info = pathinfo($file['name']);
$extension = isset($file_info['extension']) ? strtolower($file_info['extension']) : '';

if (!in_array($extension, $allowed_extensions, true)) {
    http_response_code(400);
    echo json_encode(['ok' => false, 'msj' => 'Tipo de archivo no permitido.']);
    exit;
}

// Validación de Tipo MIME con finfo (Lectura de bytes a bajo nivel)
// Requiere que la extensión 'fileinfo' esté habilitada en el servidor (normalmente lo está)
if (function_exists('finfo_open')) {
    $finfo = finfo_open(FILEINFO_MIME_TYPE);
    $mime_type = finfo_file($finfo, $file['tmp_name']);
    finfo_close($finfo);
} else {
    // Fallback básico si finfo no está disponible (menos seguro pero necesario en algunos Hostings)
    $mime_type = mime_content_type($file['tmp_name']);
}

$allowed_mime_types = [
    'image/jpeg', 
    'image/png', 
    'image/webp', 
    'application/pdf', 
    'video/mp4', 
    'audio/mpeg'
];

if (!in_array($mime_type, $allowed_mime_types, true)) {
    http_response_code(400);
    echo json_encode(['ok' => false, 'msj' => 'El contenido interno del archivo no coincide con un formato seguro.']);
    exit;
}

// Correlación de extensión y MIME tipo (Evita un PDF oculto como JPG)
$valid_mime_ext = false;
if (strpos($mime_type, 'image/') === 0 && in_array($extension, ['jpg', 'jpeg', 'png', 'webp'])) $valid_mime_ext = true;
if ($mime_type === 'application/pdf' && $extension === 'pdf') $valid_mime_ext = true;
if ($mime_type === 'video/mp4' && $extension === 'mp4') $valid_mime_ext = true;
if (strpos($mime_type, 'audio/') === 0 && in_array($extension, ['mp3', 'mpeg'])) $valid_mime_ext = true;

if (!$valid_mime_ext) {
    http_response_code(400);
    echo json_encode(['ok' => false, 'msj' => 'Inconsistencia entre extensión y contenido del archivo.']);
    exit;
}

// 5. GENERAR NOMBRE SEGURO Y ÚNICO
// Evitar Traversal Path (../) o Null Byte (%00)
try {
    $clean_name = bin2hex(random_bytes(16)) . '_' . time() . '.' . $extension;
} catch (Exception $e) {
    $clean_name = md5(uniqid(rand(), true)) . '_' . time() . '.' . $extension;
}
$target_path = $target_dir . $clean_name;

// 6. MOVER ARCHIVO FÍSICAMENTE AL SERVIDOR
if (move_uploaded_file($file['tmp_name'], $target_path)) {
    // Generar la URL final absoluta para que Flutter la pueda leer directamente
    $protocol = (isset($_SERVER['HTTPS']) && $_SERVER['HTTPS'] === 'on') ? "https" : "http";
    $host = $_SERVER['HTTP_HOST'];
    $dir = rtrim(dirname($_SERVER['PHP_SELF']), '/\\');
    
    $file_url = $protocol . "://" . $host . $dir . "/" . $target_dir . $clean_name;

    echo json_encode([
        'ok' => true, 
        'msj' => 'Archivo subido y blindado exitosamente.',
        'url' => $file_url,
        'filename' => $clean_name
    ]);
} else {
    http_response_code(500);
    echo json_encode(['ok' => false, 'msj' => 'Error de escritura en el disco del servidor.']);
}
?>
