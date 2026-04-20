<?php
/**
 * Rutas de Gestión de Actividades - Tesorería API
 */

switch ($accion) {
    case 'listarActividades':
        $stmt = $pdo->query("SELECT * FROM DSI_salon_actividades ORDER BY fecha_creacion DESC");
        $res = $stmt->fetchAll();
        foreach ($res as &$r) {
            $r['id'] = (int)$r['id'];
            $r['costo'] = (float)$r['costo'];
            $r['multa_por_dia'] = (float)$r['multa_por_dia'];
            $r['estado'] = (int)$r['estado'];
        }
        echo json_encode(['ok' => true, 'datos' => $res]);
        break;

    case 'crearActividad':
        if ($adminRol !== 'Admin' && $adminRol !== 'SuperAdmin') { echo json_encode(['ok' => false]); exit; }
        $stmt = $pdo->prepare("INSERT INTO DSI_salon_actividades (titulo, costo, fecha_creacion, fecha_limite, multa_por_dia) VALUES (?, ?, NOW(), ?, ?)");
        if ($stmt->execute([$data['titulo'], (float)$data['costo'], $data['fechaLimite'] ?? null, (float)($data['multaPorDia'] ?? 0)])) {
            $lastId = (int)$pdo->lastInsertId();
            $stmtAud = $pdo->prepare("INSERT INTO DSI_salon_auditoria (admin_id, accion, detalle, dispositivo, fecha) VALUES (?, 'Crear Actividad', ?, 'Flutter API', NOW())");
            $stmtAud->execute([$adminId, "Actividad: {$data['titulo']}, Costo: {$data['costo']}"]);
            echo json_encode(['ok' => true, 'id' => $lastId]);
        } else {
            echo json_encode(['ok' => false]);
        }
        break;

    case 'editarActividad':
        if ($adminRol !== 'Admin' && $adminRol !== 'SuperAdmin') { echo json_encode(['ok' => false]); exit; }
        $stmt = $pdo->prepare("UPDATE DSI_salon_actividades SET titulo = ?, costo = ?, fecha_limite = ?, multa_por_dia = ?, updated_at = NOW() WHERE id = ?");
        if ($stmt->execute([$data['titulo'], (float)$data['costo'], $data['fechaLimite'] ?? null, (float)($data['multaPorDia'] ?? 0), (int)$data['id']])) {
            $stmtAud = $pdo->prepare("INSERT INTO DSI_salon_auditoria (admin_id, accion, detalle, dispositivo, fecha) VALUES (?, 'Editar Actividad', ?, 'Flutter API', NOW())");
            $stmtAud->execute([$adminId, "Actividad #{$data['id']}: {$data['titulo']}"]);
            echo json_encode(['ok' => true]);
        } else {
            echo json_encode(['ok' => false]);
        }
        break;

    case 'eliminarActividad':
        if ($adminRol !== 'Admin' && $adminRol !== 'SuperAdmin') { echo json_encode(['ok' => false]); exit; }
        $id = (int)$data['id'];
        $stmtP = $pdo->prepare("SELECT COUNT(*) as total FROM DSI_salon_pagos WHERE actividad_id = ?");
        $stmtP->execute([$id]);
        if ($stmtP->fetch()['total'] > 0) {
            echo json_encode(['ok' => false, 'msj' => 'No se puede eliminar porque hay pagos registrados.']);
            exit;
        }
        $stmt = $pdo->prepare("DELETE FROM DSI_salon_actividades WHERE id = ?");
        if ($stmt->execute([$id])) {
            $stmtAud = $pdo->prepare("INSERT INTO DSI_salon_auditoria (admin_id, accion, detalle, dispositivo, fecha) VALUES (?, 'Eliminar Actividad', ?, 'Flutter API', NOW())");
            $stmtAud->execute([$adminId, "Eliminó Actividad #$id"]);
            echo json_encode(['ok' => true]);
        } else {
            echo json_encode(['ok' => false]);
        }
        break;

    case 'obtenerActividadesSimplificadas':
        $stmt = $pdo->query("SELECT id, titulo FROM DSI_salon_actividades ORDER BY fecha_creacion DESC");
        echo json_encode(['ok' => true, 'datos' => $stmt->fetchAll()]);
        break;

    default:
        http_response_code(404);
        echo json_encode(['ok' => false, 'msj' => "Accion desconocida en Actividades: '$accion'"]);
        break;
}
