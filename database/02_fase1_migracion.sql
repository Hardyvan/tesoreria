-- =============================================================================
-- MIGRACIÃ“N FASE 1: SincronizaciÃ³n de Usuarios y Roles
-- FECHA: 19/02/2026
-- =============================================================================

-- 1. Agregar columna 'uid' para vincular con Google Auth / Firebase
-- Se permite NULL inicialmente para usuarios legacy, pero deberÃ­a ser UNIQUE.

DO $$ 
BEGIN 
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                   WHERE table_name = 'DSI_salon_usuarios' AND column_name = 'uid') THEN
        ALTER TABLE DSI_salon_usuarios ADD COLUMN uid VARCHAR(128) UNIQUE AFTER id;
    END IF;
END $$;

-- NOTA: Si usas MySQL directo y no soporta bloques DO $$, usa la linea directa:
-- ALTER TABLE DSI_salon_usuarios ADD COLUMN uid VARCHAR(128) UNIQUE AFTER id;

-- En MySQL estÃ¡ndar:
ALTER TABLE DSI_salon_usuarios ADD COLUMN uid VARCHAR(128) UNIQUE AFTER id;
