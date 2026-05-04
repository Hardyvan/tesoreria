<?php
/**
 * Router Central - Tesorería API
 * Punto de entrada único para Lógica y Subidas
 */

header('Content-Type: application/json; charset=utf-8');

// 1. Configuración CORS Profesional
header("Access-Control-Allow-Origin: *");
header("Access-Control-Allow-Methods: POST, GET, OPTIONS");
header("Access-Control-Allow-Headers: Authorization, Content-Type, Accept");

// Preflight OPTIONS
if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit;
}

// 2. Cargar dependencias core
require_once __DIR__ . '/config/database.php';
require_once __DIR__ . '/middleware/auth.php';

// 3. Verificar seguridad (API Key)
verificarSeguridadAPI();

// 4. Leer datos (JSON o FORM-DATA)
$data = json_decode(file_get_contents('php://input'), true);
if (!$data) {
    $data = $_POST;
}

// 5. Determinar la acción
$accion = $data['accion'] ?? null;

// Asegurar existencia de tabla de Fondo Base (Failsafe)
$pdo = getDBConnection();
$pdo->exec("CREATE TABLE IF NOT EXISTS DSI_salon_fondo_base (
    id INT AUTO_INCREMENT PRIMARY KEY,
    monto DECIMAL(10,2) NOT NULL,
    motivo VARCHAR(255),
    fecha_apertura DATETIME DEFAULT CURRENT_TIMESTAMP
)");

$pdo->exec("CREATE TABLE IF NOT EXISTS DSI_salon_ingresos_extra (
    id INT AUTO_INCREMENT PRIMARY KEY,
    descripcion VARCHAR(255) NOT NULL,
    monto DECIMAL(10,2) NOT NULL,
    fecha_ingreso DATETIME DEFAULT CURRENT_TIMESTAMP,
    admin_id INT
)");

try {
    $pdo->exec("ALTER TABLE DSI_salon_actividades ADD COLUMN requiere_asistencia TINYINT(1) DEFAULT 0;");
    $pdo->exec("ALTER TABLE DSI_salon_actividades ADD COLUMN multa_inasistencia DECIMAL(10,2) DEFAULT 0.00;");
} catch (Exception $e) {}
try {
    $pdo->exec("CREATE TABLE IF NOT EXISTS DSI_salon_asistencias (
        id INT AUTO_INCREMENT PRIMARY KEY,
        actividad_id INT NOT NULL,
        usuario_id INT NOT NULL,
        estado VARCHAR(20) NOT NULL COMMENT 'asistio, falto, permiso',
        monto_multa DECIMAL(10,2) DEFAULT 0.00,
        fecha_registro DATETIME DEFAULT CURRENT_TIMESTAMP,
        updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
        UNIQUE KEY uq_actividad_usuario (actividad_id, usuario_id),
        FOREIGN KEY (actividad_id) REFERENCES DSI_salon_actividades(id) ON DELETE CASCADE,
        FOREIGN KEY (usuario_id) REFERENCES DSI_salon_usuarios(id) ON DELETE CASCADE
    )");
} catch (Exception $e) {}

if (!$accion && isset($_FILES['archivo'])) {
    $accion = 'subir_archivo';
}

if (!$accion) {
    http_response_code(400);
    echo json_encode(['ok' => false, 'msj' => 'Acción no especificada en Tesorería.']);
    exit;
}

// 6. Obtener conexión a BD
$pdo = getDBConnection();

// 7. PARCHE GLOBAL DE SEGURIDAD (Recuperación de adminRol)
// Garantiza que el backend use el Rol real de la BD si el APK falla al enviarlo.
$adminId = 0; $adminRol = '';
if (isset($data['adminUid']) && !empty($data['adminUid'])) {
    $stmtRol = $pdo->prepare("SELECT id, rol FROM DSI_salon_usuarios WHERE uid = ?");
    $stmtRol->execute([$data['adminUid']]);
    $rowRol = $stmtRol->fetch();
    if ($rowRol) { $adminRol = $rowRol['rol']; $adminId = (int)$rowRol['id']; }
} elseif (isset($data['adminId']) && (int)$data['adminId'] > 0) {
    $stmtRol = $pdo->prepare("SELECT id, rol FROM DSI_salon_usuarios WHERE id = ?");
    $stmtRol->execute([(int)$data['adminId']]);
    $rowRol = $stmtRol->fetch();
    if ($rowRol) { $adminRol = $rowRol['rol']; $adminId = (int)$data['adminId']; }
}

// 8. Enrutamiento modular
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
        case 'cambiarRolUsuario':
        case 'eliminarUsuario':
        case 'actualizarElementoUsuario':
        case 'sincronizarLoteOffline':
            require_once __DIR__ . '/routes/usuarios.php';
            break;

        // Mantenimiento y Sistema
        case 'ping':
        case 'debug_schema':
        case 'registrarAccion':
        case 'obtenerLogsAuditoria':
        case 'vaciarAuditoria':
        case 'obtenerResumenCaja':
            require_once __DIR__ . '/routes/mantenimiento.php';
            break;

        // Subida de archivos
        case 'subir_archivo':
            require_once __DIR__ . '/routes/uploads.php';
            break;

        default:
            http_response_code(404);
            echo json_encode(['ok' => false, 'msj' => "Acción desconocida en Tesorería: '$accion'"]);
            break;
    }
} catch (Exception $e) {
    http_response_code(500);
    echo json_encode(['ok' => false, 'msj' => 'Error Interno Tesorería: ' . $e->getMessage()]);
}
