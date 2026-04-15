<?php
// Conexión segura usando PDO
function getDBConnection() {
    $host = '93.127.137.138';
    $db = 'e20363690948';
    $user = 'Pruebas';
    $pass = 'MyPrueba2026';
    $charset = 'utf8mb4';

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
