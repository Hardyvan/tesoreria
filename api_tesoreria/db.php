<?php
// Función para cargar lector de entorno oculto
function cargarEnv($ruta) {
    if (!file_exists($ruta)) return false;
    $lineas = file($ruta, FILE_IGNORE_NEW_LINES | FILE_SKIP_EMPTY_LINES);
    foreach ($lineas as $linea) {
        if (strpos(trim($linea), '#') === 0) continue;
        list($nombre, $valor) = explode('=', $linea, 2);
        $nombre = trim($nombre);
        $valor = trim($valor);
        $valor = trim($valor, '"\''); // Quitar comillas si las hay
        putenv(sprintf('%s=%s', $nombre, $valor));
        $_ENV[$nombre] = $valor;
    }
}

// Conexión segura usando PDO
function getDBConnection() {
    // Si no están en ENV globales, cargar el archivo oculto en la misma carpeta
    if (!isset($_ENV['DB_HOST'])) {
        cargarEnv(__DIR__ . '/.env');
    }

    $host = $_ENV['DB_HOST'] ?? '';
    $db = $_ENV['DB_NAME'] ?? '';
    $user = $_ENV['DB_USER'] ?? '';
    $pass = $_ENV['DB_PASS'] ?? '';
    $charset = $_ENV['DB_CHARSET'] ?? 'utf8mb4';

    $dsn = "mysql:host=$host;dbname=$db;charset=$charset";
    $options = [
        PDO::ATTR_ERRMODE            => PDO::ERRMODE_EXCEPTION,
        PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC,
        PDO::ATTR_EMULATE_PREPARES   => false, // Usar consultas preparadas reales (protección Sql injection)
    ];

    try {
        return new PDO($dsn, $user, $pass, $options);
    } catch (\PDOException $e) {
        // En prod, ocultar el $e->getMessage() si expone BD.
        throw new \PDOException("Fallo conexion: " . $e->getMessage(), (int)$e->getCode());
    }
}
?>
