-- =============================================================================
-- MIGRACIÓN FASE 4: Agregar soporte para Fecha Límite y Multas por Día
-- FECHA: 15/04/2026
-- =============================================================================

ALTER TABLE DSI_salon_actividades 
ADD COLUMN multa_por_dia DECIMAL(10, 2) DEFAULT 0.0 AFTER fecha_limite;
