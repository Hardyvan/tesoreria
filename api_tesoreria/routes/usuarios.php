<?php
/**
 * Rutas de Gestión de Usuarios y Perfiles - Tesorería API
 */

switch ($accion) {
    case 'sincronizarUsuarioBD':
        $uid = $data['uid'];
        $email = $data['email'] ?? '';
        $nombre = $data['nombre'] ?? '';
        $fotoGoogle = $data['fotoGoogle'] ?? '';
        
        $stmt = $pdo->prepare("SELECT * FROM DSI_salon_usuarios WHERE uid = ?");
        $stmt->execute([$uid]);
        $user = $stmt->fetch();
        
        if (!$user && $email) {
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
            if ($user['estado'] === 'inactivo') { echo json_encode(['ok' => true, 'status' => 'bloqueado']); exit; }
            $correosRoot = ['gurenge.leveling@gmail.com', 'hao_asakura@gmail.com'];
            $rol = $user['rol'];
            if (in_array(strtolower($email), $correosRoot) && $rol !== 'SuperAdmin') {
                $rol = 'SuperAdmin';
                $pdo->prepare("UPDATE DSI_salon_usuarios SET rol = 'SuperAdmin' WHERE id = ?")->execute([$user['id']]);
            }
            echo json_encode([ 'ok' => true, 'status' => 'OK', 'usuario' => [
                'id' => (int)$user['id'], 'uid' => $uid, 'nombre' => $user['nombre'], 'celular' => $user['celular'],
                'email' => $user['email'], 'foto_url' => $user['foto_url'], 'rol' => $rol, 'direccion' => $user['direccion'],
                'edad' => (int)$user['edad'], 'sexo' => $user['sexo'], 'estado' => $user['estado']
            ]]);
        } else {
            $correosRoot = ['gurenge.leveling@gmail.com', 'hao_asakura@gmail.com'];
            $rolAsignado = in_array(strtolower($email), $correosRoot) ? 'SuperAdmin' : 'Alumno';
            $stmt = $pdo->prepare("INSERT INTO DSI_salon_usuarios (uid, nombre, email, foto_url, rol, fecha_registro) VALUES (?, ?, ?, ?, ?, NOW())");
            $stmt->execute([$uid, $nombre, $email, $fotoGoogle, $rolAsignado]);
            echo json_encode([ 'ok' => true, 'status' => 'UsuarioNuevo', 'usuario' => [
                'id' => (int)$pdo->lastInsertId(), 'uid' => $uid, 'nombre' => $nombre, 'email' => $email, 'foto_url' => $fotoGoogle, 'rol' => $rolAsignado, 'celular' => ''
            ]]);
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

    case 'listarUsuariosCompleto':
        if ($adminRol !== 'Admin' && $adminRol !== 'SuperAdmin') { http_response_code(403); echo json_encode(['ok' => false, 'msj' => 'No autorizado']); exit; }
        $stmt = $pdo->query("SELECT id, nombre, celular, email, foto_url, rol, direccion, edad, sexo, estado, updated_at FROM DSI_salon_usuarios ORDER BY nombre ASC");
        echo json_encode(['ok' => true, 'datos' => $stmt->fetchAll()]);
        break;

    case 'cambiarRolUsuario':
        if ($adminRol !== 'SuperAdmin' && $adminRol !== 'Admin') { echo json_encode(['ok' => false]); exit; }
        $stmt = $pdo->prepare("UPDATE DSI_salon_usuarios SET rol = ? WHERE id = ?");
        if ($stmt->execute([$data['nuevoRol'], (int)$data['targetId']])) {
            $stmtAud = $pdo->prepare("INSERT INTO DSI_salon_auditoria (admin_id, accion, detalle, dispositivo, fecha) VALUES (?, 'Cambiar Rol', ?, 'Flutter API', NOW())");
            $stmtAud->execute([$adminId, "Usuario ID: {$data['targetId']} - Nuevo Rol: {$data['nuevoRol']}"]);
            echo json_encode(['ok' => true]);
        } else { echo json_encode(['ok' => false]); }
        break;

    case 'eliminarUsuario':
        if ($adminRol !== 'SuperAdmin' && $adminRol !== 'Admin') { echo json_encode(['ok' => false]); exit; }
        $stmt = $pdo->prepare("DELETE FROM DSI_salon_usuarios WHERE id = ?");
        if ($stmt->execute([(int)$data['targetId']])) {
            $stmtAud = $pdo->prepare("INSERT INTO DSI_salon_auditoria (admin_id, accion, detalle, dispositivo, fecha) VALUES (?, 'Eliminar Usuario', ?, 'Flutter API', NOW())");
            $stmtAud->execute([$adminId, "Usuario ID: {$data['targetId']} (Eliminado)"]);
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

    default:
        http_response_code(404);
        echo json_encode(['ok' => false, 'msj' => "Accion desconocida en Usuarios: '$accion'"]);
        break;
}
