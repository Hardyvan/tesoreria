<?php
/**
 * Enrutador Central Reconstruido - DSI Tesorería API
 * Punto de entrada único para la comunicación de la aplicación Flutter.
 */

// Configurar zona horaria de Perú de forma global
date_default_timezone_set('America/Lima');

header('Content-Type: application/json; charset=utf-8');

// 1. Configuración de CORS Profesional
header("Access-Control-Allow-Origin: *");
header("Access-Control-Allow-Methods: POST, GET, OPTIONS");
header("Access-Control-Allow-Headers: Authorization, Content-Type, Accept");

// Manejo de Preflight OPTIONS
if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit;
}

// 2. Cargar dependencias core
require_once __DIR__ . '/db.php';
require_once __DIR__ . '/middleware/auth.php';

/**
 * Envía un webhook de sincronización en tiempo real a Google Sheets mediante Google Apps Script.
 * Esta función es no-bloqueante / de bajo timeout para no afectar el rendimiento de la aplicación.
 * 
 * @param string $action Tipo de acción (PAGO_NUEVO, GASTO_NUEVO, INGRESO_EXTRA, APERTURA_CAJA, CAJA_RESET, etc.)
 * @param array $payload Datos asociados a la transacción.
 * @return bool True si se envió o si está desactivado, False si falló la conexión.
 */
function enviarPeticionConRedireccionManual($url, $jsonData, $maxRedirecciones = 5) {
    if ($maxRedirecciones <= 0) {
        return false;
    }

    $ch = curl_init($url);
    curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
    curl_setopt($ch, CURLOPT_CUSTOMREQUEST, "POST");
    curl_setopt($ch, CURLOPT_POSTFIELDS, $jsonData);
    curl_setopt($ch, CURLOPT_HTTPHEADER, [
        'Content-Type: application/json',
        'Content-Length: ' . strlen($jsonData)
    ]);
    curl_setopt($ch, CURLOPT_SSL_VERIFYPEER, false);
    curl_setopt($ch, CURLOPT_TIMEOUT, 6);
    curl_setopt($ch, CURLOPT_CONNECTTIMEOUT, 3);

    $openBasedir = ini_get('open_basedir');
    if (empty($openBasedir)) {
        curl_setopt($ch, CURLOPT_FOLLOWLOCATION, true);
        curl_setopt($ch, CURLOPT_MAXREDIRS, $maxRedirecciones);
        $response = curl_exec($ch);
        $httpCode = curl_getinfo($ch, CURLINFO_HTTP_CODE);
        curl_close($ch);
        return ($httpCode === 200 || $httpCode === 302);
    } else {
        curl_setopt($ch, CURLOPT_FOLLOWLOCATION, false);
        $response = curl_exec($ch);
        $httpCode = curl_getinfo($ch, CURLINFO_HTTP_CODE);
        $redirectUrl = curl_getinfo($ch, CURLINFO_REDIRECT_URL);
        curl_close($ch);

        if (($httpCode === 301 || $httpCode === 302 || $httpCode === 307 || $httpCode === 308) && !empty($redirectUrl)) {
            return enviarPeticionConRedireccionManualGet($redirectUrl, $maxRedirecciones - 1);
        }

        return ($httpCode === 200);
    }
}

function enviarPeticionConRedireccionManualGet($url, $maxRedirecciones = 5) {
    if ($maxRedirecciones <= 0) {
        return false;
    }

    $ch = curl_init($url);
    curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
    curl_setopt($ch, CURLOPT_SSL_VERIFYPEER, false);
    curl_setopt($ch, CURLOPT_TIMEOUT, 6);
    curl_setopt($ch, CURLOPT_CONNECTTIMEOUT, 3);
    curl_setopt($ch, CURLOPT_FOLLOWLOCATION, false);

    $response = curl_exec($ch);
    $httpCode = curl_getinfo($ch, CURLINFO_HTTP_CODE);
    $redirectUrl = curl_getinfo($ch, CURLINFO_REDIRECT_URL);
    curl_close($ch);

    if (($httpCode === 301 || $httpCode === 302 || $httpCode === 307 || $httpCode === 308) && !empty($redirectUrl)) {
        return enviarPeticionConRedireccionManualGet($redirectUrl, $maxRedirecciones - 1);
    }

    return ($httpCode === 200);
}

