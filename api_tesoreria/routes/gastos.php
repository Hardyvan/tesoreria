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
            
            // Obtener nombre del administrador
            $stmtAdmin = $pdo->prepare("SELECT nombre FROM DSI_salon_usuarios WHERE id = ?");
            $stmtAdmin->execute([$adminId]);
            $adminRow = $stmtAdmin->fetch();
            $adminNombre = $adminRow ? $adminRow['nombre'] : "Admin ID: $adminId";

            // Webhook Sync (enviamos ambos formatos de llaves para compatibilidad)
            sincronizarConGoogleSheets('INGRESO_EXTRA', [
                'id' => $ingresoId,
                'ingreso_id' => $ingresoId,
                'descripcion' => $descripcion,
                'monto' => $monto,
                'responsable' => $adminNombre,
                'registrado_por' => $adminId,
                'registrado_por_nombre' => $adminNombre,
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

            // Obtener nombre del administrador responsable
            $stmtAdmin = $pdo->prepare("SELECT nombre FROM DSI_salon_usuarios WHERE id = ?");
            $stmtAdmin->execute([$adminId]);
            $adminRow = $stmtAdmin->fetch();
            $adminNombre = $adminRow ? $adminRow['nombre'] : "Admin ID: $adminId";

            // Webhook Sync (enviamos ambos formatos de llaves para compatibilidad)
            sincronizarConGoogleSheets('GASTO_NUEVO', [
                'id' => $gastoId,
                'gasto_id' => $gastoId,
                'descripcion' => $descripcion,
                'monto' => $monto,
                'actividad_id' => $actId,
                'actividad' => $actividadTitulo ?: "Gasto General",
                'actividad_titulo' => $actividadTitulo,
                'comprobante_url' => $compUrl,
                'responsable' => $adminNombre,
                'registrado_por' => $adminId,
                'registrado_por_nombre' => $adminNombre,
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
        
        // Obtener el gasto antes de eliminarlo para el webhook
        $stmtOld = $pdo->prepare("SELECT monto, descripcion FROM DSI_salon_gastos WHERE id = ?");
        $stmtOld->execute([$gastoId]);
        $gastoOld = $stmtOld->fetch();

        $stmt = $pdo->prepare("DELETE FROM DSI_salon_gastos WHERE id = ?");
        if ($stmt->execute([$gastoId])) {
            $stmtAud = $pdo->prepare("INSERT INTO DSI_salon_auditoria (admin_id, accion, detalle, dispositivo, fecha) VALUES (?, 'Eliminar Gasto', ?, '{$dispositivoGlobal}', NOW())");
            $stmtAud->execute([$adminId, "Anuló el Gasto #$gastoId"]);

            if ($gastoOld) {
                sincronizarConGoogleSheets('GASTO_ELIMINADO', [
                    'id' => $gastoId,
                    'gasto_id' => $gastoId,
                    'monto' => $gastoOld['monto'],
                    'descripcion' => $gastoOld['descripcion']
                ]);
            }

            echo json_encode(['ok' => true]);
        } else {
            echo json_encode(['ok' => false]);
        }
        break;

    case 'editarGasto':
        if ($adminRol !== 'SuperAdmin' && $adminRol !== 'Admin') { echo json_encode(['ok' => false]); exit; }
        $gastoId = (int)$data['gastoId'];
        $nuevoMonto = (float)$data['nuevoMonto'];
        $nuevaDescripcion = isset($data['nuevaDescripcion']) ? $data['nuevaDescripcion'] : null;
        $nuevaActividadId = isset($data['nuevaActividadId']) ? $data['nuevaActividadId'] : null;

        // Si nuevaActividadId es 0 o vacío, guardarlo como NULL (Gasto general)
        if ($nuevaActividadId === 0 || $nuevaActividadId === '' || $nuevaActividadId === '0') {
            $nuevaActividadId = null;
        }

        // Obtener el gasto actual antes de actualizar
        $stmtOld = $pdo->prepare("SELECT descripcion, monto, actividad_id FROM DSI_salon_gastos WHERE id = ?");
        $stmtOld->execute([$gastoId]);
        $gastoOld = $stmtOld->fetch();
        if (!$gastoOld) {
            echo json_encode(['ok' => false, 'msj' => 'Gasto no encontrado']);
            exit;
        }

        $descripcionFinal = ($nuevaDescripcion !== null) ? $nuevaDescripcion : $gastoOld['descripcion'];
        $actividadIdFinal = ($nuevaActividadId !== null) ? $nuevaActividadId : $gastoOld['actividad_id'];

        $stmt = $pdo->prepare("UPDATE DSI_salon_gastos SET monto = ?, descripcion = ?, actividad_id = ? WHERE id = ?");
        if ($stmt->execute([$nuevoMonto, $descripcionFinal, $actividadIdFinal, $gastoId])) {
            $stmtAud = $pdo->prepare("INSERT INTO DSI_salon_auditoria (admin_id, accion, detalle, dispositivo, fecha) VALUES (?, 'Editar Gasto', ?, '{$dispositivoGlobal}', NOW())");
            $stmtAud->execute([$adminId, "Editó Gasto #$gastoId: Monto S/ $nuevoMonto, Desc: '$descripcionFinal'"]);

            // Obtener título de la actividad
            $actividadTitulo = null;
            if ($actividadIdFinal) {
                $stmtAct = $pdo->prepare("SELECT titulo FROM DSI_salon_actividades WHERE id = ?");
                $stmtAct->execute([$actividadIdFinal]);
                $actRow = $stmtAct->fetch();
                if ($actRow) {
                    $actividadTitulo = $actRow['titulo'];
                }
            }

            // Webhook Sync
            sincronizarConGoogleSheets('GASTO_EDITADO', [
                'id' => $gastoId,
                'gasto_id' => $gastoId,
                'descripcion' => $descripcionFinal,
                'monto' => $nuevoMonto,
                'actividad_id' => $actividadIdFinal,
                'actividad' => $actividadTitulo ?: "Gasto General",
                'actividad_titulo' => $actividadTitulo,
                'fecha_gasto' => date('Y-m-d H:i:s')
            ]);

            echo json_encode(['ok' => true]);
        } else {
            echo json_encode(['ok' => false]);
        }
        break;

    case 'eliminarIngresoExtra':
        if ($adminRol !== 'SuperAdmin' && $adminRol !== 'Admin') { echo json_encode(['ok' => false]); exit; }
        $ingresoId = (int)$data['ingresoId'];

        $stmtOld = $pdo->prepare("SELECT descripcion, monto FROM DSI_salon_ingresos_extra WHERE id = ?");
        $stmtOld->execute([$ingresoId]);
        $extraOld = $stmtOld->fetch();

        $stmt = $pdo->prepare("DELETE FROM DSI_salon_ingresos_extra WHERE id = ?");
        if ($stmt->execute([$ingresoId])) {
            $stmtAud = $pdo->prepare("INSERT INTO DSI_salon_auditoria (admin_id, accion, detalle, dispositivo, fecha) VALUES (?, 'Eliminar Ingreso Extra', ?, '{$dispositivoGlobal}', NOW())");
            $stmtAud->execute([$adminId, "Anuló el Ingreso Extra #$ingresoId"]);

            if ($extraOld) {
                sincronizarConGoogleSheets('INGRESO_EXTRA_ELIMINADO', [
                    'id' => $ingresoId,
                    'ingreso_id' => $ingresoId,
                    'descripcion' => $extraOld['descripcion'],
                    'monto' => $extraOld['monto']
                ]);
            }

            echo json_encode(['ok' => true]);
        } else {
            echo json_encode(['ok' => false]);
        }
        break;

    case 'editarIngresoExtra':
        if ($adminRol !== 'SuperAdmin' && $adminRol !== 'Admin') { echo json_encode(['ok' => false]); exit; }
        $ingresoId = (int)$data['ingresoId'];
        $nuevoMonto = (float)$data['nuevoMonto'];
        $nuevaDescripcion = isset($data['nuevaDescripcion']) ? $data['nuevaDescripcion'] : null;

        $stmtOld = $pdo->prepare("SELECT descripcion, monto FROM DSI_salon_ingresos_extra WHERE id = ?");
        $stmtOld->execute([$ingresoId]);
        $extraOld = $stmtOld->fetch();
        if (!$extraOld) {
            echo json_encode(['ok' => false, 'msj' => 'Ingreso extra no encontrado']);
            exit;
        }

        $descripcionFinal = ($nuevaDescripcion !== null) ? $nuevaDescripcion : $extraOld['descripcion'];

        $stmt = $pdo->prepare("UPDATE DSI_salon_ingresos_extra SET monto = ?, descripcion = ? WHERE id = ?");
        if ($stmt->execute([$nuevoMonto, $descripcionFinal, $ingresoId])) {
            $stmtAud = $pdo->prepare("INSERT INTO DSI_salon_auditoria (admin_id, accion, detalle, dispositivo, fecha) VALUES (?, 'Editar Ingreso Extra', ?, '{$dispositivoGlobal}', NOW())");
            $stmtAud->execute([$adminId, "Editó Ingreso Extra #$ingresoId: Monto S/ $nuevoMonto, Desc: '$descripcionFinal'"]);

            // Webhook Sync
            sincronizarConGoogleSheets('INGRESO_EXTRA_EDITADO', [
                'id' => $ingresoId,
                'ingreso_id' => $ingresoId,
                'descripcion' => $descripcionFinal,
                'monto' => $nuevoMonto
            ]);

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
