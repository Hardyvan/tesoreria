<?php
/**
 * Rutas de Gestión de Pagos y Cobros - Tesorería API
 */

switch ($accion) {
    case 'registrarPago':
        if ($adminRol !== 'Admin' && $adminRol !== 'SuperAdmin') {
            http_response_code(403);
            echo json_encode(['ok' => false, 'msj' => 'No autorizado']);
            exit;
        }

        $pago = $data['pago'];
        $actividadId = (int)$pago['actividadId'];
        $usuarioId = (int)$pago['usuarioId'];
        $monto = (float)$pago['monto'];
        $metodoPago = $pago['metodoPago'] ?? 'Efectivo';
        $comprobante = $pago['comprobanteUrl'] ?? null;
        
        $montoMultaCalculada = 0.0;
        $stmtAct = $pdo->prepare("SELECT fecha_limite, multa_por_dia FROM DSI_salon_actividades WHERE id = ?");
        $stmtAct->execute([$actividadId]);
        $act = $stmtAct->fetch();
        if ($act && $act['fecha_limite'] && $act['multa_por_dia'] > 0) {
            $fechaLimite = new DateTime($act['fecha_limite']);
            $hoy = new DateTime();
            if ($hoy > $fechaLimite) {
                $diasRetraso = $fechaLimite->diff($hoy)->days;
                if ($diasRetraso > 0) {
                    $montoMultaCalculada = $diasRetraso * (float)$act['multa_por_dia'];
                }
            }
        }

        $stmtIns = $pdo->prepare("
            INSERT INTO DSI_salon_pagos (usuario_id, actividad_id, monto, monto_multa, metodo_pago, comprobante_url, admin_id)
            VALUES (?, ?, ?, ?, ?, ?, ?)
        ");
        $exito = $stmtIns->execute([$usuarioId, $actividadId, $monto, $montoMultaCalculada, $metodoPago, $comprobante, $adminId]);
        $pagoIdInsertado = $pdo->lastInsertId();

        if ($exito) {
            $stmtAud = $pdo->prepare("INSERT INTO DSI_salon_auditoria (admin_id, accion, detalle, dispositivo, fecha) VALUES (?, 'Registrar Pago', ?, 'Flutter API', NOW())");
            $stmtAud->execute([$adminId, "Cobro S/ $monto al usuario_id $usuarioId"]);
            echo json_encode(['ok' => true, 'msj' => 'Pago guardado', 'pagoId' => $pagoIdInsertado, 'montoAsignado' => $monto, 'esMultaCero' => ($montoMultaCalculada == 0)]);
        } else {
            echo json_encode(['ok' => false, 'msj' => 'Error al guardar en base de datos.']);
        }
        break;

    case 'editarPago':
        if ($adminRol !== 'Admin' && $adminRol !== 'SuperAdmin') {
            http_response_code(403);
            echo json_encode(['ok' => false, 'msj' => 'No autorizado']);
            exit;
        }
        $pagoId = (int)$data['pagoId'];
        $nuevoMonto = (float)$data['nuevoMonto'];
        $stmt = $pdo->prepare("UPDATE DSI_salon_pagos SET monto = ? WHERE id = ?");
        if ($stmt->execute([$nuevoMonto, $pagoId])) {
            $stmtAud = $pdo->prepare("INSERT INTO DSI_salon_auditoria (admin_id, accion, detalle, dispositivo, fecha) VALUES (?, 'Editar Pago', ?, 'Flutter API', NOW())");
            $stmtAud->execute([$adminId, "Cambió monto a S/ $nuevoMonto en Pago #$pagoId"]);
            echo json_encode(['ok' => true]);
        } else {
            echo json_encode(['ok' => false]);
        }
        break;

    case 'eliminarPago':
        if ($adminRol !== 'Admin' && $adminRol !== 'SuperAdmin') {
             echo json_encode(['ok' => false, 'msj' => 'Seguridad bloqueada']); exit;
        }
        $pagoId = (int)$data['pagoId'];
        $stmtUser = $pdo->prepare("SELECT usuario_id, monto FROM DSI_salon_pagos WHERE id = ?");
        $stmtUser->execute([$pagoId]);
        $pago = $stmtUser->fetch();
        
        $stmt = $pdo->prepare("DELETE FROM DSI_salon_pagos WHERE id = ?");
        if ($stmt->execute([$pagoId])) {
            $stmtAud = $pdo->prepare("INSERT INTO DSI_salon_auditoria (admin_id, accion, detalle, dispositivo, fecha) VALUES (?, 'Eliminar Pago', ?, 'Flutter API', NOW())");
            $stmtAud->execute([$adminId, "Anuló Pago #$pagoId"]);
            echo json_encode(['ok' => true, 'usuarioId' => $pago['usuario_id'], 'monto' => $pago['monto']]);
        } else {
            echo json_encode(['ok' => false]);
        }
        break;

    case 'obtenerDatosFinanzasUsuario':
        $usuarioId = isset($data['usuarioId']) ? (int)$data['usuarioId'] : 0;
        $stmtCosto = $pdo->query("SELECT COALESCE(SUM(costo), 0) as total FROM DSI_salon_actividades");
        $totalCosto = (float)$stmtCosto->fetch()['total'];
        
        $stmtPagado = $pdo->prepare("SELECT COALESCE(SUM(monto), 0) as total FROM DSI_salon_pagos WHERE usuario_id = :uid AND confirmado = 1");
        $stmtPagado->execute([':uid' => $usuarioId]);
        $totalPagado = (float)$stmtPagado->fetch()['total'];
        
        $deudaTotal = $totalCosto - $totalPagado;
        if ($deudaTotal < 0) $deudaTotal = 0;
        
        $stmtHist = $pdo->prepare("
            SELECT p.id, a.titulo as actividad, p.monto, p.fecha_pago 
            FROM DSI_salon_pagos p
            JOIN DSI_salon_actividades a ON p.actividad_id = a.id
            WHERE p.usuario_id = :uid AND p.confirmado = 1
            ORDER BY p.fecha_pago DESC
        ");
        $stmtHist->execute([':uid' => $usuarioId]);
        $historial = $stmtHist->fetchAll();
        foreach ($historial as &$h) { $h['monto'] = (float)$h['monto']; }
        
        echo json_encode([ 'ok' => true, 'deudaTotal' => $deudaTotal, 'totalPagado' => $totalPagado, 'misPagos' => $historial ]);
        break;

    case 'obtenerDetallePagosPorActividad':
        $usuarioId = isset($data['usuarioId']) ? (int)$data['usuarioId'] : 0;
        $stmt = $pdo->prepare("
            SELECT a.id as actividad_id, a.titulo, a.costo, p.id as pago_id, p.monto, p.monto_multa, p.fecha_pago
            FROM DSI_salon_actividades a
            LEFT JOIN DSI_salon_pagos p ON a.id = p.actividad_id AND p.usuario_id = :uid AND p.confirmado = 1
            ORDER BY a.fecha_creacion DESC, p.fecha_pago DESC
        ");
        $stmt->execute([':uid' => $usuarioId]);
        $resultados = $stmt->fetchAll();
        foreach ($resultados as &$r) {
            if ($r['costo'] !== null) $r['costo'] = (float)$r['costo'];
            if ($r['monto'] !== null) $r['monto'] = (float)$r['monto'];
            if ($r['monto_multa'] !== null) $r['monto_multa'] = (float)$r['monto_multa'];
        }
        echo json_encode(['ok' => true, 'datos' => $resultados]);
        break;

    default:
        http_response_code(404);
        echo json_encode(['ok' => false, 'msj' => "Accion desconocida en Pagos: '$accion'"]);
        break;
}
