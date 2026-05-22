<?php
/**
 * Rutas de Mantenimiento, Auditoría y Sistema - Tesorería API
 */

switch ($accion) {
    case 'ping':
        echo json_encode(['ok' => true, 'msj' => 'Pong! Enlace seguro a base de datos de Tesorería.']);
        break;

    case 'debug_schema':
        if ($adminRol !== 'Admin' && $adminRol !== 'SuperAdmin') { http_response_code(403); exit; }
        $tables = ['DSI_salon_gastos', 'DSI_salon_ingresos_extra', 'DSI_salon_actividades', 'DSI_salon_pagos'];
        $res = [];
        foreach($tables as $t) {
            $stmt = $pdo->query("DESCRIBE $t");
            $res[$t] = $stmt->fetchAll();
        }
        echo json_encode(['ok' => true, 'schema' => $res]);
        break;

    case 'verificar_estado_usuarios':
        // SOLO PARA DIAGNÓSTICO TEMPORAL
        $stmtCount = $pdo->query("SELECT COUNT(*) as total FROM DSI_salon_usuarios");
        $total = $stmtCount->fetch()['total'];

        $stmtUltimos = $pdo->query("SELECT id, nombre, email, celular, uid FROM DSI_salon_usuarios ORDER BY id DESC LIMIT 15");
        $ultimos = $stmtUltimos->fetchAll();

        echo json_encode([
            'ok' => true,
            'total_usuarios' => $total,
            'ultimos_registros' => $ultimos
        ]);
        break;

    case 'registrarAccion':
        $stmt = $pdo->prepare("INSERT INTO DSI_salon_auditoria (admin_id, accion, detalle, dispositivo, fecha) VALUES (?, ?, ?, ?, NOW())");
        $out = $stmt->execute([(int)$data['adminId'], $data['accionLog'], $data['detalle'], $data['dispositivo']]);
        echo json_encode(['ok' => $out]);
        break;

    case 'obtenerLogsAuditoria':
        if ($adminRol !== 'Admin' && $adminRol !== 'SuperAdmin') { http_response_code(403); exit; }
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
        $stmtAud = $pdo->prepare("INSERT INTO DSI_salon_auditoria (admin_id, accion, detalle, dispositivo, fecha) VALUES (?, 'Vaciar Auditoría', 'Se eliminó historial', '{$dispositivoGlobal}', NOW())");
        $stmtAud->execute([$adminId]);
        echo json_encode(['ok' => true, 'msj' => 'Historial vaciado correctamente.']);
        break;

    case 'obtenerResumenCaja':
        if ($adminRol !== 'Admin' && $adminRol !== 'SuperAdmin') { http_response_code(403); exit; }
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

    case 'obtenerIdAdminActual':
        $uid = $data['uid'] ?? '';
        if (empty($uid)) {
            http_response_code(400);
            echo json_encode(['ok' => false, 'msj' => 'El uid es obligatorio.']);
            exit;
        }
        
        $stmt = $pdo->prepare("SELECT id FROM DSI_salon_usuarios WHERE uid = ?");
        $stmt->execute([$uid]);
        $row = $stmt->fetch();
        
        if ($row) {
            echo json_encode(['ok' => true, 'id' => (int)$row['id']]);
        } else {
            echo json_encode(['ok' => false, 'msj' => 'Usuario no encontrado.']);
        }
        break;

    default:
        http_response_code(404);
        echo json_encode(['ok' => false, 'msj' => "Accion desconocida en Mantenimiento: '$accion'"]);
        break;
}
