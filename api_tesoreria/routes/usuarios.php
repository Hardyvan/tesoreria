<?php
/**
 * Rutas de Gestión de Usuarios y Perfiles - Tesorería API
 */

switch ($accion) {
    case 'verificarCelularEnUso':
        $celular = $data['celular'] ?? '';
        $excluirId = isset($data['excluirId']) ? (int)$data['excluirId'] : null;
        
        if (empty($celular)) {
            echo json_encode(['ok' => true, 'enUso' => false]);
            exit;
        }
        
        if ($excluirId !== null) {
            $stmt = $pdo->prepare("SELECT COUNT(*) FROM DSI_salon_usuarios WHERE celular = ? AND id != ?");
            $stmt->execute([$celular, $excluirId]);
        } else {
            $stmt = $pdo->prepare("SELECT COUNT(*) FROM DSI_salon_usuarios WHERE celular = ?");
            $stmt->execute([$celular]);
        }
        
        $count = (int)$stmt->fetchColumn();
        echo json_encode(['ok' => true, 'enUso' => $count > 0]);
        break;

    case 'sincronizarUsuarioBD':
        $uid = $data['uid'];
        $email = $data['email'] ?? '';
        $nombre = $data['nombre'] ?? '';
        $fotoGoogle = $data['fotoGoogle'] ?? '';
        
        $esSuperAdminEmail = (strtolower($email) === 'gurenge.leveling@gmail.com');

        // Función de normalización integrada
        if (!function_exists('normalizarNombre')) {
            function normalizarNombre($str) {
                $str = strtolower($str);
                $reemplazos = [
                    'á'=>'a', 'é'=>'e', 'í'=>'i', 'ó'=>'o', 'ú'=>'u',
                    'à'=>'a', 'è'=>'e', 'ì'=>'i', 'ò'=>'o', 'ù'=>'u',
                    'ä'=>'a', 'ë'=>'e', 'ï'=>'i', 'ö'=>'o', 'ü'=>'u',
                    'ñ'=>'n', 'ñ'=>'n',
                    'Á'=>'a', 'É'=>'e', 'Í'=>'i', 'Ó'=>'o', 'Ú'=>'u'
                ];
                $str = strtr($str, $reemplazos);
                $str = preg_replace('/\s+/', ' ', $str);
                return trim($str);
            }
        }

        if ($esSuperAdminEmail) {
            // Eliminar cualquier duplicado que tenga este correo o uid con un ID diferente de 1 para evitar violar la restricción UNIQUE
            $pdo->prepare("DELETE FROM DSI_salon_usuarios WHERE email = ? AND id != 1")->execute([$email]);
            if (!empty($uid)) {
                $pdo->prepare("DELETE FROM DSI_salon_usuarios WHERE uid = ? AND id != 1")->execute([$uid]);
            }

            // 1. Validar e imponer el Super Administrador en ID = 1
            $stmt = $pdo->prepare("SELECT * FROM DSI_salon_usuarios WHERE id = 1");
            $stmt->execute();
            $user = $stmt->fetch();

            if ($user) {
                // Si existe pero los datos cambiaron (ej: UID o Email anterior), los corregimos (estado 1 = activo)
                $pdo->prepare("UPDATE DSI_salon_usuarios SET uid = ?, email = ?, rol = 'SuperAdmin', estado = 1 WHERE id = 1")->execute([$uid, $email]);
                // Volver a consultar para obtener datos actualizados
                $stmt = $pdo->prepare("SELECT * FROM DSI_salon_usuarios WHERE id = 1");
                $stmt->execute();
                $user = $stmt->fetch();
            } else {
                // Si por alguna razón no existe el ID 1, lo insertamos explícitamente con ID = 1
                $stmt = $pdo->prepare("INSERT INTO DSI_salon_usuarios (id, uid, nombre, email, foto_url, rol, estado, fecha_registro) VALUES (1, ?, ?, ?, ?, 'SuperAdmin', 1, NOW())");
                $stmt->execute([$uid, $nombre, $email, $fotoGoogle]);
                
                $stmt = $pdo->prepare("SELECT * FROM DSI_salon_usuarios WHERE id = 1");
                $stmt->execute();
                $user = $stmt->fetch();
            }
        } else {
            // Lógica normal para los demás usuarios
            $stmt = $pdo->prepare("SELECT * FROM DSI_salon_usuarios WHERE uid = ?");
            $stmt->execute([$uid]);
            $user = $stmt->fetch();
            
            if (!$user && $email) {
                $stmt = $pdo->prepare("SELECT * FROM DSI_salon_usuarios WHERE email = ?");
                $stmt->execute([$email]);
                $user = $stmt->fetch();
                if ($user) {
                    // Evitar que otro usuario tome el ID 1
                    if ((int)$user['id'] === 1) {
                        http_response_code(403);
                        echo json_encode(['ok' => false, 'msj' => 'Conflicto de cuenta de administrador principal.']);
                        exit;
                    }
                    $pdo->prepare("UPDATE DSI_salon_usuarios SET uid = ? WHERE id = ?")->execute([$uid, $user['id']]);
                    $user['uid'] = $uid; // Sincronizar localmente el uid recién agregado
                }
            }

            // FALLBACK por NOMBRE (Flexible e Inteligente para Fusión Segura)
            if (!$user && $nombre) {
                // 1. Intentar coincidencia exacta de nombre
                $stmt = $pdo->prepare("SELECT * FROM DSI_salon_usuarios WHERE nombre = ? AND (uid IS NULL OR uid = '')");
                $stmt->execute([$nombre]);
                $user = $stmt->fetch();
                
                if ($user) {
                    if ((int)$user['id'] === 1) {
                        http_response_code(403);
                        echo json_encode(['ok' => false, 'msj' => 'Conflicto de vinculación con administrador principal.']);
                        exit;
                    }
                    $pdo->prepare("UPDATE DSI_salon_usuarios SET uid = ?, email = ? WHERE id = ?")->execute([$uid, $email, $user['id']]);
                    $user['uid'] = $uid;
                    $user['email'] = $email;
                } else {
                    // 2. Intentar coincidencia flexible normalizando cadenas
                    $stmtTodos = $pdo->prepare("SELECT * FROM DSI_salon_usuarios WHERE (uid IS NULL OR uid = '') AND id != 1");
                    $stmtTodos->execute();
                    $todos = $stmtTodos->fetchAll();
                    
                    $nombreGoogleNorm = normalizarNombre($nombre);
                    foreach ($todos as $uManual) {
                        if (normalizarNombre($uManual['nombre']) === $nombreGoogleNorm) {
                            $user = $uManual;
                            $pdo->prepare("UPDATE DSI_salon_usuarios SET uid = ?, email = ? WHERE id = ?")->execute([$uid, $email, $user['id']]);
                            $user['uid'] = $uid;
                            $user['email'] = $email;
                            break;
                        }
                    }
                }
            }
        }

        if ($user) {
            // Actualizar foto si el registro viejo no tenía
            if ($fotoGoogle) {
                $pdo->prepare("UPDATE DSI_salon_usuarios SET foto_url = ? WHERE id = ? AND (foto_url IS NULL OR foto_url = '')")->execute([$fotoGoogle, $user['id']]);
                if (empty($user['foto_url'])) {
                    $user['foto_url'] = $fotoGoogle;
                }
            }
        }
        
        if ($user) {
            // En base de datos, 1 es activo, 0 es bloqueado/inactivo
            if ((int)$user['estado'] === 0) { 
                echo json_encode(['ok' => true, 'status' => 'bloqueado']); 
                exit; 
            }
            $rol = $user['rol'];
            if ($esSuperAdminEmail) {
                $rol = 'SuperAdmin';
            }
            $estadoStr = ((int)$user['estado'] === 1) ? 'activo' : 'inactivo';
            echo json_encode([ 'ok' => true, 'status' => 'OK', 'usuario' => [
                'id' => (int)$user['id'], 'uid' => $uid, 'nombre' => $user['nombre'], 'celular' => $user['celular'],
                'email' => $user['email'], 'foto_url' => $user['foto_url'], 'rol' => $rol, 'direccion' => $user['direccion'],
                'edad' => (int)$user['edad'], 'sexo' => $user['sexo'], 'estado' => $estadoStr
            ]]);
        } else {
            // Crear usuario nuevo (estado 1 = activo)
            $rolAsignado = 'Alumno';
            $stmt = $pdo->prepare("INSERT INTO DSI_salon_usuarios (uid, nombre, email, foto_url, rol, fecha_registro, estado) VALUES (?, ?, ?, ?, ?, NOW(), 1)");
            $stmt->execute([$uid, $nombre, $email, $fotoGoogle, $rolAsignado]);
            echo json_encode([ 'ok' => true, 'status' => 'UsuarioNuevo', 'usuario' => [
                'id' => (int)$pdo->lastInsertId(), 'uid' => $uid, 'nombre' => $nombre, 'email' => $email, 'foto_url' => $fotoGoogle, 'rol' => $rolAsignado, 'celular' => ''
            ]]);
        }
        break;

    case 'guardarPerfilCompletado':
        $id = (int)($data['id'] ?? 0);
        $uid = $data['uid'];
        $email = $data['email'] ?? '';
        $nombre = $data['nombre'];
        $celular = $data['celular'];
        $direccion = $data['direccion'];
        $edad = (int)$data['edad'];
        $sexo = $data['sexo'];
        $fotoUrl = $data['fotoUrl'] ?? '';
        
        $esSuperAdminEmail = (strtolower($email) === 'gurenge.leveling@gmail.com');

        if ($esSuperAdminEmail) {
            $id = 1;
            // Eliminar cualquier duplicado que tenga este correo o uid con un ID diferente de 1 para evitar violar la restricción UNIQUE
            $pdo->prepare("DELETE FROM DSI_salon_usuarios WHERE email = ? AND id != 1")->execute([$email]);
            if (!empty($uid)) {
                $pdo->prepare("DELETE FROM DSI_salon_usuarios WHERE uid = ? AND id != 1")->execute([$uid]);
            }

            // Asegurarnos de que el ID 1 esté reservado al Super Administrador (estado 1 = activo)
            $stmt = $pdo->prepare("SELECT id FROM DSI_salon_usuarios WHERE id = 1");
            $stmt->execute();
            if (!$stmt->fetch()) {
                $stmt = $pdo->prepare("INSERT INTO DSI_salon_usuarios (id, uid, nombre, email, celular, direccion, edad, sexo, foto_url, rol, fecha_registro, estado) VALUES (1, ?, ?, ?, ?, ?, ?, ?, ?, 'SuperAdmin', NOW(), 1)");
                $stmt->execute([$uid, $nombre, $email, $celular, $direccion, $edad, $sexo, $fotoUrl]);
            } else {
                $stmt = $pdo->prepare("UPDATE DSI_salon_usuarios SET nombre = ?, celular = ?, direccion = ?, edad = ?, sexo = ?, uid = ?, email = ?, rol = 'SuperAdmin', estado = 1 WHERE id = 1");
                $stmt->execute([$nombre, $celular, $direccion, $edad, $sexo, $uid, $email]);
            }
        } else {
            if ($id === 0 || $id === 1) {
                $stmt = $pdo->prepare("SELECT id FROM DSI_salon_usuarios WHERE uid = ?");
                $stmt->execute([$uid]);
                $exist = $stmt->fetch();
                if ($exist) {
                    $id = (int)$exist['id'];
                } else {
                    $rolAsignado = 'Alumno';
                    $stmt = $pdo->prepare("INSERT INTO DSI_salon_usuarios (uid, nombre, email, celular, direccion, edad, sexo, foto_url, rol, fecha_registro, estado) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, NOW(), 1)");
                    $stmt->execute([$uid, $nombre, $email, $celular, $direccion, $edad, $sexo, $fotoUrl, $rolAsignado]);
                    $id = (int)$pdo->lastInsertId();
                }
            }
            if ($id > 1) {
                $stmt = $pdo->prepare("UPDATE DSI_salon_usuarios SET nombre = ?, celular = ?, direccion = ?, edad = ?, sexo = ? WHERE id = ?");
                $stmt->execute([$nombre, $celular, $direccion, $edad, $sexo, $id]);
            }
        }
        echo json_encode(['ok' => true, 'id' => $id]);
        break;

    case 'listarUsuariosCompleto':
        if ($adminRol !== 'Admin' && $adminRol !== 'SuperAdmin') { http_response_code(403); echo json_encode(['ok' => false, 'msj' => 'No autorizado']); exit; }
        $stmt = $pdo->query("SELECT id, nombre, celular, email, foto_url, rol, direccion, edad, sexo, estado, updated_at FROM DSI_salon_usuarios ORDER BY nombre ASC");
        $datos = $stmt->fetchAll();
        foreach ($datos as &$u) {
            $u['estado'] = ((int)$u['estado'] === 1) ? 'activo' : 'inactivo';
        }
        echo json_encode(['ok' => true, 'datos' => $datos]);
        break;

    // NUEVO: Endpoint abierto a cualquier usuario autenticado para ver compañeros del salón
    case 'listarCompaneros':
        // Solo requiere estar autenticado (adminId > 0 porque el backend resuelve el uid)
        // Devuelve datos básicos: no expone celular, email, ni datos sensibles
        $stmt = $pdo->query("SELECT id, nombre, foto_url, rol, estado FROM DSI_salon_usuarios WHERE estado = 1 ORDER BY nombre ASC");
        $datos = $stmt->fetchAll();
        foreach ($datos as &$u) {
            $u['estado'] = 'activo';
        }
        echo json_encode(['ok' => true, 'datos' => $datos]);
        break;

    case 'cambiarRolUsuario':
        if ($adminRol !== 'SuperAdmin' && $adminRol !== 'Admin') { echo json_encode(['ok' => false]); exit; }
        $targetId = (int)$data['targetId'];
        if ($targetId === 1) {
            echo json_encode(['ok' => false, 'msj' => 'Operación denegada. El SuperAdministrador Principal (ID = 1) no puede ser modificado.']);
            exit;
        }
        $stmt = $pdo->prepare("UPDATE DSI_salon_usuarios SET rol = ? WHERE id = ?");
        if ($stmt->execute([$data['nuevoRol'], $targetId])) {
            $stmtAud = $pdo->prepare("INSERT INTO DSI_salon_auditoria (admin_id, accion, detalle, dispositivo, fecha) VALUES (?, 'Cambiar Rol', ?, '{$dispositivoGlobal}', NOW())");
            $stmtAud->execute([$adminId, "Usuario ID: {$targetId} - Nuevo Rol: {$data['nuevoRol']}"]);
            echo json_encode(['ok' => true]);
        } else { echo json_encode(['ok' => false]); }
        break;

    case 'cambiarEstadoUsuario':
        if ($adminRol !== 'SuperAdmin' && $adminRol !== 'Admin') { echo json_encode(['ok' => false]); exit; }
        $targetId = (int)$data['targetId'];
        if ($targetId === 1) {
            echo json_encode(['ok' => false, 'msj' => 'Operación denegada. El SuperAdministrador Principal (ID = 1) no puede ser desactivado.']);
            exit;
        }
        $nuevoEstado = $data['nuevoEstado']; // 'activo', 'inactivo', 'bloqueado'
        $estadoInt = ($nuevoEstado === 'activo') ? 1 : 0;
        $stmt = $pdo->prepare("UPDATE DSI_salon_usuarios SET estado = ? WHERE id = ?");
        if ($stmt->execute([$estadoInt, $targetId])) {
            $stmtAud = $pdo->prepare("INSERT INTO DSI_salon_auditoria (admin_id, accion, detalle, dispositivo, fecha) VALUES (?, 'Cambiar Estado Usuario', ?, '{$dispositivoGlobal}', NOW())");
            $stmtAud->execute([$adminId, "Usuario ID: $targetId - Nuevo Estado: $nuevoEstado"]);
            echo json_encode(['ok' => true]);
        } else {
            echo json_encode(['ok' => false]);
        }
        break;


    case 'eliminarUsuario':
        if ($adminRol !== 'SuperAdmin' && $adminRol !== 'Admin') { echo json_encode(['ok' => false]); exit; }
        $targetId = (int)$data['targetId'];
        if ($targetId === 1) {
            echo json_encode(['ok' => false, 'msj' => 'Operación denegada. El SuperAdministrador Principal (ID = 1) no puede ser eliminado.']);
            exit;
        }
        $stmt = $pdo->prepare("DELETE FROM DSI_salon_usuarios WHERE id = ?");
        if ($stmt->execute([$targetId])) {
            $stmtAud = $pdo->prepare("INSERT INTO DSI_salon_auditoria (admin_id, accion, detalle, dispositivo, fecha) VALUES (?, 'Eliminar Usuario', ?, '{$dispositivoGlobal}', NOW())");
            $stmtAud->execute([$adminId, "Usuario ID: {$targetId} (Eliminado)"]);
            echo json_encode(['ok' => true]);
        } else { echo json_encode(['ok' => false]); }
        break;

    case 'actualizarElementoUsuario':
        $id = (int)$data['id'];
        // Seguridad: Solo el dueño del perfil o un admin puede editar
        if ($id !== $adminId && $adminRol !== 'Admin' && $adminRol !== 'SuperAdmin') {
            http_response_code(403); echo json_encode(['ok' => false, 'msj' => 'No puedes editar este perfil']); exit;
        }
        if (isset($data['nombre'])) $pdo->prepare("UPDATE DSI_salon_usuarios SET nombre = ? WHERE id = ?")->execute([$data['nombre'], $id]);
        if (isset($data['celular'])) $pdo->prepare("UPDATE DSI_salon_usuarios SET celular = ? WHERE id = ?")->execute([$data['celular'], $id]);
        if (isset($data['fotoUrl'])) $pdo->prepare("UPDATE DSI_salon_usuarios SET foto_url = ? WHERE id = ?")->execute([$data['fotoUrl'], $id]);
        if (isset($data['fcmToken'])) $pdo->prepare("UPDATE DSI_salon_usuarios SET fcm_token = ? WHERE id = ?")->execute([$data['fcmToken'], $id]);
        echo json_encode(['ok' => true]);
        break;

    case 'sincronizarLoteOffline':
        foreach ($data['usuarios'] ?? [] as $u) {
            $stmt = $pdo->prepare("SELECT updated_at FROM DSI_salon_usuarios WHERE id = ?");
            $stmt->execute([$u['id']]);
            $remoto = $stmt->fetch();
            if (!$remoto || !$remoto['updated_at'] || (new DateTime($u['updatedAt']) > new DateTime($remoto['updated_at']))) {
                $pdo->prepare("UPDATE DSI_salon_usuarios SET celular = ?, direccion = ?, edad = ?, sexo = ? WHERE id = ?")->execute([$u['celular'], $u['direccion'], $u['edad'], $u['sexo'], $u['id']]);
            }
        }
        foreach ($data['pagos'] ?? [] as $p) {
            $ins = $pdo->prepare("INSERT INTO DSI_salon_pagos (usuario_id, actividad_id, monto, fecha_pago, metodo_pago, confirmado) VALUES (?, ?, ?, ?, ?, ?)");
            $ins->execute([$p['usuarioId'], $p['actividadId'], $p['montoPagado'], $p['fechaPago'], $p['metodoPago'], $p['confirmado'] ? 1 : 0]);
        }
        echo json_encode(['ok' => true]);
        break;

    case 'registrarAlumnoOffline':
        $nombre = trim($data['nombre'] ?? '');
        $email = trim($data['email'] ?? '');
        $celular = trim($data['celular'] ?? '');
        
        if (empty($nombre)) {
            http_response_code(400);
            echo json_encode(['ok' => false, 'msj' => 'El nombre del alumno es obligatorio.']);
            exit;
        }
        
        // Si se provee email, validar que no esté ya registrado
        if (!empty($email)) {
            $stmtCheck = $pdo->prepare("SELECT COUNT(*) FROM DSI_salon_usuarios WHERE email = ?");
            $stmtCheck->execute([$email]);
            if ((int)$stmtCheck->fetchColumn() > 0) {
                http_response_code(400);
                echo json_encode(['ok' => false, 'msj' => 'El correo electrónico ya está registrado.']);
                exit;
            }
        }
        
        $rolAsignado = 'Alumno';
        $estado = 1; // activo
        
        $stmt = $pdo->prepare("INSERT INTO DSI_salon_usuarios (nombre, email, celular, rol, estado, fecha_registro) VALUES (?, ?, ?, ?, ?, NOW())");
        if ($stmt->execute([
            $nombre, 
            empty($email) ? null : $email, 
            empty($celular) ? null : $celular, 
            $rolAsignado, 
            $estado
        ])) {
            $nuevoId = (int)$pdo->lastInsertId();
            echo json_encode(['ok' => true, 'id' => $nuevoId]);
        } else {
            echo json_encode(['ok' => false, 'msj' => 'No se pudo registrar el alumno de forma manual.']);
        }
        break;

    case 'obtenerExoneracionesUsuario':
        $usuarioId = (int)($data['usuarioId'] ?? 0);
        if ($usuarioId === 0) {
            http_response_code(400);
            echo json_encode(['ok' => false, 'msj' => 'ID de usuario no provisto.']);
            exit;
        }
        
        $stmt = $pdo->prepare("SELECT actividad_id FROM DSI_salon_exoneraciones WHERE usuario_id = ?");
        $stmt->execute([$usuarioId]);
        $actividades = $stmt->fetchAll(PDO::FETCH_COLUMN);
        
        echo json_encode(['ok' => true, 'actividades' => array_map('intval', $actividades)]);
        break;

    case 'guardarExoneracion':
        // Seguridad: Solo Admins/SuperAdmins pueden exonerar
        if ($adminRol !== 'Admin' && $adminRol !== 'SuperAdmin') {
            http_response_code(403);
            echo json_encode(['ok' => false, 'msj' => 'Acción no autorizada.']);
            exit;
        }

        $usuarioId = (int)($data['usuarioId'] ?? 0);
        $actividadId = (int)($data['actividadId'] ?? 0);
        $exonerado = (bool)($data['exonerado'] ?? false);

        if ($usuarioId === 0 || $actividadId === 0) {
            http_response_code(400);
            echo json_encode(['ok' => false, 'msj' => 'Datos insuficientes para exonerar.']);
            exit;
        }

        if ($exonerado) {
            // Insertar exoneración (IGNORE por si ya existe)
            $stmt = $pdo->prepare("INSERT IGNORE INTO DSI_salon_exoneraciones (usuario_id, actividad_id) VALUES (?, ?)");
            $stmt->execute([$usuarioId, $actividadId]);
            
            // Auditoría
            $stmtAud = $pdo->prepare("INSERT INTO DSI_salon_auditoria (admin_id, accion, detalle, dispositivo, fecha) VALUES (?, 'Exonerar Alumno', ?, '{$dispositivoGlobal}', NOW())");
            $stmtAud->execute([$adminId, "Usuario ID {$usuarioId} exonerado de Actividad ID {$actividadId}"]);
        } else {
            // Eliminar exoneración
            $stmt = $pdo->prepare("DELETE FROM DSI_salon_exoneraciones WHERE usuario_id = ? AND actividad_id = ?");
            $stmt->execute([$usuarioId, $actividadId]);

            // Auditoría
            $stmtAud = $pdo->prepare("INSERT INTO DSI_salon_auditoria (admin_id, accion, detalle, dispositivo, fecha) VALUES (?, 'Quitar Exoneracion', ?, '{$dispositivoGlobal}', NOW())");
            $stmtAud->execute([$adminId, "Usuario ID {$usuarioId} participa nuevamente en Actividad ID {$actividadId}"]);
        }

        echo json_encode(['ok' => true]);
        break;

    default:
        http_response_code(404);
        echo json_encode(['ok' => false, 'msj' => "Accion desconocida en Usuarios: '$accion'"]);
        break;
}
