<?php
/**
 * Conexión a la base de datos MySQL usando PDO
 * Tesorería API - Estructura Modular
 */

function getDBConnection(): PDO {
    static $pdo = null;
    if ($pdo !== null) return $pdo;

    $envFile = __DIR__ . '/../.env';
    if (file_exists($envFile)) {
        $lines = file($envFile, FILE_IGNORE_NEW_LINES | FILE_SKIP_EMPTY_LINES);
        foreach ($lines as $line) {
            if (strpos(trim($line), '#') === 0) continue;
            if (strpos($line, '=') !== false) {
                [$key, $value] = explode('=', $line, 2);
                $key = trim($key);
                $value = trim(trim($value), '"\'');
                putenv("$key=$value");
                $_ENV[$key] = $value;
            }
        }
    }

    $host    = getenv('DB_HOST') ?: 'localhost';
    $dbname  = getenv('DB_NAME') ?: '';
    $user    = getenv('DB_USER') ?: '';
    $pass    = getenv('DB_PASS') ?: '';
    $charset = getenv('DB_CHARSET') ?: 'utf8mb4';

    $dsn = "mysql:host={$host};dbname={$dbname};charset={$charset}";
    
    try {
        $pdo = new PDO($dsn, $user, $pass, [
            PDO::ATTR_ERRMODE            => PDO::ERRMODE_EXCEPTION,
            PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC,
            PDO::ATTR_EMULATE_PREPARES   => false,
        ]);
        return $pdo;
    } catch (PDOException $e) {
        http_response_code(500);
        echo json_encode(['ok' => false, 'msj' => 'Error de conexión Tesorería: ' . $e->getMessage()]);
        exit;
    }
}
