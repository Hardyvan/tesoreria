-- =============================================================================
-- MIGRACIÃ“N FASE 2: Tabla de Pagos
-- FECHA: 19/02/2026
-- =============================================================================

CREATE TABLE IF NOT EXISTS DSI_salon_pagos (
    id INT AUTO_INCREMENT PRIMARY KEY,
    usuario_id INT NOT NULL,
    actividad_id INT NOT NULL,
    monto DECIMAL(10, 2) NOT NULL,
    fecha_pago DATETIME DEFAULT CURRENT_TIMESTAMP,
    confirmado BOOLEAN DEFAULT TRUE,
    FOREIGN KEY (usuario_id) REFERENCES DSI_salon_usuarios(id),
    FOREIGN KEY (actividad_id) REFERENCES DSI_salon_actividades(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
