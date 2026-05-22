<?php
/**
 * Enrutador Central Reconstruido - DSI Tesorería API
 * Punto de entrada único para la comunicación de la aplicación Flutter.
 */

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
function sincronizarConGoogleSheets($action, $payload) {
    $webhookUrl = getenv('GOOGLE_SHEET_WEBHOOK_URL');
    if (empty($webhookUrl)) {
        return true; // Sincronización desactivada silenciosamente
    }

    // Estructurar el cuerpo de la petición
    $data = [
        'action' => $action,
        'timestamp' => date('Y-m-d H:i:s'),
        'payload' => $payload
    ];

    $jsonData = json_encode($data);

    // Inicializar cURL
    $ch = curl_init($webhookUrl);
    curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
    curl_setopt($ch, CURLOPT_CUSTOMREQUEST, "POST");
    curl_setopt($ch, CURLOPT_POSTFIELDS, $jsonData);
    curl_setopt($ch, CURLOPT_HTTPHEADER, [
        'Content-Type: application/json',
        'Content-Length: ' . strlen($jsonData)
    ]);
    
    // Configuración para redirecciones (muy importante para Google Apps Script)
    curl_setopt($ch, CURLOPT_FOLLOWLOCATION, true);
    curl_setopt($ch, CURLOPT_SSL_VERIFYPEER, false); // Evitar problemas de certificado local/servidor compartido
    
    // Timeout bajo para no ralentizar la respuesta del API al usuario
    curl_setopt($ch, CURLOPT_TIMEOUT, 6); 
    curl_setopt($ch, CURLOPT_CONNECTTIMEOUT, 3);

    $response = curl_exec($ch);
    $error = curl_error($ch);
    $httpCode = curl_getinfo($ch, CURLINFO_HTTP_CODE);
    curl_close($ch);

    if ($error) {
        return false;
    }

    return $httpCode === 200 || $httpCode === 302;
}

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
