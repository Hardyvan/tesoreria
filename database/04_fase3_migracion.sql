-- =============================================================================
-- MIGRACIÃ“N FASE 3: Tabla de Gastos
-- FECHA: 19/02/2026
-- =============================================================================

CREATE TABLE IF NOT EXISTS DSI_salon_gastos (
    id INT AUTO_INCREMENT PRIMARY KEY,
    descripcion VARCHAR(255) NOT NULL,
    monto DECIMAL(10, 2) NOT NULL,
    fecha_gasto DATETIME DEFAULT CURRENT_TIMESTAMP,
    usuario_id INT, -- QuiÃ©n registrÃ³ el gasto (Admin)
    FOREIGN KEY (usuario_id) REFERENCES DSI_salon_usuarios(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
