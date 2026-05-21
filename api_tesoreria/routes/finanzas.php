<?php
/**
 * Rutas de Finanzas, Reportes y Kardex - Tesorería API
 */

switch ($accion) {
    case 'obtenerResumenGeneral':
        // Abierto a todos los usuarios por política de transparencia (para ver saldo en tiempo real)
        
        // Ingresos y Gastos Globales (Solo confirmados)
        $pagos = (float)$pdo->query("SELECT COALESCE(SUM(monto), 0) FROM DSI_salon_pagos WHERE confirmado = 1")->fetchColumn();
        $extras = (float)$pdo->query("SELECT COALESCE(SUM(monto), 0) FROM DSI_salon_ingresos_extra")->fetchColumn();
        $gastos = (float)$pdo->query("SELECT COALESCE(SUM(monto), 0) FROM DSI_salon_gastos")->fetchColumn();
        $fondoBase = (float)$pdo->query("SELECT COALESCE(SUM(monto), 0) FROM DSI_salon_fondo_base")->fetchColumn();
        
        $stmtFL = $pdo->query("SELECT motivo FROM DSI_salon_fondo_base ORDER BY id DESC LIMIT 1");
        $motivoFondo = $stmtFL->fetch()['motivo'] ?? '';
        
        echo json_encode([
            'ok' => true,
            'resumen' => [
                'totalIngresos' => $pagos + $extras,
                'totalGastos'   => $gastos,
                'fondoBase'     => $fondoBase,
                'fondoBaseMotivo' => $motivoFondo,
                'saldoCaja'     => ($pagos + $extras + $fondoBase) - $gastos
            ]
        ]);
        break;

    case 'obtenerHistorialKardex':
        // Abierto a todos los usuarios por política de transparencia (historial de movimientos)
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
        // Abierto a cualquier usuario autenticado (para llenar la pestaña "Estado" en la app)
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
        // Abierto a todos los usuarios para permitir la descarga del resumen oficial en Excel
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
    case 'obtenerDashboardAnalytics':
        if ($adminRol !== 'Admin' && $adminRol !== 'SuperAdmin') { http_response_code(403); echo json_encode(['ok' => false, 'msj' => 'No autorizado']); exit; }
        
        $anio = $data['anio'] ?? date('Y');
        $mes = $data['mes'] ?? 'TODOS';
        $estadoFiltro = $data['estado'] ?? 'TODOS';

        // 1. KPIs Filtrados
        $sqlPagos = "SELECT COALESCE(SUM(monto), 0) as total FROM DSI_salon_pagos WHERE confirmado = 1 AND YEAR(fecha_pago) = ?";
        $paramsPagos = [$anio];
        
        $mesesMap = [
            'Enero' => 1, 'Febrero' => 2, 'Marzo' => 3, 'Abril' => 4, 'Mayo' => 5, 'Junio' => 6,
            'Julio' => 7, 'Agosto' => 8, 'Septiembre' => 9, 'Octubre' => 10, 'Noviembre' => 11, 'Diciembre' => 12
        ];
        
        if ($mes !== 'TODOS') {
            $mesNum = $mesesMap[$mes] ?? 0;
            if ($mesNum > 0) {
                $sqlPagos .= " AND MONTH(fecha_pago) = ?";
                $paramsPagos[] = $mesNum;
            }
        }
        
        $stmtI = $pdo->prepare($sqlPagos);
        $stmtI->execute($paramsPagos);
        $pagos = (float)$stmtI->fetch()['total'];
        
        $sqlExtra = "SELECT COALESCE(SUM(monto), 0) as total FROM DSI_salon_ingresos_extra WHERE YEAR(fecha_ingreso) = ?";
        $paramsExtra = [$anio];
        if ($mes !== 'TODOS') {
            $mesNum = $mesesMap[$mes] ?? 0;
            if ($mesNum > 0) {
                $sqlExtra .= " AND MONTH(fecha_ingreso) = ?";
                $paramsExtra[] = $mesNum;
            }
        }
        $stmtE = $pdo->prepare($sqlExtra);
        $stmtE->execute($paramsExtra);
        $extras = (float)$stmtE->fetch()['total'];
        $recaudadoTotal = $pagos + $extras;

        $sqlGastos = "SELECT COALESCE(SUM(monto), 0) as total FROM DSI_salon_gastos WHERE YEAR(fecha_gasto) = ?";
        $paramsGastos = [$anio];
        if ($mes !== 'TODOS') {
            $mesNum = $mesesMap[$mes] ?? 0;
            if ($mesNum > 0) {
                $sqlGastos .= " AND MONTH(fecha_gasto) = ?";
                $paramsGastos[] = $mesNum;
            }
        }
        $stmtG = $pdo->prepare($sqlGastos);
        $stmtG->execute($paramsGastos);
        $gastos = (float)$stmtG->fetch()['total'];

        // 2. Cálculo de Deuda y Meta (Optimizando subconsultas)
        $costoTotalActividades = (float)$pdo->query("SELECT COALESCE(SUM(costo), 0) FROM DSI_salon_actividades WHERE estado = 1")->fetchColumn();
        $alumnosActivos = (int)$pdo->query("SELECT COUNT(1) FROM DSI_salon_usuarios WHERE rol IN ('Alumno', 'Admin') AND estado = 'activo' AND id != 1")->fetchColumn();
        
        $metaTotal = $costoTotalActividades * $alumnosActivos;

        $deudaPendiente = max(0, $metaTotal - $pagos);
        $progresoMeta = $metaTotal > 0 ? ($pagos / $metaTotal) : 0;

        // 3. Tendencias Mensuales (Flujo de Caja para el Gráfico de Líneas)
        $tendenciasIngresos = array_fill(0, 12, 0);
        $tendenciasGastos = array_fill(0, 12, 0);

        $sqlTing = "SELECT MONTH(fecha_pago) as mes, SUM(monto) as total FROM DSI_salon_pagos WHERE confirmado = 1 AND YEAR(fecha_pago) = ? GROUP BY MONTH(fecha_pago)";
        $stmtTing = $pdo->prepare($sqlTing);
        $stmtTing->execute([$anio]);
        foreach ($stmtTing->fetchAll() as $r) { $tendenciasIngresos[(int)$r['mes'] - 1] = (float)$r['total']; }

        $sqlTgas = "SELECT MONTH(fecha_gasto) as mes, SUM(monto) as total FROM DSI_salon_gastos WHERE YEAR(fecha_gasto) = ? GROUP BY MONTH(fecha_gasto)";
        $stmtTgas = $pdo->prepare($sqlTgas);
        $stmtTgas->execute([$anio]);
        foreach ($stmtTgas->fetchAll() as $r) { $tendenciasGastos[(int)$r['mes'] - 1] = (float)$r['total']; }

        // 4. Usuarios Detallados para la Tabla (Filtrados por Estado si aplica)
        // OPTIMIZACIÓN: Pasamos el costo base como parámetro en vez de hacer subquery por cada usuario
        $sqlUsuarios = "
            SELECT 
                u.id, 
                u.nombre, 
                u.foto_url,
                u.celular,
                (? + (SELECT COALESCE(SUM(monto_multa), 0) FROM DSI_salon_asistencias WHERE usuario_id = u.id AND estado = 'falto')) as total_a_pagar,
                (SELECT COALESCE(SUM(monto), 0) FROM DSI_salon_pagos WHERE usuario_id = u.id AND confirmado = 1 AND YEAR(fecha_pago) = ?) as total_pagado,
                (SELECT COUNT(1) FROM DSI_salon_asistencias WHERE usuario_id = u.id AND estado = 'falto') as faltas
            FROM DSI_salon_usuarios u
            WHERE u.rol IN ('Alumno', 'Admin') AND u.id != 1 AND u.estado != 'inactivo'
            ORDER BY u.nombre ASC
        ";
        $stmtU = $pdo->prepare($sqlUsuarios);
        $stmtU->execute([$costoTotalActividades, $anio]);
        $resUsuarios = $stmtU->fetchAll();
        
        $usuariosFormateados = [];
        foreach ($resUsuarios as $u) {
            $deuda = (float)$u['total_a_pagar'] - (float)$u['total_pagado'];
            $faltas = (int)$u['faltas'];
            $estado = 'AL DÍA';
            if ($deuda > 0) {
                $estado = $faltas >= 3 ? 'CRÍTICO' : 'MOROSO';
            }
            
            // Aplicar filtro de estado si no es TODOS
            if ($estadoFiltro !== 'TODOS' && $estadoFiltro !== $estado) {
                continue;
            }
            
            $usuariosFormateados[] = [
                'id' => $u['id'],
                'nombre' => $u['nombre'],
                'foto_url' => $u['foto_url'],
                'celular' => $u['celular'],
                'deuda' => max(0, $deuda),
                'faltas' => $faltas,
                'estado' => $estado
            ];
        }

        // 5. Alertas Cruzadas Inteligentes
        $alertas = [];
        
        // Alerta: Actividades con baja recaudación (< 50%)
        // OPTIMIZACIÓN: Usamos el contador de alumnos en memoria ($alumnosActivos)
        $sqlActAlert = "
            SELECT 
                titulo, 
                costo * ? as meta,
                (SELECT COALESCE(SUM(monto), 0) FROM DSI_salon_pagos WHERE actividad_id = a.id AND confirmado = 1) as rec
            FROM DSI_salon_actividades a WHERE estado = 1
        ";
        $stmtAct = $pdo->prepare($sqlActAlert);
        $stmtAct->execute([$alumnosActivos]);
        
        foreach ($stmtAct->fetchAll() as $ac) {
            $metaA = (float)$ac['meta'];
            $recA = (float)$ac['rec'];
            if ($metaA > 0) {
                $porcentaje = ($recA / $metaA);
                if ($porcentaje < 0.5) {
                    $alertas[] = [
                        'tipo' => 'ACTIVIDAD',
                        'titulo' => 'Baja Recaudación',
                        'msj' => "La actividad '{$ac['titulo']}' está por debajo del 50% de su meta.",
                        'nivel' => 'warning'
                    ];
                } else if ($porcentaje >= 0.95) {
                    $alertas[] = [
                        'tipo' => 'ACTIVIDAD',
                        'titulo' => '¡Meta Alcanzada!',
                        'msj' => "La actividad '{$ac['titulo']}' ya superó el 95% de recaudación.",
                        'nivel' => 'success'
                    ];
                }
            }
        }

        // Alerta: Usuarios Críticos (Muchos ya están en el array de usuarios, pero aquí los resaltamos)
        $criticosCount = 0;
        foreach ($usuariosFormateados as $uf) {
            if ($uf['estado'] === 'CRÍTICO') $criticosCount++;
        }
        if ($criticosCount > 0) {
            $alertas[] = [
                'tipo' => 'USUARIO',
                'titulo' => 'Atención Urgente',
                'msj' => "Hay $criticosCount usuarios con deuda y más de 3 faltas acumuladas.",
                'nivel' => 'danger'
            ];
        }

        // Alerta: Balance de Caja Global vs Balance del Periodo
        // 1. Calculamos el saldo real absoluto de la caja (histórico completo)
        $globalPagos = (float)$pdo->query("SELECT COALESCE(SUM(monto), 0) FROM DSI_salon_pagos WHERE confirmado = 1")->fetchColumn();
        $globalExtras = (float)$pdo->query("SELECT COALESCE(SUM(monto), 0) FROM DSI_salon_ingresos_extra")->fetchColumn();
        $globalGastos = (float)$pdo->query("SELECT COALESCE(SUM(monto), 0) FROM DSI_salon_gastos")->fetchColumn();
        $fondoBaseTotal = (float)$pdo->query("SELECT COALESCE(SUM(monto), 0) FROM DSI_salon_fondo_base")->fetchColumn();
        
        $saldoRealGlobal = ($globalPagos + $globalExtras + $fondoBaseTotal) - $globalGastos;
        
        if ($saldoRealGlobal < 0) {
            $alertas[] = [
                'tipo' => 'CAJA',
                'titulo' => 'Déficit Crítico',
                'msj' => "¡Alerta! La caja general está en negativo. Los gastos históricos superan todo el dinero ingresado.",
                'nivel' => 'danger'
            ];
        } else if ($gastos > $recaudadoTotal && $recaudadoTotal > 0) {
            $alertas[] = [
                'tipo' => 'CAJA',
                'titulo' => 'Gasto Elevado (Periodo)',
                'msj' => "En este mes seleccionado, los gastos superaron a los ingresos (se usó dinero de reserva).",
                'nivel' => 'warning'
            ];
        }

        echo json_encode([
            'ok' => true,
            'kpis' => [
                'ingresos' => $recaudadoTotal,
                'gastos' => $gastos,
                'deudaPendiente' => $deudaPendiente,
                'meta' => $metaTotal,
                'progreso' => $progresoMeta
            ],
            'tendencias' => [
                'ingresos' => $tendenciasIngresos,
                'gastos' => $tendenciasGastos
            ],
            'dona' => [
                ['titulo' => 'Recaudado', 'valor' => $pagos],
                ['titulo' => 'Deuda', 'valor' => $deudaPendiente]
            ],
            'usuarios' => $usuariosFormateados,
            'alertas' => $alertas
        ]);
        break;

    default:
        http_response_code(404);
        echo json_encode(['ok' => false, 'msj' => "Accion desconocida en Finanzas: '$accion'"]);
        break;
}
