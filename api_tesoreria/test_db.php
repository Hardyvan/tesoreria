<?php
require_once 'config/database.php';
$pdo = getDBConnection();
$stmt = $pdo->query("SELECT id, nombre, email, celular FROM DSI_salon_usuarios");
echo json_encode($stmt->fetchAll(PDO::FETCH_ASSOC));
?>
