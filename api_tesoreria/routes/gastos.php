<?php
/**
 * Rutas de Gestión de Gastos e Ingresos Extra - Tesorería API
 */

switch ($accion) {
    case 'registrarGasto':
        if ($adminRol !== 'Admin' && $adminRol !== 'SuperAdmin') {
            http_response_code(403);
            echo json_encode(['ok' => false, 'msj' => 'No autorizado']);
            exit;
        }
        $gasto = $data['gasto'];
        $stmt = $pdo->prepare("INSERT INTO DSI_salon_gastos (descripcion, monto, fecha_gasto, comprobante_url, actividad_id, admin_id, usuario_id) VALUES (?, ?, NOW(), ?, ?, ?, ?)");
        $actId = $gasto['actividadId'] ?? null;
        $compUrl = $gasto['comprobanteUrl'] ?? null;
        if ($stmt->execute([$gasto['descripcion'], $gasto['monto'], $compUrl, $actId, $adminId, $adminId])) {
            $stmtAud = $pdo->prepare("INSERT INTO DSI_salon_auditoria (admin_id, accion, detalle, dispositivo, fecha) VALUES (?, 'Registrar Gasto', ?, 'Flutter API', NOW())");
            $stmtAud->execute([$adminId, "Gasto S/ " . $gasto['monto'] . ": " . $gasto['descripcion']]);
            echo json_encode(['ok' => true]);
        } else {
            echo json_encode(['ok' => false]);
        }
        break;

    case 'eliminarGasto':
        if ($adminRol !== 'SuperAdmin' && $adminRol !== 'Admin') { echo json_encode(['ok' => false]); exit; }
        $gastoId = (int)$data['gastoId'];
        $stmt = $pdo->prepare("DELETE FROM DSI_salon_gastos WHERE id = ?");
        if ($stmt->execute([$gastoId])) {
            $stmtAud = $pdo->prepare("INSERT INTO DSI_salon_auditoria (admin_id, accion, detalle, dispositivo, fecha) VALUES (?, 'Eliminar Gasto', ?, 'Flutter API', NOW())");
            $stmtAud->execute([$adminId, "Anuló el Gasto #$gastoId"]);
            echo json_encode(['ok' => true]);
        } else {
            echo json_encode(['ok' => false]);
        }
        break;

    case 'editarGasto':
        if ($adminRol !== 'SuperAdmin' && $adminRol !== 'Admin') { echo json_encode(['ok' => false]); exit; }
        $gastoId = (int)$data['gastoId'];
        $nuevoMonto = (float)$data['nuevoMonto'];
        $stmt = $pdo->prepare("UPDATE DSI_salon_gastos SET monto = ? WHERE id = ?");
        if ($stmt->execute([$nuevoMonto, $gastoId])) {
            $stmtAud = $pdo->prepare("INSERT INTO DSI_salon_auditoria (admin_id, accion, detalle, dispositivo, fecha) VALUES (?, 'Editar Gasto', ?, 'Flutter API', NOW())");
            $stmtAud->execute([$adminId, "Cambió monto a S/ $nuevoMonto en Gasto #$gastoId"]);
            echo json_encode(['ok' => true]);
        } else {
            echo json_encode(['ok' => false]);
        }
        break;

    case 'eliminarIngresoExtra':
        if ($adminRol !== 'SuperAdmin' && $adminRol !== 'Admin') { echo json_encode(['ok' => false]); exit; }
        $ingresoId = (int)$data['ingresoId'];
        $stmt = $pdo->prepare("DELETE FROM DSI_salon_ingresos_extra WHERE id = ?");
        if ($stmt->execute([$ingresoId])) {
            $stmtAud = $pdo->prepare("INSERT INTO DSI_salon_auditoria (admin_id, accion, detalle, dispositivo, fecha) VALUES (?, 'Eliminar Ingreso Extra', ?, 'Flutter API', NOW())");
            $stmtAud->execute([$adminId, "Anuló el Ingreso Extra #$ingresoId"]);
            echo json_encode(['ok' => true]);
        } else {
            echo json_encode(['ok' => false]);
        }
        break;

    case 'editarIngresoExtra':
        if ($adminRol !== 'SuperAdmin' && $adminRol !== 'Admin') { echo json_encode(['ok' => false]); exit; }
        $ingresoId = (int)$data['ingresoId'];
        $nuevoMonto = (float)$data['nuevoMonto'];
        $stmt = $pdo->prepare("UPDATE DSI_salon_ingresos_extra SET monto = ? WHERE id = ?");
        if ($stmt->execute([$nuevoMonto, $ingresoId])) {
            $stmtAud = $pdo->prepare("INSERT INTO DSI_salon_auditoria (admin_id, accion, detalle, dispositivo, fecha) VALUES (?, 'Editar Ingreso Extra', ?, 'Flutter API', NOW())");
            $stmtAud->execute([$adminId, "Cambió monto a S/ $nuevoMonto en Ingreso Extra #$ingresoId"]);
            echo json_encode(['ok' => true]);
        } else {
            echo json_encode(['ok' => false]);
        }
        break;

    default:
        http_response_code(404);
        echo json_encode(['ok' => false, 'msj' => "Accion desconocida en Gastos: '$accion'"]);
        break;
}
