-- -----------------------------------------------------
-- Base de Datos: e20363690948 (InSOFT TesorerÃ­a)
-- Script de CreaciÃ³n de Esquema Inicial
-- -----------------------------------------------------

-- 1. Tabla: DSI_salon_usuarios
-- Almacena los alumnos y administradores.
CREATE TABLE IF NOT EXISTS `DSI_salon_usuarios` (
  `id` INT AUTO_INCREMENT PRIMARY KEY,
  `uid` VARCHAR(100) NULL,
  `nombre` VARCHAR(150) NOT NULL,
  `email` VARCHAR(150) UNIQUE,
  `celular` VARCHAR(20) NULL,
  `direccion` VARCHAR(255) NULL,
  `edad` INT NULL,
  `sexo` VARCHAR(20) NULL,
  `foto_url` VARCHAR(255) NULL,
  `rol` VARCHAR(50) DEFAULT 'Alumno',
  `fecha_registro` DATETIME DEFAULT CURRENT_TIMESTAMP,
  `estado` TINYINT(1) DEFAULT 1,
  `updated_at` DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 2. Tabla: DSI_salon_actividades
-- Almacena "Semanas" o "Eventos" con su meta financiera
CREATE TABLE IF NOT EXISTS `DSI_salon_actividades` (
  `id` INT AUTO_INCREMENT PRIMARY KEY,
  `titulo` VARCHAR(150) NOT NULL,
  `costo` DECIMAL(10,2) NOT NULL,
  `estado` TINYINT(1) DEFAULT 1,
  `fecha_creacion` DATETIME DEFAULT CURRENT_TIMESTAMP,
  `updated_at` DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 3. Tabla: DSI_salon_pagos
-- Ingresos: Pagos realizados por los usuarios asignados a actividades
CREATE TABLE IF NOT EXISTS `DSI_salon_pagos` (
  `id` INT AUTO_INCREMENT PRIMARY KEY,
  `usuario_id` INT NOT NULL,
  `actividad_id` INT NOT NULL,
  `monto` DECIMAL(10,2) NOT NULL,
  `fecha_pago` DATETIME DEFAULT CURRENT_TIMESTAMP,
  `confirmado` TINYINT(1) DEFAULT 1,
  `updated_at` DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  FOREIGN KEY (`usuario_id`) REFERENCES `DSI_salon_usuarios`(`id`) ON DELETE CASCADE,
  FOREIGN KEY (`actividad_id`) REFERENCES `DSI_salon_actividades`(`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;


-- 4. Tabla: DSI_salon_gastos
-- Egresos: Gastos generados por el salÃ³n
CREATE TABLE IF NOT EXISTS `DSI_salon_gastos` (
  `id` INT AUTO_INCREMENT PRIMARY KEY,
  `usuario_id` INT NOT NULL, -- Persona que registra el gasto
  `actividad_id` INT NULL,   -- Opcional: Si el gasto pertenece a una actividad
  `descripcion` TEXT NOT NULL,
  `monto` DECIMAL(10,2) NOT NULL,
  `fecha_gasto` DATETIME DEFAULT CURRENT_TIMESTAMP,
  `updated_at` DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  FOREIGN KEY (`usuario_id`) REFERENCES `DSI_salon_usuarios`(`id`) ON DELETE CASCADE,
  FOREIGN KEY (`actividad_id`) REFERENCES `DSI_salon_actividades`(`id`) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 5. Tabla: DSI_salon_auditoria
-- Registra acciones administrativas (opcional pero lo usa el controlador)
CREATE TABLE IF NOT EXISTS `DSI_salon_auditoria` (
  `id` INT AUTO_INCREMENT PRIMARY KEY,
  `admin_id` INT NOT NULL,
  `accion` VARCHAR(100) NOT NULL,
  `detalle` TEXT NULL,
  `dispositivo` VARCHAR(255) NULL,
  `fecha` DATETIME DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (`admin_id`) REFERENCES `DSI_salon_usuarios`(`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- InserciÃ³n de un SuperAdministrador base
INSERT INTO `DSI_salon_usuarios` (`nombre`, `email`, `rol`, `fecha_registro`) 
VALUES ('Super Admin', 'admin@tesoreria.com', 'SuperAdmin', NOW());
