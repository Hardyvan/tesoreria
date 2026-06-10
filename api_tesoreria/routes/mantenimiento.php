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

    case 'sincronizarTodoGoogleSheets':
        if ($adminRol !== 'Admin' && $adminRol !== 'SuperAdmin') {
            http_response_code(403);
            echo json_encode(['ok' => false, 'msj' => 'No autorizado.']);
            exit;
        }
        
        // 1. Obtener deudores
        $sqlDeudores = "
            SELECT 
                u.id, u.nombre, u.rol, u.celular,
                ((SELECT COALESCE(SUM(act.costo), 0) FROM DSI_salon_actividades act 
                  WHERE act.estado = 1 
                  AND NOT EXISTS (
                      SELECT 1 FROM DSI_salon_exoneraciones ex 
                      WHERE ex.usuario_id = u.id AND ex.actividad_id = act.id
                  )) + 
                 (SELECT COALESCE(SUM(monto_multa), 0) FROM DSI_salon_asistencias WHERE usuario_id = u.id AND estado = 'falto')) as total_a_pagar,
                (SELECT COALESCE(SUM(monto), 0) FROM DSI_salon_pagos WHERE usuario_id = u.id AND confirmado = 1) as total_pagado
            FROM DSI_salon_usuarios u
            WHERE u.rol IN ('Alumno', 'Admin') AND u.id != 1 ORDER BY u.nombre
        ";
        $resDeudores = $pdo->query($sqlDeudores)->fetchAll();

        // 2. Obtener pagos
        $sqlPagos = "
            SELECT p.id, u.nombre as alumno, a.titulo as actividad, p.monto, p.monto_multa, p.metodo_pago, p.fecha_pago, admin.nombre as recaudador
            FROM DSI_salon_pagos p
            JOIN DSI_salon_usuarios u ON p.usuario_id = u.id
            JOIN DSI_salon_actividades a ON p.actividad_id = a.id
            LEFT JOIN DSI_salon_usuarios admin ON p.admin_id = admin.id
            WHERE p.confirmado = 1 ORDER BY p.fecha_pago DESC
        ";
        $resPagos = $pdo->query($sqlPagos)->fetchAll();

        // 3. Obtener gastos
        $sqlGastos = "
            SELECT g.id, g.descripcion, a.titulo as actividad, u.nombre as responsable, g.monto, g.fecha_gasto, g.comprobante_url
            FROM DSI_salon_gastos g
            LEFT JOIN DSI_salon_actividades a ON g.actividad_id = a.id
            LEFT JOIN DSI_salon_usuarios u ON g.admin_id = u.id
            ORDER BY g.fecha_gasto DESC
        ";
        $resGastos = $pdo->query($sqlGastos)->fetchAll();

        // 4. Obtener ingresos extra
        $sqlExtras = "
            SELECT i.id, i.descripcion, i.monto, i.fecha_ingreso, u.nombre as responsable
            FROM DSI_salon_ingresos_extra i
            LEFT JOIN DSI_salon_usuarios u ON i.admin_id = u.id
            ORDER BY i.fecha_ingreso DESC
        ";
        $resExtras = $pdo->query($sqlExtras)->fetchAll();

        // 5. Obtener fondo base
        $sqlFondo = "SELECT monto, motivo, fecha_apertura FROM DSI_salon_fondo_base ORDER BY fecha_apertura DESC";
        $resFondo = $pdo->query($sqlFondo)->fetchAll();

        // 6. Obtener actividades activas
        $sqlActividades = "SELECT id, titulo, costo FROM DSI_salon_actividades WHERE estado = 1 ORDER BY fecha_creacion ASC";
        $resActividades = $pdo->query($sqlActividades)->fetchAll();
        
        // 7. Resumen General
        $stmtI = $pdo->query("SELECT COALESCE(SUM(monto), 0) as total FROM DSI_salon_pagos WHERE confirmado = 1");
        $pagosVal = (float)$stmtI->fetch()['total'];
        $stmtE = $pdo->query("SELECT COALESCE(SUM(monto), 0) as total FROM DSI_salon_ingresos_extra");
        $extrasVal = (float)$stmtE->fetch()['total'];
        $stmtG = $pdo->query("SELECT COALESCE(SUM(monto), 0) as total FROM DSI_salon_gastos");
        $gastosVal = (float)$stmtG->fetch()['total'];
        $stmtF = $pdo->query("SELECT COALESCE(SUM(monto), 0) as total FROM DSI_salon_fondo_base");
        $montoFondo = (float)($stmtF->fetch()['total'] ?? 0);
        
        $payload = [
            'deudores' => $resDeudores,
            'pagos' => $resPagos,
            'gastos' => $resGastos,
            'extras' => $resExtras,
            'fondo_base' => $resFondo,
            'actividades' => $resActividades,
            'resumen' => [
                'totalIngresos' => $pagosVal + $extrasVal,
                'totalGastos' => $gastosVal,
                'fondoBase' => $montoFondo,
                'fondoBaseMotivo' => !empty($resFondo) ? ($resFondo[count($resFondo)-1]['motivo'] ?? '') : '',
                'saldoCaja' => ($pagosVal + $extrasVal + $montoFondo) - $gastosVal
            ]
        ];
        
        // Ejecutar sincronización
        $resSync = sincronizarConGoogleSheets('SINCRONIZAR_TODO', $payload);
        
        if ($resSync) {
            echo json_encode(['ok' => true, 'msj' => 'Sincronización masiva con Google Sheets completada exitosamente.']);
        } else {
            echo json_encode(['ok' => false, 'msj' => 'Error al conectar con el Webhook de Google Sheets.']);
        }
        break;

    case 'obtenerControlVersion':
        // Control de versiones para Google Play Store
        echo json_encode([
            'ok' => true,
            'version_actual' => '1.1.0',
            'version_minima' => '1.1.0',
            'url_play_store' => 'https://play.google.com/store/apps/details?id=pe.insoft.tesoreria.dsi',
            'mensaje_opcional' => 'Nueva versión disponible en Google Play Store con mejoras gráficas 3D y estabilidad.',
            'mensaje_obligatorio' => 'Actualización obligatoria requerida para poder seguir utilizando la aplicación de forma segura.'
        ]);
        break;

    default:
        http_response_code(404);
        echo json_encode(['ok' => false, 'msj' => "Accion desconocida en Mantenimiento: '$accion'"]);
        break;
}
