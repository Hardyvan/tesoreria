<?php
/**
 * Middleware de Seguridad - DSI Tesorería API
 * Valida la API_SECRET_KEY provista en las cabeceras HTTP de forma ultra-compatible.
 */

function verificarSeguridadAPI() {
    $secretKey = getenv('API_SECRET_KEY') ?: ($_ENV['API_SECRET_KEY'] ?? '');
    
    // Obtener las cabeceras de la petición de forma compatible con Nginx y Apache (FastCGI)
    $headers = [];
    if (function_exists('apache_request_headers')) {
        $headers = apache_request_headers();
    } else {
        foreach ($_SERVER as $key => $value) {
            if (substr($key, 0, 5) === 'HTTP_') {
                $header = str_replace(' ', '-', ucwords(str_replace('_', ' ', strtolower(substr($key, 5)))));
                $headers[$header] = $value;
            }
        }
    }

    // Buscar cabecera de autorización de forma insensible a mayúsculas/minúsculas
    $authHeader = '';
    foreach ($headers as $key => $val) {
        if (strtolower($key) === 'authorization') {
            $authHeader = $val;
            break;
        }
    }

    // Fallbacks estándar y FastCGI para variables de servidor directas
    if (empty($authHeader)) {
        if (isset($_SERVER['HTTP_AUTHORIZATION'])) {
            $authHeader = $_SERVER['HTTP_AUTHORIZATION'];
        } elseif (isset($_SERVER['REDIRECT_HTTP_AUTHORIZATION'])) {
            $authHeader = $_SERVER['REDIRECT_HTTP_AUTHORIZATION'];
        }
    }

    if (empty($secretKey) || $authHeader !== "Bearer " . $secretKey) {
        http_response_code(401);
        header('Content-Type: application/json; charset=utf-8');
        echo json_encode([
            'ok' => false,
            'msj' => 'Acceso denegado. Tesorería API Key inválida o no configurada en las cabeceras de la petición.'
        ]);
        exit;
    }
}
