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
        $stmt = $pdo->prepare("INSERT INTO DSI_salon_actividades (titulo, costo, fecha_creacion, fecha_limite, multa_por_dia, requiere_asistencia, multa_inasistencia) VALUES (?, ?, NOW(), ?, ?, ?, ?)");
        if ($stmt->execute([
            $data['titulo'], 
            (float)$data['costo'], 
            $data['fechaLimite'] ?? null, 
            (float)($data['multaPorDia'] ?? 0),
            isset($data['requiereAsistencia']) && $data['requiereAsistencia'] ? 1 : 0,
            (float)($data['multaInasistencia'] ?? 0)
        ])) {
            $lastId = (int)$pdo->lastInsertId();
            $stmtAud = $pdo->prepare("INSERT INTO DSI_salon_auditoria (admin_id, accion, detalle, dispositivo, fecha) VALUES (?, 'Crear Actividad', ?, '{$dispositivoGlobal}', NOW())");
            $stmtAud->execute([$adminId, "Actividad: {$data['titulo']}, Costo: {$data['costo']}"]);
            
            // Sincronizar de forma completa con Google Sheets en segundo plano
            triggerFullSheetsSync($pdo);

            echo json_encode(['ok' => true, 'id' => $lastId]);
        } else {
            echo json_encode(['ok' => false]);
        }
        break;

    case 'editarActividad':
        if ($adminRol !== 'Admin' && $adminRol !== 'SuperAdmin') { echo json_encode(['ok' => false]); exit; }
        $stmt = $pdo->prepare("UPDATE DSI_salon_actividades SET titulo = ?, costo = ?, fecha_limite = ?, multa_por_dia = ?, requiere_asistencia = ?, multa_inasistencia = ?, updated_at = NOW() WHERE id = ?");
        if ($stmt->execute([
            $data['titulo'], 
            (float)$data['costo'], 
            $data['fechaLimite'] ?? null, 
            (float)($data['multaPorDia'] ?? 0),
            isset($data['requiereAsistencia']) && $data['requiereAsistencia'] ? 1 : 0,
            (float)($data['multaInasistencia'] ?? 0),
            (int)$data['id']
        ])) {
            $stmtAud = $pdo->prepare("INSERT INTO DSI_salon_auditoria (admin_id, accion, detalle, dispositivo, fecha) VALUES (?, 'Editar Actividad', ?, '{$dispositivoGlobal}', NOW())");
            $stmtAud->execute([$adminId, "Actividad #{$data['id']}: {$data['titulo']}"]);
            
            // Sincronizar de forma completa con Google Sheets en segundo plano
            triggerFullSheetsSync($pdo);

            echo json_encode(['ok' => true]);
        } else {
            echo json_encode(['ok' => false]);
        }
        break;

    case 'eliminarActividad':
        if ($adminRol !== 'Admin' && $adminRol !== 'SuperAdmin') { echo json_encode(['ok' => false]); exit; }
        $id = (int)$data['id'];
        $stmtP = $pdo->prepare("SELECT COUNT(*) as total FROM DSI_salon_pagos WHERE actividad_id = ?");
        $stmtP->execute([id]);
        if ($stmtP->fetch()['total'] > 0) {
            echo json_encode(['ok' => false, 'msj' => 'No se puede eliminar porque hay pagos registrados.']);
            exit;
        }
        $stmtTitle = $pdo->prepare("SELECT titulo FROM DSI_salon_actividades WHERE id = ?");
        $stmtTitle->execute([$id]);
        $tituloAct = $stmtTitle->fetchColumn() ?: "ID: $id";

        $stmt = $pdo->prepare("DELETE FROM DSI_salon_actividades WHERE id = ?");
        if ($stmt->execute([$id])) {
            $stmtAud = $pdo->prepare("INSERT INTO DSI_salon_auditoria (admin_id, accion, detalle, dispositivo, fecha) VALUES (?, 'Eliminar Actividad', ?, '{$dispositivoGlobal}', NOW())");
            $stmtAud->execute([$adminId, "Eliminó la actividad: $tituloAct"]);
            
            // Sincronizar de forma completa con Google Sheets en segundo plano
            triggerFullSheetsSync($pdo);

            echo json_encode(['ok' => true]);
        } else {
            echo json_encode(['ok' => false]);
        }
        break;

    case 'obtenerActividadesSimplificadas':
        $stmt = $pdo->query("SELECT id, titulo FROM DSI_salon_actividades ORDER BY fecha_creacion DESC");
        echo json_encode(['ok' => true, 'datos' => $stmt->fetchAll()]);
        break;

    case 'obtenerAsistencia':
        $id = (int)$data['actividadId'];
        $stmt = $pdo->prepare("SELECT u.id as usuario_id, u.nombre, COALESCE(a.estado, 'pendiente') as estado 
            FROM DSI_salon_usuarios u 
            LEFT JOIN DSI_salon_asistencias a ON u.id = a.usuario_id AND a.actividad_id = ? 
            WHERE u.rol IN ('Alumno', 'Admin') AND u.id != 1 
            ORDER BY u.nombre ASC");
        $stmt->execute([$id]);
        echo json_encode(['ok' => true, 'datos' => $stmt->fetchAll()]);
        break;

    case 'guardarAsistenciaLote':
        if ($adminRol !== 'Admin' && $adminRol !== 'SuperAdmin') { echo json_encode(['ok' => false]); exit; }
        $actividadId = (int)$data['actividadId'];
        $asistencias = $data['asistencias'] ?? [];
        
        // Obtener la multa configurada
        $stmtAct = $pdo->prepare("SELECT multa_inasistencia FROM DSI_salon_actividades WHERE id = ?");
        $stmtAct->execute([$actividadId]);
        $act = $stmtAct->fetch();
        $multaBase = (float)($act['multa_inasistencia'] ?? 0);

        try {
            $pdo->beginTransaction();
            foreach ($asistencias as $asist) {
                $uid = (int)$asist['usuarioId'];
                $estado = $asist['estado']; // 'asistio', 'falto', 'permiso'
                $montoMulta = ($estado === 'falto') ? $multaBase : 0;

                $stmt = $pdo->prepare("INSERT INTO DSI_salon_asistencias (actividad_id, usuario_id, estado, monto_multa) 
                    VALUES (?, ?, ?, ?) 
                    ON DUPLICATE KEY UPDATE estado = VALUES(estado), monto_multa = VALUES(monto_multa)");
                $stmt->execute([$actividadId, $uid, $estado, $montoMulta]);
            }
            $pdo->commit();
            $stmtTitle = $pdo->prepare("SELECT titulo FROM DSI_salon_actividades WHERE id = ?");
            $stmtTitle->execute([$actividadId]);
            $tituloAct = $stmtTitle->fetchColumn() ?: "ID: $actividadId";

            $stmtAud = $pdo->prepare("INSERT INTO DSI_salon_auditoria (admin_id, accion, detalle, dispositivo, fecha) VALUES (?, 'Guardar Asistencia', ?, '{$dispositivoGlobal}', NOW())");
            $stmtAud->execute([$adminId, "Guardó asistencia para la actividad: $tituloAct"]);
            echo json_encode(['ok' => true]);
        } catch (Exception $e) {
            $pdo->rollBack();
            echo json_encode(['ok' => false, 'msj' => $e->getMessage()]);
        }
        break;

    default:
        http_response_code(404);
        echo json_encode(['ok' => false, 'msj' => "Accion desconocida en Actividades: '$accion'"]);
        break;
}