// Cola para sincronizaciones diferidas (caso fallback)
$GLOBALS['sheets_sync_queue'] = [];

function sincronizarConGoogleSheets($action, $payload) {
    $webhookUrl = getenv('GOOGLE_SHEET_WEBHOOK_URL');
    if (empty($webhookUrl)) {
        return true; 
    }

    // Estructurar el cuerpo de la petición
    $data = [
        'action' => $action,
        'timestamp' => date('Y-m-d H:i:s'),
        'payload' => $payload
    ];

    $jsonData = json_encode($data);

    // 1. Intentar ejecución asíncrona mediante comando cURL CLI en segundo plano (rápido y no-bloqueante)
    if (function_exists('exec') && strncasecmp(PHP_OS, 'WIN', 3) !== 0) {
        $escapedUrl = escapeshellarg($webhookUrl);
        $escapedJson = escapeshellarg($jsonData);
        // El caracter '&' al final corre el comando en segundo plano en Linux/Unix
        $command = "curl -L -k -H 'Content-Type: application/json' -d $escapedJson $escapedUrl > /dev/null 2>&1 &";
        exec($command);
        return true;
    }

    // 2. Fallback: Guardar en cola para procesarlo al final del script tras liberar al cliente
    $GLOBALS['sheets_sync_queue'][] = [
        'url' => $webhookUrl,
        'json' => $jsonData
    ];
    return true;
}

function triggerFullSheetsSync($pdo) {
    try {
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
        $resDeudores = $pdo->query($sqlDeudores)->fetchAll(PDO::FETCH_ASSOC);

        // 2. Obtener pagos
        $sqlPagos = "
            SELECT p.id, u.nombre as alumno, a.titulo as actividad, p.monto, p.monto_multa, p.metodo_pago, p.fecha_pago, admin.nombre as recaudador
            FROM DSI_salon_pagos p
            JOIN DSI_salon_usuarios u ON p.usuario_id = u.id
            JOIN DSI_salon_actividades a ON p.actividad_id = a.id
            LEFT JOIN DSI_salon_usuarios admin ON p.admin_id = admin.id
            WHERE p.confirmado = 1 ORDER BY p.fecha_pago DESC
        ";
        $resPagos = $pdo->query($sqlPagos)->fetchAll(PDO::FETCH_ASSOC);

        // 3. Obtener gastos
        $sqlGastos = "
            SELECT g.id, g.descripcion, a.titulo as actividad, u.nombre as responsable, g.monto, g.fecha_gasto, g.comprobante_url
            FROM DSI_salon_gastos g
            LEFT JOIN DSI_salon_actividades a ON g.actividad_id = a.id
            LEFT JOIN DSI_salon_usuarios u ON g.admin_id = u.id
            ORDER BY g.fecha_gasto DESC
        ";
        $resGastos = $pdo->query($sqlGastos)->fetchAll(PDO::FETCH_ASSOC);

        // 4. Obtener ingresos extra
        $sqlExtras = "
            SELECT i.id, i.descripcion, i.monto, i.fecha_ingreso, u.nombre as responsable
            FROM DSI_salon_ingresos_extra i
            LEFT JOIN DSI_salon_usuarios u ON i.admin_id = u.id
            ORDER BY i.fecha_ingreso DESC
        ";
        $resExtras = $pdo->query($sqlExtras)->fetchAll(PDO::FETCH_ASSOC);

        // 5. Obtener fondo base
        $sqlFondo = "SELECT monto, motivo, fecha_apertura FROM DSI_salon_fondo_base ORDER BY fecha_apertura DESC";
        $resFondo = $pdo->query($sqlFondo)->fetchAll(PDO::FETCH_ASSOC);

        // 6. Obtener actividades activas
        $sqlActividades = "SELECT id, titulo, costo FROM DSI_salon_actividades WHERE estado = 1 ORDER BY fecha_creacion ASC";
        $resActividades = $pdo->query($sqlActividades)->fetchAll(PDO::FETCH_ASSOC);
        
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

        return sincronizarConGoogleSheets('SINCRONIZAR_TODO', $payload);
    } catch (Exception $e) {
        return false;
    }
}

