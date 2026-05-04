<?php
header('Content-Type: application/json; charset=utf-8');

// Permisos CORS básicos (Ajustar en producción)
header("Access-Control-Allow-Origin: *");
header("Access-Control-Allow-Methods: POST, GET, OPTIONS");
header("Access-Control-Allow-Headers: Authorization, Content-Type");

// Preflight OPTIONS (Flutter Web/Dio a veces usa options)
if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit;
}

// 1. VERIFICAR LLAVE DE SEGURIDAD (API KEY)
$secret_key = $_ENV['API_SECRET_KEY'] ?? "Insoft2026_SecureKey";
$headers = apache_request_headers();
$auth_header = isset($headers['Authorization']) ? $headers['Authorization'] : (isset($headers['authorization']) ? $headers['authorization'] : '');

if ($auth_header !== "Bearer " . $secret_key) {
    http_response_code(401);
    echo json_encode(['ok' => false, 'msj' => 'Acceso denegado. API Key inválida.']);
    exit;
}

require_once 'db.php';

// 2. LEER DATOS (JSON O FORM-DATA)
$data = json_decode(file_get_contents('php://input'), true);
if (!$data) {
    $data = $_POST;
}

if (!isset($data['accion'])) {
    http_response_code(400);
    echo json_encode(['ok' => false, 'msj' => 'Acción no especificada.']);
    exit;
}

$accion = $data['accion'];

