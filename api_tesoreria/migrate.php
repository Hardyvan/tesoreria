<?php
require 'config/database.php';
$pdo = getDBConnection();

try {
    // 1. Añadir columnas a DSI_salon_actividades
    $pdo->exec("ALTER TABLE DSI_salon_actividades ADD COLUMN requiere_asistencia TINYINT(1) DEFAULT 0;");
    $pdo->exec("ALTER TABLE DSI_salon_actividades ADD COLUMN multa_inasistencia DECIMAL(10,2) DEFAULT 0.00;");
    echo "Columnas añadidas a DSI_salon_actividades.\n";
} catch (Exception $e) {
    echo "Info (Actividades): " . $e->getMessage() . "\n";
}

try {
    // 2. Crear tabla DSI_salon_asistencias
    $sql = "
    CREATE TABLE IF NOT EXISTS DSI_salon_asistencias (
        id INT AUTO_INCREMENT PRIMARY KEY,
        actividad_id INT NOT NULL,
        usuario_id INT NOT NULL,
        estado VARCHAR(20) NOT NULL COMMENT 'asistio, falto, permiso',
        monto_multa DECIMAL(10,2) DEFAULT 0.00,
        fecha_registro DATETIME DEFAULT CURRENT_TIMESTAMP,
        updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
        UNIQUE KEY uq_actividad_usuario (actividad_id, usuario_id),
        FOREIGN KEY (actividad_id) REFERENCES DSI_salon_actividades(id) ON DELETE CASCADE,
        FOREIGN KEY (usuario_id) REFERENCES DSI_salon_usuarios(id) ON DELETE CASCADE
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
    ";
    $pdo->exec($sql);
    echo "Tabla DSI_salon_asistencias creada exitosamente.\n";
} catch (Exception $e) {
    echo "Error (Asistencias): " . $e->getMessage() . "\n";
}

echo "Migración completada.\n";
?>
