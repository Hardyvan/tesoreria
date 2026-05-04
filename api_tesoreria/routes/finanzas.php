<?php
/**
 * Rutas de Finanzas, Reportes y Kardex - Tesorería API
 */

switch ($accion) {
    case 'obtenerResumenGeneral':
        if ($adminRol !== 'Admin' && $adminRol !== 'SuperAdmin') { http_response_code(403); echo json_encode(['ok' => false, 'msj' => 'No autorizado']); exit; }
        $stmtI = $pdo->query("SELECT COALESCE(SUM(monto), 0) as total FROM DSI_salon_pagos WHERE confirmado = 1");
        $pagos = (float)$stmtI->fetch()['total'];
        
        $stmtE = $pdo->query("SELECT COALESCE(SUM(monto), 0) as total FROM DSI_salon_ingresos_extra");
        $extras = (float)$stmtE->fetch()['total'];
        
        $stmtG = $pdo->query("SELECT COALESCE(SUM(monto), 0) as total FROM DSI_salon_gastos");
        $gastos = (float)$stmtG->fetch()['total'];
        
        $stmtF = $pdo->query("SELECT COALESCE(SUM(monto), 0) as total FROM DSI_salon_fondo_base");
        $montoFondo = (float)$stmtF->fetch()['total'];
        
        // El motivo ya no es único, así que devolvemos un resumen o el último
        $stmtFL = $pdo->query("SELECT motivo FROM DSI_salon_fondo_base ORDER BY id DESC LIMIT 1");
        $motivoFondo = $stmtFL->fetch()['motivo'] ?? '';
        
        echo json_encode([
            'ok' => true,
            'resumen' => [
                'totalIngresos' => $pagos + $extras,
                'totalGastos'   => $gastos,
                'fondoBase'     => $montoFondo,
                'fondoBaseMotivo' => $motivoFondo,
                'saldoCaja'     => ($pagos + $extras + $montoFondo) - $gastos
            ]
        ]);
        break;

    case 'obtenerHistorialKardex':
        if ($adminRol !== 'Admin' && $adminRol !== 'SuperAdmin') { http_response_code(403); echo json_encode(['ok' => false, 'msj' => 'No autorizado']); exit; }
        $limit = isset($data['limit']) ? (int)$data['limit'] : 20;
        $offset = isset($data['offset']) ? (int)$data['offset'] : 0;
        
        $sql = "
            SELECT 
                'I' AS tipo, p.id AS id_movimiento, CONCAT('Pago: ', u.nombre) AS descripcion, p.monto AS monto, p.fecha_pago AS fecha
            FROM DSI_salon_pagos p
            JOIN DSI_salon_usuarios u ON p.usuario_id = u.id
            WHERE p.confirmado = 1

            UNION ALL

            SELECT 'E' AS tipo, g.id AS id_movimiento, g.descripcion AS descripcion, g.monto AS monto, g.fecha_gasto AS fecha
            FROM DSI_salon_gastos g

            UNION ALL

            SELECT 'X' AS tipo, i.id AS id_movimiento, i.descripcion AS descripcion, i.monto AS monto, i.fecha_ingreso AS fecha
            FROM DSI_salon_ingresos_extra i

            ORDER BY fecha DESC
            LIMIT :limit OFFSET :offset
        ";
        $stmt = $pdo->prepare($sql);
        $stmt->bindValue(':limit', $limit, PDO::PARAM_INT);
        $stmt->bindValue(':offset', $offset, PDO::PARAM_INT);
        $stmt->execute();
        
        $resultados = $stmt->fetchAll();
        foreach ($resultados as &$fila) {
            $fila['monto'] = (float)$fila['monto'];
        }
        echo json_encode(['ok' => true, 'datos' => $resultados]);
        break;

    case 'obtenerReporteDeudores':
        if ($adminRol !== 'Admin' && $adminRol !== 'SuperAdmin') { http_response_code(403); echo json_encode(['ok' => false, 'msj' => 'No autorizado']); exit; }
        $sql = "
            SELECT 
                u.id, 
                u.nombre, 
                u.foto_url,
                u.celular,
                ((SELECT COALESCE(SUM(costo), 0) FROM DSI_salon_actividades) + 
                 (SELECT COALESCE(SUM(monto_multa), 0) FROM DSI_salon_asistencias WHERE usuario_id = u.id AND estado = 'falto')) as total_a_pagar,
                (SELECT COALESCE(SUM(monto), 0) FROM DSI_salon_pagos WHERE usuario_id = u.id AND confirmado = 1) as total_pagado
            FROM DSI_salon_usuarios u
            WHERE u.rol IN ('Alumno', 'Admin') AND u.id != 1
            ORDER BY u.nombre ASC
        ";
        $stmt = $pdo->query($sql);
        $results = $stmt->fetchAll();
        
        foreach ($results as &$fila) {
            $totalPagar = (float)$fila['total_a_pagar'];
            $totalPagado = (float)$fila['total_pagado'];
            $deuda = $totalPagar - $totalPagado;
            
            $fila['deuda'] = $deuda;
            $fila['estado'] = $deuda > 0 ? 'Deudor' : 'Al día';
            $fila['total_a_pagar'] = $totalPagar;
            $fila['total_pagado'] = $totalPagado;
        }
        echo json_encode(['ok' => true, 'datos' => $results]);
        break;

    case 'obtenerMetasActividades':
        $sql = "
            SELECT 
              a.id, 
              a.titulo, 
              a.costo,
              (SELECT COUNT(1) FROM DSI_salon_usuarios WHERE rol IN ('Alumno', 'Admin') AND estado = 1 AND id != 1) as total_alumnos,
              (SELECT COALESCE(SUM(monto), 0) FROM DSI_salon_pagos p WHERE p.actividad_id = a.id AND p.confirmado = 1) as recaudado,
              (SELECT COALESCE(SUM(monto), 0) FROM DSI_salon_gastos g WHERE g.actividad_id = a.id) as gastado
            FROM DSI_salon_actividades a
            WHERE a.estado = 1
            ORDER BY a.fecha_creacion DESC
        ";
        $stmt = $pdo->query($sql);
        $results = $stmt->fetchAll();
        
        $lista = [];
        foreach ($results as $fila) {
            $costo = (float)$fila['costo'];
            $totalAlumnos = (int)$fila['total_alumnos'];
            $recaudado = (float)$fila['recaudado'];
            $gastado = (float)$fila['gastado'];
            
            $metaTotal = $costo * $totalAlumnos;
            $progreso = $metaTotal > 0 ? ($recaudado / $metaTotal) : 0.0;
            if ($progreso > 1.0) $progreso = 1.0;
            
            $lista[] = [
                'id' => $fila['id'],
                'titulo' => $fila['titulo'],
                'meta_total' => $metaTotal,
                'recaudado' => $recaudado,
                'gastado' => $gastado,
                'saldo_disponible' => $recaudado - $gastado,
                'porcentaje_recaudacion' => $progreso,
            ];
        }
        echo json_encode(['ok' => true, 'datos' => $lista]);
        break;

    case 'obtenerReporteAvanzado':
        if ($adminRol !== 'Admin' && $adminRol !== 'SuperAdmin') { http_response_code(403); echo json_encode(['ok' => false, 'msj' => 'No autorizado']); exit; }
        $inicio = $data['inicio'];
        $fin = $data['fin'];
        $inicioFull = $inicio . ' 00:00:00';
        $finFull = $fin . ' 23:59:59';
        
        $stmtI = $pdo->prepare("SELECT COALESCE(SUM(monto), 0) as total FROM DSI_salon_pagos WHERE confirmado = 1 AND fecha_pago BETWEEN ? AND ?");
        $stmtI->execute([$inicioFull, $finFull]);
        $totalIngresos = (float)$stmtI->fetch()['total'];
        
        $stmtG = $pdo->prepare("SELECT COALESCE(SUM(monto), 0) as total FROM DSI_salon_gastos WHERE fecha_gasto BETWEEN ? AND ?");
        $stmtG->execute([$inicioFull, $finFull]);
        $totalGastos = (float)$stmtG->fetch()['total'];
        
        $stmtE = $pdo->prepare("SELECT COALESCE(SUM(monto), 0) as total FROM DSI_salon_ingresos_extra WHERE fecha_ingreso BETWEEN ? AND ?");
        $stmtE->execute([$inicioFull, $finFull]);
        $totalExtra = (float)$stmtE->fetch()['total'];
        
        $totalIngresos += $totalExtra;
        
        $sqlDes = "
            SELECT 
                a.id, a.titulo,
                (SELECT COALESCE(SUM(p.monto), 0) FROM DSI_salon_pagos p WHERE p.actividad_id = a.id AND p.confirmado = 1 AND p.fecha_pago BETWEEN ? AND ?) as ingresos,
                (SELECT COALESCE(SUM(g.monto), 0) FROM DSI_salon_gastos g WHERE g.actividad_id = a.id AND g.fecha_gasto BETWEEN ? AND ?) as gastos
            FROM DSI_salon_actividades a
            ORDER BY a.fecha_creacion DESC
        ";
        $stmtDes = $pdo->prepare($sqlDes);
        $stmtDes->execute([$inicioFull, $finFull, $inicioFull, $finFull]);
        $desgloseRaw = $stmtDes->fetchAll();
        $desglose = [];
        foreach ($desgloseRaw as $d) {
            $ing = (float)$d['ingresos'];
            $gas = (float)$d['gastos'];
            $desglose[] = [ 'titulo' => $d['titulo'], 'ingresos' => $ing, 'gastos' => $gas, 'utilidad' => $ing - $gas ];
        }
        if ($totalExtra > 0) {
            array_unshift($desglose, ['titulo' => 'DONACIONES / EXTRAS', 'ingresos' => $totalExtra, 'gastos' => 0.0, 'utilidad' => $totalExtra]);
        }
        
        $sqlAdm = "
            SELECT COALESCE(u.nombre, 'Sistema/Manual') as admin_nombre, SUM(p.monto) as total
            FROM DSI_salon_pagos p
            LEFT JOIN DSI_salon_usuarios u ON p.admin_id = u.id
            WHERE p.confirmado = 1 AND p.fecha_pago BETWEEN ? AND ?
            GROUP BY u.id, u.nombre
            ORDER BY total DESC
        ";
        $stmtAdm = $pdo->prepare($sqlAdm);
        $stmtAdm->execute([$inicioFull, $finFull]);
        $recaudacionAdmins = $stmtAdm->fetchAll();
        foreach ($recaudacionAdmins as &$ra) { $ra['total'] = (float)$ra['total']; }
        
        echo json_encode([
            'ok' => true,
            'totalIngresos' => $totalIngresos,
            'totalGastos' => $totalGastos,
            'utilidadNeta' => $totalIngresos - $totalGastos,
            'desglose' => $desglose,
            'recaudacionAdmins' => $recaudacionAdmins
        ]);
        break;

    case 'obtenerDatosExcel':
        if ($adminRol !== 'Admin' && $adminRol !== 'SuperAdmin') { http_response_code(403); echo json_encode(['ok' => false, 'msj' => 'No autorizado']); exit; }
        // 1. Deudores
        $sqlDeudores = "
            SELECT 
                u.id, u.nombre, u.rol, u.celular,
                ((SELECT COALESCE(SUM(costo), 0) FROM DSI_salon_actividades) + 
                 (SELECT COALESCE(SUM(monto_multa), 0) FROM DSI_salon_asistencias WHERE usuario_id = u.id AND estado = 'falto')) as total_a_pagar,
                (SELECT COALESCE(SUM(monto), 0) FROM DSI_salon_pagos WHERE usuario_id = u.id AND confirmado = 1) as total_pagado
            FROM DSI_salon_usuarios u
            WHERE u.rol IN ('Alumno', 'Admin') AND u.id != 1 ORDER BY u.nombre
        ";
        $resDeudores = $pdo->query($sqlDeudores)->fetchAll();

        // 2. Pagos
        $sqlPagos = "
            SELECT p.id, u.nombre as alumno, a.titulo as actividad, p.monto, p.monto_multa, p.metodo_pago, p.fecha_pago, admin.nombre as recaudador
            FROM DSI_salon_pagos p
            JOIN DSI_salon_usuarios u ON p.usuario_id = u.id
            JOIN DSI_salon_actividades a ON p.actividad_id = a.id
            LEFT JOIN DSI_salon_usuarios admin ON p.admin_id = admin.id
            WHERE p.confirmado = 1 ORDER BY p.fecha_pago DESC
        ";
        $resPagos = $pdo->query($sqlPagos)->fetchAll();

        // 3. Gastos
        $sqlGastos = "
            SELECT g.id, g.descripcion, a.titulo as actividad, u.nombre as responsable, g.monto, g.fecha_gasto, g.comprobante_url
            FROM DSI_salon_gastos g
            LEFT JOIN DSI_salon_actividades a ON g.actividad_id = a.id
            LEFT JOIN DSI_salon_usuarios u ON g.admin_id = u.id
            ORDER BY g.fecha_gasto DESC
        ";
        $resGastos = $pdo->query($sqlGastos)->fetchAll();

        // 4. Extras
        $sqlExtras = "
            SELECT i.id, i.descripcion, i.monto, i.fecha_ingreso, u.nombre as responsable
            FROM DSI_salon_ingresos_extra i
            LEFT JOIN DSI_salon_usuarios u ON i.admin_id = u.id
            ORDER BY i.fecha_ingreso DESC
        ";
        $resExtras = $pdo->query($sqlExtras)->fetchAll();

        // 4.5 Asistencias
        $sqlAsistencias = "
            SELECT u.nombre as alumno, a.titulo as actividad, asi.estado, asi.monto_multa, a.fecha_creacion
            FROM DSI_salon_asistencias asi
            JOIN DSI_salon_usuarios u ON asi.usuario_id = u.id
            JOIN DSI_salon_actividades a ON asi.actividad_id = a.id
            ORDER BY a.fecha_creacion DESC, u.nombre ASC
        ";
        $resAsistencias = $pdo->query($sqlAsistencias)->fetchAll();
        
        // 5. Fondo Base (Historial completo para el reporte)
        $sqlFondo = "SELECT monto, motivo, fecha_apertura FROM DSI_salon_fondo_base ORDER BY fecha_apertura DESC";
        $resFondo = $pdo->query($sqlFondo)->fetchAll();

        // 6. Resumen General
        $stmtI = $pdo->query("SELECT COALESCE(SUM(monto), 0) as total FROM DSI_salon_pagos WHERE confirmado = 1");
        $pagos = (float)$stmtI->fetch()['total'];
        $stmtE = $pdo->query("SELECT COALESCE(SUM(monto), 0) as total FROM DSI_salon_ingresos_extra");
        $extras = (float)$stmtE->fetch()['total'];
        $stmtG = $pdo->query("SELECT COALESCE(SUM(monto), 0) as total FROM DSI_salon_gastos");
        $gastos = (float)$stmtG->fetch()['total'];
        $stmtF = $pdo->query("SELECT COALESCE(SUM(monto), 0) as total FROM DSI_salon_fondo_base");
        $montoFondo = (float)($stmtF->fetch()['total'] ?? 0);

        echo json_encode([ 
            'ok' => true, 
            'deudores' => $resDeudores, 
            'pagos' => $resPagos, 
            'gastos' => $resGastos, 
            'extras' => $resExtras,
            'asistencias' => $resAsistencias,
            'fondo_base' => $resFondo,
            'resumen' => [
                'totalIngresos' => $pagos + $extras,
                'totalGastos' => $gastos,
                'fondoBase' => $montoFondo,
                'fondoBaseMotivo' => !empty($resFondo) ? ($resFondo[count($resFondo)-1]['motivo'] ?? '') : '',
                'saldoCaja' => ($pagos + $extras + $montoFondo) - $gastos
            ]
        ]);
        break;

    case 'establecerFondoBase':
        if ($adminRol !== 'SuperAdmin' && $adminRol !== 'Admin') { echo json_encode(['ok' => false, 'msj' => 'No autorizado']); exit;}
        $monto = (float)$data['monto'];
        $motivo = $data['motivo'];
        
        $stmt = $pdo->prepare("INSERT INTO DSI_salon_fondo_base (monto, motivo, fecha_apertura) VALUES (?, ?, NOW())");
        if ($stmt->execute([$monto, $motivo])) {
            echo json_encode(['ok' => true]);
        } else {
            $err = $stmt->errorInfo();
            echo json_encode(['ok' => false, 'msj' => 'Error BD: ' . $err[2]]);
        }
        break;

    case 'vaciarFondoBase':
        if ($adminRol !== 'SuperAdmin') { echo json_encode(['ok' => false, 'msj' => 'Solo SuperAdmin']); exit;}
        $pdo->query("DELETE FROM DSI_salon_fondo_base");
        echo json_encode(['ok' => true]);
        break;

    case 'editarFondoBase':
        if ($adminRol !== 'SuperAdmin' && $adminRol !== 'Admin') { echo json_encode(['ok' => false, 'msj' => 'No autorizado']); exit;}
        $nuevoMonto = (float)$data['nuevoMonto'];
        // Para simplificar, si editamos el fondo base, reseteamos y ponemos el nuevo monto total
        $pdo->query("DELETE FROM DSI_salon_fondo_base");
        $stmt = $pdo->prepare("INSERT INTO DSI_salon_fondo_base (monto, motivo, fecha_apertura) VALUES (?, 'Apertura Corregida', NOW())");
        if ($stmt->execute([$nuevoMonto])) {
            echo json_encode(['ok' => true]);
        } else { echo json_encode(['ok' => false]); }
        break;

    default:
        http_response_code(404);
        echo json_encode(['ok' => false, 'msj' => "Accion desconocida en Finanzas: '$accion'"]);
        break;
}