try {
    $pdo = getDBConnection();
    
    // --- PARCHE GLOBAL DE SEGURIDAD (Resuelve fallos de adminRol en el APK) ---
    // Si Flutter manda adminUid o adminId pero adminRol llega vacío o modificado por el APK,
    // garantizamos que el backend recupere el Rol correcto directamente de la BD.
    if (isset($data['adminUid']) && !empty($data['adminUid'])) {
        $stmtRol = $pdo->prepare("SELECT id, rol FROM DSI_salon_usuarios WHERE uid = ?");
        $stmtRol->execute([$data['adminUid']]);
        $rowRol = $stmtRol->fetch();
        if ($rowRol) {
            $data['adminRol'] = $rowRol['rol'];
            $data['adminId'] = $rowRol['id'];
        }
    } elseif (isset($data['adminId']) && (int)$data['adminId'] > 0) {
        $stmtRol = $pdo->prepare("SELECT id, rol FROM DSI_salon_usuarios WHERE id = ?");
        $stmtRol->execute([(int)$data['adminId']]);
        $rowRol = $stmtRol->fetch();
        if ($rowRol) {
            $data['adminRol'] = $rowRol['rol'];
        }
    }
    // --------------------------------------------------------------------------

    // ENRUTADOR CENTRAL
    switch ($accion) {
        case 'ping':
            echo json_encode(['ok' => true, 'msj' => 'Pong! Enlace seguro a base de datos.']);
            break;
            
        case 'debug_schema':
            $tables = ['DSI_salon_gastos', 'DSI_salon_ingresos_extra'];
            $res = [];
            foreach($tables as $t) {
                $stmt = $pdo->query("DESCRIBE $t");
                $res[$t] = $stmt->fetchAll();
            }
            echo json_encode(['ok' => true, 'schema' => $res]);
            exit;
            
        case 'obtenerResumenGeneral':
            $stmtI = $pdo->query("SELECT COALESCE(SUM(monto), 0) as total FROM DSI_salon_pagos WHERE confirmado = 1");
            $pagos = (float)$stmtI->fetch()['total'];
            
            $stmtE = $pdo->query("SELECT COALESCE(SUM(monto), 0) as total FROM DSI_salon_ingresos_extra");
            $extras = (float)$stmtE->fetch()['total'];
            
            $stmtG = $pdo->query("SELECT COALESCE(SUM(monto), 0) as total FROM DSI_salon_gastos");
            $gastos = (float)$stmtG->fetch()['total'];
            
            $stmtF = $pdo->query("SELECT monto, motivo FROM DSI_salon_fondo_base LIMIT 1");
            $fondo = $stmtF->fetch();
            $montoFondo = $fondo ? (float)$fondo['monto'] : 0.0;
            $motivoFondo = $fondo ? $fondo['motivo'] : '';
            
            echo json_encode([
                'ok' => true, 
                'totalIngresos' => $pagos + $extras,
                'totalGastos' => $gastos,
                'fondoBase' => $montoFondo,
                'fondoBaseMotivo' => $motivoFondo,
                'saldoCaja' => ($pagos + $extras + $montoFondo) - $gastos
            ]);
            break;

        case 'obtenerHistorialKardex':
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

                SELECT 'D' AS tipo, i.id AS id_movimiento, i.descripcion AS descripcion, i.monto AS monto, i.fecha_ingreso AS fecha
                FROM DSI_salon_ingresos_extra i

                ORDER BY fecha DESC
                LIMIT :limit OFFSET :offset
            ";
            $stmt = $pdo->prepare($sql);
            $stmt->bindValue(':limit', $limit, PDO::PARAM_INT);
            $stmt->bindValue(':offset', $offset, PDO::PARAM_INT);
            $stmt->execute();
            
            $resultados = $stmt->fetchAll();
            // Convertir montos a double para Flutter
            foreach ($resultados as &$fila) {
                $fila['monto'] = (float)$fila['monto'];
            }
            
            echo json_encode(['ok' => true, 'datos' => $resultados]);
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
            
            foreach ($historial as &$h) {
                $h['monto'] = (float)$h['monto'];
            }
            
            echo json_encode([
                'ok' => true,
                'deudaTotal' => $deudaTotal,
                'totalPagado' => $totalPagado,
                'misPagos' => $historial
            ]);
            break;

        case 'obtenerDetallePagosPorActividad':
            $usuarioId = isset($data['usuarioId']) ? (int)$data['usuarioId'] : 0;
            $stmt = $pdo->prepare("
                SELECT 
                  a.id as actividad_id, a.titulo, a.costo, 
                  p.id as pago_id, p.monto, p.monto_multa, p.fecha_pago, p.metodo_pago
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

        case 'registrarPago':
            $adminRol = isset($data['adminRol']) ? $data['adminRol'] : '';
            $adminUid = isset($data['adminUid']) ? $data['adminUid'] : '';
            $adminId = isset($data['adminId']) ? (int)$data['adminId'] : 0;
            $adminNombre = isset($data['adminNombre']) ? $data['adminNombre'] : 'Admin';
            
            $esAdminSeguro = false;
            if ($adminRol === 'Admin' || $adminRol === 'SuperAdmin') {
                $esAdminSeguro = true;
            } else {
                $stmt = $pdo->prepare("SELECT rol FROM DSI_salon_usuarios WHERE uid = ?");
                $stmt->execute([$adminUid]);
                $userDb = $stmt->fetch();
                if ($userDb && ($userDb['rol'] === 'Admin' || $userDb['rol'] === 'SuperAdmin')) {
                    $esAdminSeguro = true;
                }
            }

            if (!$esAdminSeguro) {
                http_response_code(403);
                echo json_encode(['ok' => false, 'msj' => 'No autorizado']);
                exit;
            }

            // Cálculo automático de multa
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
                // Auditoria silenciosa
                $stmtAud = $pdo->prepare("INSERT INTO DSI_salon_auditoria (admin_id, accion, detalle, dispositivo, fecha) VALUES (?, 'Registrar Pago', ?, '{$dispositivoGlobal}', NOW())");
                $stmtAud->execute([$adminId, "Cobro S/ $monto al usuario_id $usuarioId"]);
                
                // Obtener FCM Token del usuario receptor
                $stmtToken = $pdo->prepare("SELECT fcm_token FROM DSI_salon_usuarios WHERE id = ?");
                $stmtToken->execute([$usuarioId]);
                $tokenRow = $stmtToken->fetch();
                $fcmToken = $tokenRow ? $tokenRow['fcm_token'] : null;
                
                echo json_encode(['ok' => true, 'msj' => 'Pago guardado', 'pagoId' => $pagoIdInsertado, 'montoAsignado' => $monto, 'esMultaCero' => ($montoMultaCalculada == 0), 'fcmTokenUsuario' => $fcmToken]);
            } else {
                echo json_encode(['ok' => false, 'msj' => 'Error al guardar en base de datos.']);
            }
            break;

        case 'editarPago':
            $adminRol = isset($data['adminRol']) ? $data['adminRol'] : '';
            $adminUid = isset($data['adminUid']) ? $data['adminUid'] : '';
            $adminId = isset($data['adminId']) ? (int)$data['adminId'] : 0;
            
            // Verificar esAdmin (simplificado para ahorrar líneas)
            if ($adminRol !== 'Admin' && $adminRol !== 'SuperAdmin') {
                http_response_code(403);
                echo json_encode(['ok' => false, 'msj' => 'No autorizado']);
                exit;
            }

            $pagoId = (int)$data['pagoId'];
            $nuevoMonto = (float)$data['nuevoMonto'];
            
            $stmt = $pdo->prepare("UPDATE DSI_salon_pagos SET monto = ? WHERE id = ?");
            if ($stmt->execute([$nuevoMonto, $pagoId])) {
                $stmtAud = $pdo->prepare("INSERT INTO DSI_salon_auditoria (admin_id, accion, detalle, dispositivo, fecha) VALUES (?, 'Editar Pago', ?, '{$dispositivoGlobal}', NOW())");
                $stmtAud->execute([$adminId, "Cambió monto a S/ $nuevoMonto en Pago #$pagoId"]);
                echo json_encode(['ok' => true]);
            } else {
                echo json_encode(['ok' => false]);
            }
            break;

        case 'eliminarPago':
            $adminRol = isset($data['adminRol']) ? $data['adminRol'] : '';
            $adminUid = isset($data['adminUid']) ? $data['adminUid'] : '';
            $adminId = isset($data['adminId']) ? (int)$data['adminId'] : 0;
            
            // Verificar esAdmin
            if ($adminRol !== 'Admin' && $adminRol !== 'SuperAdmin') {
                 echo json_encode(['ok' => false, 'msj' => 'Seguridad bloqueada']); exit;
            }
            
            $pagoId = (int)$data['pagoId'];
            $stmtUser = $pdo->prepare("SELECT usuario_id, monto FROM DSI_salon_pagos WHERE id = ?");
            $stmtUser->execute([$pagoId]);
            $pago = $stmtUser->fetch();
            
            $stmt = $pdo->prepare("DELETE FROM DSI_salon_pagos WHERE id = ?");
            if ($stmt->execute([$pagoId])) {
                $stmtAud = $pdo->prepare("INSERT INTO DSI_salon_auditoria (admin_id, accion, detalle, dispositivo, fecha) VALUES (?, 'Eliminar Pago', ?, '{$dispositivoGlobal}', NOW())");
                $stmtAud->execute([$adminId, "Anuló Pago #$pagoId"]);
                
                // Retornar datos para que Flutter envíe el Push Notification
                echo json_encode(['ok' => true, 'usuarioId' => $pago['usuario_id'], 'monto' => $pago['monto']]);
            } else {
                echo json_encode(['ok' => false]);
            }
            break;

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
            $adminRol = $data['adminRol'] ?? '';
            if ($adminRol !== 'Admin' && $adminRol !== 'SuperAdmin') { echo json_encode(['ok' => false]); exit; }
            
            $titulo = $data['titulo'];
            $costo = (float)$data['costo'];
            $fechaLimite = $data['fechaLimite'] ?? null;
            $multa = (float)($data['multaPorDia'] ?? 0);
            $adminId = (int)$data['adminId'];
            
            $stmt = $pdo->prepare("INSERT INTO DSI_salon_actividades (titulo, costo, fecha_creacion, fecha_limite, multa_por_dia) VALUES (?, ?, NOW(), ?, ?)");
            if ($stmt->execute([$titulo, $costo, $fechaLimite, $multa])) {
                $lastId = (int)$pdo->lastInsertId();
                $stmtAud = $pdo->prepare("INSERT INTO DSI_salon_auditoria (admin_id, accion, detalle, dispositivo, fecha) VALUES (?, 'Crear Actividad', ?, '{$dispositivoGlobal}', NOW())");
                $stmtAud->execute([$adminId, "Actividad: $titulo, Costo: $costo"]);
                echo json_encode(['ok' => true, 'id' => $lastId]);
            } else {
                echo json_encode(['ok' => false]);
            }
            break;

        case 'editarActividad':
            $adminRol = $data['adminRol'] ?? '';
            if ($adminRol !== 'Admin' && $adminRol !== 'SuperAdmin') { echo json_encode(['ok' => false]); exit; }
            
            $id = (int)$data['id'];
            $titulo = $data['titulo'];
            $costo = (float)$data['costo'];
            $fechaLimite = $data['fechaLimite'] ?? null;
            $multa = (float)($data['multaPorDia'] ?? 0);
            $adminId = (int)$data['adminId'];
            
            $stmt = $pdo->prepare("UPDATE DSI_salon_actividades SET titulo = ?, costo = ?, fecha_limite = ?, multa_por_dia = ?, updated_at = NOW() WHERE id = ?");
            if ($stmt->execute([$titulo, $costo, $fechaLimite, $multa, $id])) {
                $stmtAud = $pdo->prepare("INSERT INTO DSI_salon_auditoria (admin_id, accion, detalle, dispositivo, fecha) VALUES (?, 'Editar Actividad', ?, '{$dispositivoGlobal}', NOW())");
                $stmtAud->execute([$adminId, "Actividad #$id: $titulo"]);
                echo json_encode(['ok' => true]);
            } else {
                echo json_encode(['ok' => false]);
            }
            break;

        case 'eliminarActividad':
            $adminRol = $data['adminRol'] ?? '';
            if ($adminRol !== 'Admin' && $adminRol !== 'SuperAdmin') { echo json_encode(['ok' => false]); exit; }
            
            $id = (int)$data['id'];
            $adminId = (int)$data['adminId'];
            
            // Verificar si hay pagos
            $stmtP = $pdo->prepare("SELECT COUNT(*) as total FROM DSI_salon_pagos WHERE actividad_id = ?");
            $stmtP->execute([$id]);
            if ($stmtP->fetch()['total'] > 0) {
                echo json_encode(['ok' => false, 'msj' => 'No se puede eliminar porque hay pagos registrados.']);
                exit;
            }
            
            $stmt = $pdo->prepare("DELETE FROM DSI_salon_actividades WHERE id = ?");
            if ($stmt->execute([$id])) {
                $stmtAud = $pdo->prepare("INSERT INTO DSI_salon_auditoria (admin_id, accion, detalle, dispositivo, fecha) VALUES (?, 'Eliminar Actividad', ?, '{$dispositivoGlobal}', NOW())");
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

        case 'registrarGasto':
            $adminRol = isset($data['adminRol']) ? $data['adminRol'] : '';
            $adminUid = isset($data['adminUid']) ? $data['adminUid'] : '';
            $adminId = isset($data['adminId']) ? (int)$data['adminId'] : 0;
            
            if ($adminRol !== 'Admin' && $adminRol !== 'SuperAdmin') {
                http_response_code(403);
                echo json_encode(['ok' => false, 'msj' => 'No autorizado']);
                exit;
            }

            $gasto = $data['gasto'];
            $stmt = $pdo->prepare("INSERT INTO DSI_salon_gastos (descripcion, monto, fecha_gasto, comprobante_url, actividad_id, admin_id, usuario_id) VALUES (?, ?, NOW(), ?, ?, ?, ?)");
            $actId = isset($gasto['actividadId']) ? $gasto['actividadId'] : null;
            $compUrl = isset($gasto['comprobanteUrl']) ? $gasto['comprobanteUrl'] : null;
            if ($stmt->execute([$gasto['descripcion'], $gasto['monto'], $compUrl, $actId, $adminId, $adminId])) {
                $stmtAud = $pdo->prepare("INSERT INTO DSI_salon_auditoria (admin_id, accion, detalle, dispositivo, fecha) VALUES (?, 'Registrar Gasto', ?, '{$dispositivoGlobal}', NOW())");
                $stmtAud->execute([$adminId, "Gasto S/ " . $gasto['monto'] . ": " . $gasto['descripcion']]);
                echo json_encode(['ok' => true]);
            } else {
                echo json_encode(['ok' => false]);
            }
            break;

        case 'eliminarGasto':
            $adminRol = isset($data['adminRol']) ? $data['adminRol'] : '';
            $adminId = isset($data['adminId']) ? (int)$data['adminId'] : 0;
            if ($adminRol !== 'SuperAdmin' && $adminRol !== 'Admin') {
                 echo json_encode(['ok' => false]); exit;
            }
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
            $adminRol = isset($data['adminRol']) ? $data['adminRol'] : '';
            $adminId = isset($data['adminId']) ? (int)$data['adminId'] : 0;
            if ($adminRol !== 'SuperAdmin' && $adminRol !== 'Admin') {
                 echo json_encode(['ok' => false]); exit;
            }
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
            $adminRol = isset($data['adminRol']) ? $data['adminRol'] : '';
            $adminId = isset($data['adminId']) ? (int)$data['adminId'] : 0;
            if ($adminRol !== 'SuperAdmin' && $adminRol !== 'Admin') {
                 echo json_encode(['ok' => false]); exit;
            }
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
            $adminRol = isset($data['adminRol']) ? $data['adminRol'] : '';
            $adminId = isset($data['adminId']) ? (int)$data['adminId'] : 0;
            if ($adminRol !== 'SuperAdmin' && $adminRol !== 'Admin') {
                 echo json_encode(['ok' => false]); exit;
            }
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

        case 'establecerFondoBase':
            $adminRol = isset($data['adminRol']) ? $data['adminRol'] : '';
            $adminId = isset($data['adminId']) ? (int)$data['adminId'] : 0;
            if ($adminRol !== 'SuperAdmin') { echo json_encode(['ok' => false]); exit;}
            
            $monto = (float)$data['monto'];
            $motivo = $data['motivo'];
            $pdo->query("DELETE FROM DSI_salon_fondo_base");
            $stmt = $pdo->prepare("INSERT INTO DSI_salon_fondo_base (monto, motivo, fecha_apertura) VALUES (?, ?, NOW())");
            $stmt->execute([$monto, $motivo]);
            echo json_encode(['ok' => true]);
            break;
            
        case 'obtenerReporteDeudores':
            // Asumimos: TODOS deben pagar TODAS las actividades
            // Excluimos al SuperAdmin con id = 1
            $sql = "
                SELECT 
                    u.id, 
                    u.nombre, 
                    u.foto_url,
                    (SELECT COALESCE(SUM(costo), 0) FROM DSI_salon_actividades) as total_a_pagar,
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
                  (SELECT COUNT(1) FROM DSI_salon_usuarios WHERE rol IN ('Alumno', 'Admin') AND estado = 1 AND u.id != 1) as total_alumnos,
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
            $inicio = $data['inicio']; // YYYY-MM-DD
            $fin = $data['fin'];       // YYYY-MM-DD
            $inicioFull = $inicio . ' 00:00:00';
            $finFull = $fin . ' 23:59:59';
            
            // A. Totales
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
            
            // B. Desglose Actividades
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
                $desglose[] = [
                    'titulo' => $d['titulo'],
                    'ingresos' => $ing,
                    'gastos' => $gas,
                    'utilidad' => $ing - $gas
                ];
            }
            if ($totalExtra > 0) {
                array_unshift($desglose, ['titulo' => 'DONACIONES / EXTRAS', 'ingresos' => $totalExtra, 'gastos' => 0.0, 'utilidad' => $totalExtra]);
            }
            
            // C. Admins
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

        case 'verificarCelularEnUso':
            $celular = $data['celular'];
            $excluirId = isset($data['excluirId']) ? (int)$data['excluirId'] : null;
            $sql = "SELECT id FROM DSI_salon_usuarios WHERE celular = ?";
            if ($excluirId !== null) $sql .= " AND id != $excluirId";
            $stmt = $pdo->prepare($sql);
            $stmt->execute([$celular]);
            echo json_encode(['ok' => true, 'enUso' => $stmt->fetch() ? true : false]);
            break;

        case 'sincronizarUsuarioBD':
            $uid = $data['uid'];
            $email = $data['email'] ?? '';
            $nombre = $data['nombre'] ?? '';
            $fotoGoogle = $data['fotoGoogle'] ?? '';
            
            // Búsqueda por UID
            $stmt = $pdo->prepare("SELECT * FROM DSI_salon_usuarios WHERE uid = ?");
            $stmt->execute([$uid]);
            $user = $stmt->fetch();
            
            if (!$user && $email) {
                // Fallback email
                $stmt = $pdo->prepare("SELECT * FROM DSI_salon_usuarios WHERE email = ?");
                $stmt->execute([$email]);
                $user = $stmt->fetch();
                if ($user) {
                    $pdo->prepare("UPDATE DSI_salon_usuarios SET uid = ? WHERE id = ?")->execute([$uid, $user['id']]);
                    if ($fotoGoogle) {
                        $pdo->prepare("UPDATE DSI_salon_usuarios SET foto_url = ? WHERE id = ? AND (foto_url IS NULL OR foto_url = '')")->execute([$fotoGoogle, $user['id']]);
                    }
                }
            }
            
            if ($user) {
                // Existe
                if ($user['estado'] === 'inactivo') {
                    echo json_encode(['ok' => true, 'status' => 'bloqueado']);
                    exit;
                }
                
                // Root check
                $correosRoot = ['gurenge.leveling@gmail.com', 'hao_asakura@gmail.com'];
                $rol = $user['rol'];
                if (in_array(strtolower($email), $correosRoot) && $rol !== 'SuperAdmin') {
                    $rol = 'SuperAdmin';
                    $pdo->prepare("UPDATE DSI_salon_usuarios SET rol = 'SuperAdmin' WHERE id = ?")->execute([$user['id']]);
                }
                
                echo json_encode([
                    'ok' => true, 
                    'status' => 'OK', 
                    'usuario' => [
                        'id' => (int)$user['id'],
                        'uid' => $uid,
                        'nombre' => $user['nombre'],
                        'celular' => $user['celular'],
                        'email' => $user['email'],
                        'foto_url' => $user['foto_url'],
                        'rol' => $rol,
                        'direccion' => $user['direccion'],
                        'edad' => (int)$user['edad'],
                        'sexo' => $user['sexo'],
                        'estado' => $user['estado']
                    ]
                ]);
            } else {
                // Nuevo
                $correosRoot = ['gurenge.leveling@gmail.com', 'hao_asakura@gmail.com'];
                $rolAsignado = in_array(strtolower($email), $correosRoot) ? 'SuperAdmin' : 'Alumno';
                
                $stmt = $pdo->prepare("INSERT INTO DSI_salon_usuarios (uid, nombre, email, foto_url, rol, fecha_registro) VALUES (?, ?, ?, ?, ?, NOW())");
                $stmt->execute([$uid, $nombre, $email, $fotoGoogle, $rolAsignado]);
                $lastId = (int)$pdo->lastInsertId();
                
                echo json_encode([
                    'ok' => true,
                    'status' => 'UsuarioNuevo',
                    'usuario' => [
                        'id' => $lastId,
                        'uid' => $uid,
                        'nombre' => $nombre,
                        'email' => $email,
                        'foto_url' => $fotoGoogle,
                        'rol' => $rolAsignado,
                        'celular' => ''
                    ]
                ]);
            }
            break;

        case 'guardarPerfilCompletado':
            $id = (int)($data['id'] ?? 0);
            $uid = $data['uid'];
            $email = $data['email'];
            $nombre = $data['nombre'];
            $celular = $data['celular'];
            $direccion = $data['direccion'];
            $edad = (int)$data['edad'];
            $sexo = $data['sexo'];
            $fotoUrl = $data['fotoUrl'] ?? '';
            
            if ($id === 0) {
                // Ver si ya existe por UID (seguridad)
                $stmt = $pdo->prepare("SELECT id FROM DSI_salon_usuarios WHERE uid = ?");
                $stmt->execute([$uid]);
                $exist = $stmt->fetch();
                if ($exist) {
                    $id = (int)$exist['id'];
                } else {
                    $correosRoot = ['gurenge.leveling@gmail.com', 'hao_asakura@gmail.com'];
                    $rolAsignado = in_array(strtolower($email), $correosRoot) ? 'SuperAdmin' : 'Alumno';
                    $stmt = $pdo->prepare("INSERT INTO DSI_salon_usuarios (uid, nombre, email, celular, direccion, edad, sexo, foto_url, rol, fecha_registro) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, NOW())");
                    $stmt->execute([$uid, $nombre, $email, $celular, $direccion, $edad, $sexo, $fotoUrl, $rolAsignado]);
                    $id = (int)$pdo->lastInsertId();
                }
            }
            
            if ($id > 0) {
                $stmt = $pdo->prepare("UPDATE DSI_salon_usuarios SET nombre = ?, celular = ?, direccion = ?, edad = ?, sexo = ? WHERE id = ?");
                $stmt->execute([$nombre, $celular, $direccion, $edad, $sexo, $id]);
            }
            
            echo json_encode(['ok' => true, 'id' => $id]);
            break;

        case 'actualizarElementoUsuario':
            $id = (int)$data['id'];
            $celular = $data['celular'] ?? null;
            $fotoUrl = $data['fotoUrl'] ?? null;
            $fcmToken = $data['fcmToken'] ?? null;
            
            if ($celular !== null) {
                $pdo->prepare("UPDATE DSI_salon_usuarios SET celular = ? WHERE id = ?")->execute([$celular, $id]);
            }
            if ($fotoUrl !== null) {
                $pdo->prepare("UPDATE DSI_salon_usuarios SET foto_url = ? WHERE id = ?")->execute([$fotoUrl, $id]);
            }
            if ($fcmToken !== null) {
                $pdo->prepare("UPDATE DSI_salon_usuarios SET fcm_token = ? WHERE id = ?")->execute([$fcmToken, $id]);
            }
            echo json_encode(['ok' => true]);
            break;

        case 'obtenerIdAdminActual':
            $uid = $data['uid'];
            $stmt = $pdo->prepare("SELECT id FROM DSI_salon_usuarios WHERE uid = ?");
            $stmt->execute([$uid]);
            $res = $stmt->fetch();
            echo json_encode(['ok' => true, 'id' => $res ? (int)$res['id'] : -1]);
            break;

        case 'registrarAlumnoOffline':
            $nombre = $data['nombre'];
            $uid = 'offline_' . time();
            $stmt = $pdo->prepare("INSERT INTO DSI_salon_usuarios (uid, nombre, email, celular, foto_url, rol) VALUES (?, ?, 'offline@tesoreria.local', '000000000', '', 'Alumno')");
            $stmt->execute([$uid, $nombre]);
            echo json_encode(['ok' => true]);
            break;

        case 'registrarAccion':
            $adminId = (int)$data['adminId'];
            $accionLog = $data['accionLog'];
            $detalle = $data['detalle'];
            $dispositivo = $data['dispositivo'];
            
            $stmt = $pdo->prepare("INSERT INTO DSI_salon_auditoria (admin_id, accion, detalle, dispositivo, fecha) VALUES (?, ?, ?, ?, NOW())");
            $out = $stmt->execute([$adminId, $accionLog, $detalle, $dispositivo]);
            echo json_encode(['ok' => $out]);
            break;

        case 'obtenerLogsAuditoria':
            $stmt = $pdo->query("
                SELECT a.id, u.nombre as admin_nombre, u.rol, a.accion, a.detalle, a.dispositivo, a.fecha
                FROM DSI_salon_auditoria a
                JOIN DSI_salon_usuarios u ON a.admin_id = u.id
                ORDER BY a.fecha DESC
                LIMIT 100
            ");
            echo json_encode(['ok' => true, 'datos' => $stmt->fetchAll()]);
            break;

        case 'obtenerResumenCaja':
            $fecha = $data['fecha']; // Formato YYYY-MM-DD
            $inicio = $fecha . ' 00:00:00';
            $fin = $fecha . ' 23:59:59';
            
            $stmt = $pdo->prepare("
                SELECT u.nombre as admin_nombre, a.detalle
                FROM DSI_salon_auditoria a
                JOIN DSI_salon_usuarios u ON a.admin_id = u.id
                WHERE a.accion = 'Registrar Pago' 
                  AND a.fecha BETWEEN ? AND ?
            ");
            $stmt->execute([$inicio, $fin]);
            echo json_encode(['ok' => true, 'datos' => $stmt->fetchAll()]);
            break;

        case 'vaciarAuditoria':
            $adminRol = isset($data['adminRol']) ? $data['adminRol'] : '';
            if ($adminRol !== 'SuperAdmin') {
                http_response_code(403);
                echo json_encode(['ok' => false, 'msj' => 'Solo el SuperAdmin puede realizar esta acción.']);
                exit;
            }
            
            // Vaciar tabla
            $pdo->query("DELETE FROM DSI_salon_auditoria");
            
            // Registrar acción de vaciado (opcional, pero buena práctica)
            $adminId = (int)$data['adminId'];
            $stmtAud = $pdo->prepare("INSERT INTO DSI_salon_auditoria (admin_id, accion, detalle, dispositivo, fecha) VALUES (?, 'Vaciar Auditoría', 'Se eliminó todo el historial de acciones', '{$dispositivoGlobal}', NOW())");
            $stmtAud->execute([$adminId]);
            
            echo json_encode(['ok' => true, 'msj' => 'Historial de auditoría vaciado correctamente.']);
            break;

        case 'obtenerDatosExcel':
            $sqlDeudores = "
                SELECT 
                    u.id, 
                    u.nombre, 
                    u.rol,
                    u.celular,
                    (SELECT COALESCE(SUM(costo), 0) FROM DSI_salon_actividades) as total_a_pagar,
                    (SELECT COALESCE(SUM(monto), 0) FROM DSI_salon_pagos WHERE usuario_id = u.id AND confirmado = 1) as total_pagado
                FROM DSI_salon_usuarios u
                WHERE u.rol IN ('Alumno', 'Admin') AND u.id != 1
                ORDER BY u.nombre
            ";
            $resDeudores = $pdo->query($sqlDeudores)->fetchAll();

            $sqlPagos = "
                SELECT 
                  p.id, u.nombre as alumno, a.titulo as actividad, p.monto, p.monto_multa, p.metodo_pago, p.fecha_pago,
                  admin.nombre as recaudador
                FROM DSI_salon_pagos p
                JOIN DSI_salon_usuarios u ON p.usuario_id = u.id
                JOIN DSI_salon_actividades a ON p.actividad_id = a.id
                LEFT JOIN DSI_salon_usuarios admin ON p.admin_id = admin.id
                WHERE p.confirmado = 1
                ORDER BY p.fecha_pago DESC
            ";
            $resPagos = $pdo->query($sqlPagos)->fetchAll();

            $sqlGastos = "
                SELECT 
                  g.id, g.descripcion, a.titulo as actividad, u.nombre as responsable, g.monto, g.fecha_gasto, g.comprobante_url
                FROM DSI_salon_gastos g
                LEFT JOIN DSI_salon_actividades a ON g.actividad_id = a.id
                LEFT JOIN DSI_salon_usuarios u ON g.admin_id = u.id
                ORDER BY g.fecha_gasto DESC
            ";
            $resGastos = $pdo->query($sqlGastos)->fetchAll();

            $sqlExtras = "
                SELECT 
                  i.id, i.descripcion, i.monto, i.fecha_ingreso, u.nombre as responsable
                FROM DSI_salon_ingresos_extra i
                LEFT JOIN DSI_salon_usuarios u ON i.admin_id = u.id
                ORDER BY i.fecha_ingreso DESC
            ";
            $resExtras = $pdo->query($sqlExtras)->fetchAll();

            echo json_encode([
                'ok' => true, 
                'deudores' => $resDeudores, 
                'pagos' => $resPagos, 
                'gastos' => $resGastos, 
                'extras' => $resExtras
            ]);
            break;

        case 'listarUsuariosCompleto':
            $stmt = $pdo->query("SELECT id, nombre, celular, email, foto_url, rol, direccion, edad, sexo, estado, updated_at FROM DSI_salon_usuarios");
            echo json_encode(['ok' => true, 'datos' => $stmt->fetchAll()]);
            break;

        case 'cambiarRolUsuario':
            $adminRol = $data['adminRol'] ?? '';
            $adminId = (int)($data['adminId'] ?? 0);
            if ($adminRol !== 'SuperAdmin' && $adminRol !== 'Admin') { echo json_encode(['ok' => false]); exit; }
            $targetId = (int)$data['targetId'];
            $nuevoRol = $data['nuevoRol'];
            $stmt = $pdo->prepare("UPDATE DSI_salon_usuarios SET rol = ? WHERE id = ?");
            if ($stmt->execute([$nuevoRol, $targetId])) {
                $stmtAud = $pdo->prepare("INSERT INTO DSI_salon_auditoria (admin_id, accion, detalle, dispositivo, fecha) VALUES (?, 'Cambiar Rol', ?, '{$dispositivoGlobal}', NOW())");
                $stmtAud->execute([$adminId, "Usuario ID: $targetId - Nuevo Rol: $nuevoRol"]);
                echo json_encode(['ok' => true]);
            } else {
                echo json_encode(['ok' => false]);
            }
            break;

        case 'cambiarEstadoUsuario':
            $adminRol = $data['adminRol'] ?? '';
            $adminId = (int)($data['adminId'] ?? 0);
            if ($adminRol !== 'SuperAdmin' && $adminRol !== 'Admin') { echo json_encode(['ok' => false]); exit; }
            $targetId = (int)$data['targetId'];
            $nuevoEstado = $data['nuevoEstado'];
            $estadoDb = ($nuevoEstado === 'activo') ? 1 : 0; 
            $stmt = $pdo->prepare("UPDATE DSI_salon_usuarios SET estado = ? WHERE id = ?");
            if ($stmt->execute([$estadoDb, $targetId])) {
                $stmtAud = $pdo->prepare("INSERT INTO DSI_salon_auditoria (admin_id, accion, detalle, dispositivo, fecha) VALUES (?, 'Cambiar Estado Usuario', ?, '{$dispositivoGlobal}', NOW())");
                $stmtAud->execute([$adminId, "Usuario ID: $targetId - Nuevo Estado: $nuevoEstado"]);
                echo json_encode(['ok' => true]);
            } else {
                echo json_encode(['ok' => false]);
            }
            break;

        case 'eliminarUsuario':
            $adminRol = $data['adminRol'] ?? '';
            $adminId = (int)($data['adminId'] ?? 0);
            if ($adminRol !== 'SuperAdmin' && $adminRol !== 'Admin') { echo json_encode(['ok' => false]); exit; }
            $targetId = (int)$data['targetId'];
            $stmt = $pdo->prepare("DELETE FROM DSI_salon_usuarios WHERE id = ?");
            if ($stmt->execute([$targetId])) {
                $stmtAud = $pdo->prepare("INSERT INTO DSI_salon_auditoria (admin_id, accion, detalle, dispositivo, fecha) VALUES (?, 'Eliminar Usuario', ?, '{$dispositivoGlobal}', NOW())");
                $stmtAud->execute([$adminId, "Usuario ID: $targetId (Eliminado permanentemente)"]);
                echo json_encode(['ok' => true]);
            } else {
                echo json_encode(['ok' => false]);
            }
            break;

        case 'sincronizarLoteOffline':
            $usuarios = $data['usuarios'] ?? [];
            $pagos = $data['pagos'] ?? [];
            
            // Subir Usuarios
            foreach ($usuarios as $u) {
                // Check updated_at
                $stmt = $pdo->prepare("SELECT updated_at FROM DSI_salon_usuarios WHERE id = ?");
                $stmt->execute([$u['id']]);
                $remoto = $stmt->fetch();
                $sobrescribir = true;
                if ($remoto && $remoto['updated_at'] && $u['updatedAt']) {
                    $dtRemoto = new DateTime($remoto['updated_at']);
                    $dtLocal = new DateTime($u['updatedAt']);
                    if ($dtRemoto > $dtLocal) {
                        $sobrescribir = false;
                    }
                }
                if ($sobrescribir) {
                    $upd = $pdo->prepare("UPDATE DSI_salon_usuarios SET celular = ?, direccion = ?, edad = ?, sexo = ? WHERE id = ?");
                    $upd->execute([$u['celular'], $u['direccion'], $u['edad'], $u['sexo'], $u['id']]);
                }
            }
            
            // Subir Pagos (Monto debe ser de la actividad, se requiere adminId real, here we use generic rule)
            foreach ($pagos as $p) {
                $ins = $pdo->prepare("INSERT INTO DSI_salon_pagos (usuario_id, actividad_id, monto, fecha_pago, metodo_pago, confirmado) VALUES (?, ?, ?, ?, ?, ?)");
                $conf = $p['confirmado'] ? 1 : 0;
                $ins->execute([$p['usuarioId'], $p['actividadId'], $p['montoPagado'], $p['fechaPago'], $p['metodoPago'], $conf]);
            }
            
            echo json_encode(['ok' => true]);
            break;

        default:
            http_response_code(404);
            echo json_encode(['ok' => false, 'msj' => "Accion desconocida o sin migrar todavía: '$accion'"]);
            break;
    }
} catch (Exception $e) {
    http_response_code(500);
    echo json_encode(['ok' => false, 'msj' => 'Error Interno BD: ' . $e->getMessage()]);
}
?>
