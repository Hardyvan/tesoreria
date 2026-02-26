-- =============================================================================
-- BASE DE DATOS: tesoreria_ivan
-- FECHA: 05/02/2026
-- =============================================================================

-- 1. TABLA DE USUARIOS
-- Almacena los alumnos y administradores.
-- Se vincula con Google Sign-In mediante el campo 'email'.

CREATE TABLE IF NOT EXISTS DSI_salon_usuarios (
    id INT AUTO_INCREMENT PRIMARY KEY,
    nombre VARCHAR(255) NOT NULL,
    celular VARCHAR(20),
    email VARCHAR(255) UNIQUE NOT NULL, -- Clave para Login Google
    foto_url TEXT,
    rol VARCHAR(50) DEFAULT 'Alumno', -- 'Admin' o 'Alumno'
    direccion VARCHAR(255), -- Nuevo: Registro HÃ­brido
    edad INT,               -- Nuevo: Registro HÃ­brido
    sexo VARCHAR(20),       -- Nuevo: Registro HÃ­brido
    fecha_registro DATETIME DEFAULT CURRENT_TIMESTAMP,
    estado ENUM('activo', 'inactivo') DEFAULT 'activo'
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- SI LA TABLA YA EXISTE, EJECUTAR:
-- ALTER TABLE DSI_salon_usuarios ADD COLUMN direccion VARCHAR(255);
-- ALTER TABLE DSI_salon_usuarios ADD COLUMN edad INT;
-- ALTER TABLE DSI_salon_usuarios ADD COLUMN sexo VARCHAR(20);

-- 2. TABLA DE ACTIVIDADES (Futuro: Para ControladorActividades)
-- Almacena las polladas, cuotas, etc.

CREATE TABLE IF NOT EXISTS DSI_salon_actividades (
    id INT AUTO_INCREMENT PRIMARY KEY,
    titulo VARCHAR(255) NOT NULL,
    descripcion TEXT,
    costo DECIMAL(10, 2) NOT NULL, -- Ej: 20.00
    fecha_evento DATE,
    fecha_creacion DATETIME DEFAULT CURRENT_TIMESTAMP,
    id_creador INT,
    FOREIGN KEY (id_creador) REFERENCES DSI_salon_usuarios(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 3. DATOS DE EJEMPLO (Opcional)
-- Usuario Administrador por defecto (Login Manual)
-- Password 'admin123' no se guarda aquÃ­ porque el login manual estÃ¡ hardcodeado en cÃ³digo por ahora.
-- Pero registramos al usuario para que exista.

INSERT INTO DSI_salon_usuarios (nombre, celular, email, rol, foto_url)
VALUES 
('Administrador Principal', '999999999', 'admin@insoft.pe', 'Admin', '');