// Registrar función de apagado para liberar al cliente y procesar el fallback de Sheets en segundo plano
register_shutdown_function(function() {
    if (!empty($GLOBALS['sheets_sync_queue'])) {
        // Enviar respuesta al cliente y cerrar la conexión HTTP de inmediato
        if (function_exists('fastcgi_finish_request')) {
            fastcgi_finish_request();
        }
        
        // Procesar las peticiones encoladas
        foreach ($GLOBALS['sheets_sync_queue'] as $item) {
            enviarPeticionConRedireccionManual($item['url'], $item['json']);
        }
    }
});

// 3. Verificar seguridad (API Key)
verificarSeguridadAPI();

// 4. Leer datos recibidos (JSON o FORM-DATA)
$data = json_decode(file_get_contents('php://input'), true);
if (!$data) {
    $data = $_POST;
}

// 5. Determinar la acción
$accion = $data['accion'] ?? null;

if (!$accion && isset($_FILES['archivo'])) {
    $accion = 'subir_archivo';
}

if (!$accion) {
    http_response_code(400);
    echo json_encode([
        'ok' => false,
        'msj' => 'Acción no especificada en el enrutador de Tesorería.'
    ]);
    exit;
}

// 6. Obtener conexión a BD
$pdo = getDBConnection();

// 7. Resolución Automática de Datos de Administrador (Garantía de Rol)
$adminId = 0; 
$adminRol = 'Alumno'; // Valor por defecto seguro
$adminEmail = '';

if (isset($data['adminUid']) && !empty($data['adminUid'])) {
    $stmtRol = $pdo->prepare("SELECT id, rol, email FROM DSI_salon_usuarios WHERE uid = ?");
    $stmtRol->execute([$data['adminUid']]);
    $rowRol = $stmtRol->fetch();
    if ($rowRol) { 
        $adminRol = $rowRol['rol']; 
        $adminId = (int)$rowRol['id']; 
        $adminEmail = $rowRol['email'];
    }
} elseif (isset($data['adminId']) && (int)$data['adminId'] > 0) {
    $stmtRol = $pdo->prepare("SELECT id, rol, email FROM DSI_salon_usuarios WHERE id = ?");
    $stmtRol->execute([(int)$data['adminId']]);
    $rowRol = $stmtRol->fetch();
    if ($rowRol) { 
        $adminRol = $rowRol['rol']; 
        $adminId = (int)$rowRol['id']; 
        $adminEmail = $rowRol['email'];
    }
}

// 8. CONTROL DE SEGURIDAD EXCLUSIVO PARA EL SUPERADMIN PRINCIPAL (ID = 1 / gurenge.leveling@gmail.com)
// Forzar rol de SuperAdmin para el correo principal por seguridad de servidor
if (strtolower($adminEmail) === 'gurenge.leveling@gmail.com') {
    $adminRol = 'SuperAdmin';
    $adminId = 1;
}

// Restricciones críticas para proteger la cuenta id = 1
$targetId = isset($data['targetId']) ? (int)$data['targetId'] : (isset($data['id']) ? (int)$data['id'] : 0);

