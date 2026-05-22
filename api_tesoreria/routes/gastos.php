<?php
/**
 * Rutas de Gestión de Gastos e Ingresos Extra - Tesorería API
 */

switch ($accion) {
    case 'registrarIngresoExtra':
        if ($adminRol !== 'Admin' && $adminRol !== 'SuperAdmin') { 
            echo json_encode(['ok' => false, 'msj' => "No autorizado. Tu rol actual es: '$adminRol'"]); 
            exit; 
        }
        $descripcion = $data['descripcion'];
        $monto = $data['monto'];
        $stmt = $pdo->prepare("INSERT INTO DSI_salon_ingresos_extra (descripcion, monto, fecha_ingreso, admin_id) VALUES (?, ?, NOW(), ?)");
        if ($stmt->execute([$descripcion, $monto, $adminId])) {
            $ingresoId = $pdo->lastInsertId();
            $stmtAud = $pdo->prepare("INSERT INTO DSI_salon_auditoria (admin_id, accion, detalle, dispositivo, fecha) VALUES (?, 'Registrar Ingreso Extra', ?, '{$dispositivoGlobal}', NOW())");
            $stmtAud->execute([$adminId, "Ingreso Extra S/ " . $monto . ": " . $descripcion]);
            
            // Webhook Sync
            sincronizarConGoogleSheets('INGRESO_EXTRA', [
                'ingreso_id' => $ingresoId,
                'descripcion' => $descripcion,
                'monto' => $monto,
                'registrado_por' => $adminId,
                'fecha_ingreso' => date('Y-m-d H:i:s')
            ]);
            
            echo json_encode(['ok' => true]);
        } else { 
            $err = $stmt->errorInfo();
            echo json_encode(['ok' => false, 'msj' => 'Error BD: ' . $err[2]]); 
        }
        break;

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
        $descripcion = $gasto['descripcion'];
        $monto = $gasto['monto'];
        if ($stmt->execute([$descripcion, $monto, $compUrl, $actId, $adminId, $adminId])) {
            $gastoId = $pdo->lastInsertId();
            $stmtAud = $pdo->prepare("INSERT INTO DSI_salon_auditoria (admin_id, accion, detalle, dispositivo, fecha) VALUES (?, 'Registrar Gasto', ?, '{$dispositivoGlobal}', NOW())");
            $stmtAud->execute([$adminId, "Gasto S/ " . $monto . ": " . $descripcion]);
            
            // Obtener nombre de la actividad
            $actividadTitulo = null;
            if ($actId) {
                $stmtAct = $pdo->prepare("SELECT titulo FROM DSI_salon_actividades WHERE id = ?");
                $stmtAct->execute([$actId]);
                $actRow = $stmtAct->fetch();
                if ($actRow) {
                    $actividadTitulo = $actRow['titulo'];
                }
            }

            // Webhook Sync
            sincronizarConGoogleSheets('GASTO_NUEVO', [
                'gasto_id' => $gastoId,
                'descripcion' => $descripcion,
                'monto' => $monto,
                'actividad_id' => $actId,
                'actividad_titulo' => $actividadTitulo,
                'comprobante_url' => $compUrl,
                'registrado_por' => $adminId,
                'fecha_gasto' => date('Y-m-d H:i:s')
            ]);

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
            $stmtAud = $pdo->prepare("INSERT INTO DSI_salon_auditoria (admin_id, accion, detalle, dispositivo, fecha) VALUES (?, 'Eliminar Gasto', ?, '{$dispositivoGlobal}', NOW())");
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
            $stmtAud = $pdo->prepare("INSERT INTO DSI_salon_auditoria (admin_id, accion, detalle, dispositivo, fecha) VALUES (?, 'Editar Gasto', ?, '{$dispositivoGlobal}', NOW())");
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
            $stmtAud = $pdo->prepare("INSERT INTO DSI_salon_auditoria (admin_id, accion, detalle, dispositivo, fecha) VALUES (?, 'Eliminar Ingreso Extra', ?, '{$dispositivoGlobal}', NOW())");
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
            $stmtAud = $pdo->prepare("INSERT INTO DSI_salon_auditoria (admin_id, accion, detalle, dispositivo, fecha) VALUES (?, 'Editar Ingreso Extra', ?, '{$dispositivoGlobal}', NOW())");
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
