<?php
/**
 * Middleware de seguridad para validar la API_SECRET_KEY en Tesorería
 */

function verificarSeguridadAPI() {
    $envFile = __DIR__ . '/../.env';
    if (file_exists($envFile)) {
        $lines = file($envFile, FILE_IGNORE_NEW_LINES | FILE_SKIP_EMPTY_LINES);
        foreach ($lines as $line) {
            if (strpos(trim($line), '#') === 0) continue;
            if (strpos($line, '=') !== false) {
                [$key, $value] = explode('=', $line, 2);
                $key = trim($key);
                $value = trim(trim($value), '"\'');
                if ($key === 'API_SECRET_KEY') {
                    putenv("$key=$value");
                    $_ENV[$key] = $value;
                    break;
                }
            }
        }
    }

    $secret_key = getenv('API_SECRET_KEY') ?: ($_ENV['API_SECRET_KEY'] ?? '');
    
    $headers = apache_request_headers();
    $auth_header = isset($headers['Authorization']) ? $headers['Authorization'] : (isset($headers['authorization']) ? $headers['authorization'] : '');

    if (empty($secret_key) || $auth_header !== "Bearer " . $secret_key) {
        http_response_code(401);
        echo json_encode(['ok' => false, 'msj' => 'Acceso denegado. Tesorería API Key inválida o no configurada.']);
        exit;
    }
}