if ($targetId === 1) {
    // Bloquear cualquier intento de modificar o eliminar al Super Administrador Principal
    if (in_array($accion, ['eliminarUsuario', 'cambiarRolUsuario', 'cambiarEstadoUsuario'])) {
        http_response_code(403);
        echo json_encode([
            'ok' => false,
            'msj' => 'Operación Denegada. El Super Administrador Principal (ID = 1) no puede ser modificado, desactivado o eliminado por seguridad.'
        ]);
        exit;
    }
}

$dispositivoGlobal = $data['dispositivo'] ?? 'App Móvil';
$dispositivoGlobal = substr(strip_tags($dispositivoGlobal), 0, 50); // Sanitización básica

// 9. Enrutamiento Modular
try {
    switch ($accion) {
        // Finanzas y Reportes
        case 'obtenerResumenGeneral':
        case 'obtenerHistorialKardex':
        case 'obtenerMetasActividades':
        case 'obtenerReporteAvanzado':
        case 'obtenerReporteDeudores':
        case 'obtenerDatosExcel':
        case 'establecerFondoBase':
        case 'vaciarFondoBase':
        case 'editarFondoBase':
        case 'obtenerDashboardAnalytics':
            require_once __DIR__ . '/routes/finanzas.php';
            break;

        // Pagos
        case 'registrarPago':
        case 'editarPago':
        case 'eliminarPago':
        case 'obtenerDatosFinanzasUsuario':
        case 'obtenerDetallePagosPorActividad':
            require_once __DIR__ . '/routes/pagos.php';
            break;

        // Actividades
        case 'listarActividades':
        case 'crearActividad':
        case 'editarActividad':
        case 'eliminarActividad':
        case 'obtenerActividadesSimplificadas':
        case 'obtenerAsistencia':
        case 'guardarAsistenciaLote':
            require_once __DIR__ . '/routes/actividades.php';
            break;

        // Gastos e Ingresos Extra
        case 'registrarGasto':
        case 'editarGasto':
        case 'eliminarGasto':
        case 'registrarIngresoExtra':
        case 'editarIngresoExtra':
        case 'eliminarIngresoExtra':
            require_once __DIR__ . '/routes/gastos.php';
            break;

        // Usuarios
        case 'sincronizarUsuarioBD':
        case 'guardarPerfilCompletado':
        case 'listarUsuariosCompleto':
        case 'listarCompaneros':
        case 'cambiarRolUsuario':
        case 'cambiarEstadoUsuario':
        case 'eliminarUsuario':
        case 'actualizarElementoUsuario':
        case 'sincronizarLoteOffline':
        case 'registrarAlumnoOffline':
        case 'verificarCelularEnUso':
        case 'aceptarTerminos':
        case 'fusionarUsuarios':
        case 'obtenerExoneracionesUsuario':
        case 'guardarExoneracion':
            require_once __DIR__ . '/routes/usuarios.php';
            break;

        // Mantenimiento y Sistema
        case 'ping':
        case 'debug_schema':
        case 'registrarAccion':
        case 'obtenerLogsAuditoria':
        case 'vaciarAuditoria':
        case 'obtenerResumenCaja':
        case 'obtenerIdAdminActual':
        case 'verificar_estado_usuarios':
        case 'obtenerControlVersion':
        case 'sincronizarTodoGoogleSheets':
            require_once __DIR__ . '/routes/mantenimiento.php';
            break;

        // Subida de archivos
        case 'subir_archivo':
            require_once __DIR__ . '/routes/uploads.php';
            break;

        default:
            http_response_code(404);
            echo json_encode([
                'ok' => false,
                'msj' => "Acción desconocida en el sistema de Tesorería: '$accion'"
            ]);
            break;
    }
} catch (Exception $e) {
    http_response_code(500);
    echo json_encode([
        'ok' => false,
        'msj' => 'Error Interno en Tesorería API: ' . $e->getMessage()
    ]);
}
