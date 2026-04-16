-- =============================================================================
-- MIGRACIÓN INTELIGENTE A PRUEBA DE FALLOS (Para MySQL Workbench)
-- =============================================================================

DELIMITER $$
DROP PROCEDURE IF EXISTS _AgregarColumnaSegura $$
CREATE PROCEDURE _AgregarColumnaSegura(
    IN nombreTabla VARCHAR(255),
    IN nombreColumna VARCHAR(255),
    IN definicionColumna VARCHAR(255)
)
BEGIN
    IF NOT EXISTS (
        SELECT * FROM INFORMATION_SCHEMA.COLUMNS
        WHERE table_name = nombreTabla
        AND column_name = nombreColumna
        AND table_schema = DATABASE()
    ) THEN
        SET @query = CONCAT('ALTER TABLE ', nombreTabla, ' ADD COLUMN ', nombreColumna, ' ', definicionColumna);
        PREPARE stmt FROM @query;
        EXECUTE stmt;
        DEALLOCATE PREPARE stmt;
    END IF;
END $$
DELIMITER ;

-- 1. TABLA PAGOS
CALL _AgregarColumnaSegura('DSI_salon_pagos', 'monto_multa', "DECIMAL(10, 2) DEFAULT 0.00 AFTER monto");
CALL _AgregarColumnaSegura('DSI_salon_pagos', 'metodo_pago', "VARCHAR(50) DEFAULT 'Efectivo' AFTER monto_multa");
CALL _AgregarColumnaSegura('DSI_salon_pagos', 'comprobante_url', "TEXT NULL AFTER metodo_pago");
CALL _AgregarColumnaSegura('DSI_salon_pagos', 'admin_id', "INT NULL AFTER comprobante_url");

-- 2. TABLA GASTOS
CALL _AgregarColumnaSegura('DSI_salon_gastos', 'comprobante_url', "TEXT NULL AFTER fecha_gasto");
CALL _AgregarColumnaSegura('DSI_salon_gastos', 'actividad_id', "INT NULL AFTER comprobante_url");
CALL _AgregarColumnaSegura('DSI_salon_gastos', 'admin_id', "INT NULL AFTER actividad_id");

-- 3. TABLA ACTIVIDADES
CALL _AgregarColumnaSegura('DSI_salon_actividades', 'fecha_limite', "DATE NULL AFTER costo");
CALL _AgregarColumnaSegura('DSI_salon_actividades', 'multa_por_dia', "DECIMAL(10, 2) DEFAULT 0.00 AFTER fecha_limite");
CALL _AgregarColumnaSegura('DSI_salon_actividades', 'estado', "TINYINT(1) DEFAULT 1 AFTER multa_por_dia");
CALL _AgregarColumnaSegura('DSI_salon_actividades', 'updated_at', "DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP");

-- 4. TABLA USUARIOS
CALL _AgregarColumnaSegura('DSI_salon_usuarios', 'fcm_token', "TEXT NULL");
CALL _AgregarColumnaSegura('DSI_salon_usuarios', 'updated_at', "DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP");

-- LIMPIEZA
DROP PROCEDURE IF EXISTS _AgregarColumnaSegura;
