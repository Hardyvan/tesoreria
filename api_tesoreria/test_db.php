<?php
/**
 * Script de Diagnóstico del Sistema - DSI Tesorería API
 * Permite verificar la conexión a la base de datos y la salud de las tablas.
 */

header('Content-Type: application/json; charset=utf-8');

// Configurar errores para visualización segura en JSON
ini_set('display_errors', 0);
error_reporting(E_ALL);

require_once __DIR__ . '/db.php';

try {
    $pdo = getDBConnection();
    
    // 1. Probar consulta básica
    $stmt = $pdo->query("SELECT 1");
    $dbOk = $stmt ? true : false;
    
    // 2. Consultar conteo de usuarios y el estado del SuperAdmin Principal (ID=1)
    $tablaUsuarios = "DSI_salon_usuarios";
    $userCount = 0;
    $superAdminStatus = "No encontrado";
    
    try {
        $stmtCount = $pdo->query("SELECT COUNT(*) FROM $tablaUsuarios");
        $userCount = (int)$stmtCount->fetchColumn();
        
        $stmtSA = $pdo->prepare("SELECT email, rol, estado FROM $tablaUsuarios WHERE id = 1");
        $stmtSA->execute();
        $sa = $stmtSA->fetch();
        if ($sa) {
            $estadoStr = ((int)$sa['estado'] === 1) ? 'activo' : 'inactivo';
            $superAdminStatus = "Encontrado - Email: " . $sa['email'] . " | Rol: " . $sa['rol'] . " | Estado: " . $estadoStr;
        }
        $tablesStatus = "OK";
    } catch (Exception $exTable) {
        $tablesStatus = "Error: " . $exTable->getMessage();
    }
    
    echo json_encode([
        'ok' => true,
        'msj' => 'Servidor conectado exitosamente con la base de datos de Tesorería.',
        'diagnostico' => [
            'conexion_db' => $dbOk ? 'EXITOSA' : 'FALLIDA',
            'base_datos' => getenv('DB_NAME') ?: ($_ENV['DB_NAME'] ?? 'No configurada'),
            'tabla_usuarios' => $tablesStatus,
            'total_usuarios' => $userCount,
            'superadmin_id_1' => $superAdminStatus,
            'php_version' => PHP_VERSION,
            'server_software' => $_SERVER['SERVER_SOFTWARE'] ?? 'Desconocido'
        ]
    ]);
    
} catch (Exception $e) {
    http_response_code(500);
    echo json_encode([
        'ok' => false,
        'msj' => 'Error de conexión o configuración en la API de Tesorería.',
        'error' => $e->getMessage()
    ]);
}
