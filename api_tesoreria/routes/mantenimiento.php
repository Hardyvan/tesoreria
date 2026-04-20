<?php
/**
 * Rutas de Mantenimiento, Auditoría y Sistema - Tesorería API
 */

switch ($accion) {
    case 'ping':
        echo json_encode(['ok' => true, 'msj' => 'Pong! Enlace seguro a base de datos de Tesorería.']);
        break;

    case 'debug_schema':
        $tables = ['DSI_salon_gastos', 'DSI_salon_ingresos_extra', 'DSI_salon_actividades', 'DSI_salon_pagos'];
        $res = [];
        foreach($tables as $t) {
            $stmt = $pdo->query("DESCRIBE $t");
            $res[$t] = $stmt->fetchAll();
        }
        echo json_encode(['ok' => true, 'schema' => $res]);
        break;

    case 'registrarAccion':
        $stmt = $pdo->prepare("INSERT INTO DSI_salon_auditoria (admin_id, accion, detalle, dispositivo, fecha) VALUES (?, ?, ?, ?, NOW())");
        $out = $stmt->execute([(int)$data['adminId'], $data['accionLog'], $data['detalle'], $data['dispositivo']]);
        echo json_encode(['ok' => $out]);
        break;

    case 'obtenerLogsAuditoria':
        $stmt = $pdo->query("
            SELECT a.id, u.nombre as admin_nombre, u.rol, a.accion, a.detalle, a.dispositivo, a.fecha
            FROM DSI_salon_auditoria a
            JOIN DSI_salon_usuarios u ON a.admin_id = u.id
            ORDER BY a.fecha DESC LIMIT 100
        ");
        echo json_encode(['ok' => true, 'datos' => $stmt->fetchAll()]);
        break;

    case 'vaciarAuditoria':
        if ($adminRol !== 'SuperAdmin') {
            http_response_code(403);
            echo json_encode(['ok' => false, 'msj' => 'Solo el SuperAdmin puede realizar esta acción.']);
            exit;
        }
        $pdo->query("DELETE FROM DSI_salon_auditoria");
        $stmtAud = $pdo->prepare("INSERT INTO DSI_salon_auditoria (admin_id, accion, detalle, dispositivo, fecha) VALUES (?, 'Vaciar Auditoría', 'Se eliminó historial', 'Flutter API', NOW())");
        $stmtAud->execute([$adminId]);
        echo json_encode(['ok' => true, 'msj' => 'Historial vaciado correctamente.']);
        break;

    case 'obtenerResumenCaja':
        $fecha = $data['fecha'];
        $stmt = $pdo->prepare("
            SELECT u.nombre as admin_nombre, a.detalle
            FROM DSI_salon_auditoria a
            JOIN DSI_salon_usuarios u ON a.admin_id = u.id
            WHERE a.accion = 'Registrar Pago' AND a.fecha BETWEEN ? AND ?
        ");
        $stmt->execute([$fecha . ' 00:00:00', $fecha . ' 23:59:59']);
        echo json_encode(['ok' => true, 'datos' => $stmt->fetchAll()]);
        break;

    default:
        http_response_code(404);
        echo json_encode(['ok' => false, 'msj' => "Accion desconocida en Mantenimiento: '$accion'"]);
        break;
}
