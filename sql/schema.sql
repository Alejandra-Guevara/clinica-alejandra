-- 1. SEGURIDAD -------------------------------------------------

CREATE TABLE usuarios (
    id_usuario BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    nombres VARCHAR(100) NOT NULL,
    apellidos VARCHAR(100) NOT NULL,
    email VARCHAR(190) NOT NULL UNIQUE,
    password_hash VARCHAR(255) NOT NULL,
    estado ENUM('activo','inactivo','bloqueado') NOT NULL DEFAULT 'activo',
    creado_en DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    actualizado_en DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB;

CREATE TABLE roles (
    id_rol INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    nombre VARCHAR(50) NOT NULL UNIQUE,
    descripcion VARCHAR(255)
) ENGINE=InnoDB;

CREATE TABLE usuario_rol (
    id_usuario BIGINT UNSIGNED NOT NULL,
    id_rol INT UNSIGNED NOT NULL,
    PRIMARY KEY (id_usuario, id_rol),
    CONSTRAINT fk_ur_usuario FOREIGN KEY (id_usuario)
        REFERENCES usuarios(id_usuario) ON DELETE CASCADE,
    CONSTRAINT fk_ur_rol FOREIGN KEY (id_rol)
        REFERENCES roles(id_rol) ON DELETE RESTRICT
) ENGINE=InnoDB;

-- 2. PERSONAS Y PROFESIONALES ----------------------------------

CREATE TABLE pacientes (
    id_paciente BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    id_usuario BIGINT UNSIGNED NULL UNIQUE, -- Solo si usa portal de pacientes
    tipo_documento VARCHAR(20) NOT NULL,
    numero_documento VARCHAR(40) NOT NULL,
    nombres VARCHAR(100) NOT NULL,
    apellidos VARCHAR(100) NOT NULL,
    fecha_nacimiento DATE NOT NULL,
    sexo_registrado VARCHAR(30),
    telefono VARCHAR(30),
    email VARCHAR(190),
    direccion VARCHAR(255),
    grupo_sanguineo VARCHAR(5),
    creado_en DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    UNIQUE KEY uq_paciente_documento (tipo_documento, numero_documento),
    CONSTRAINT fk_paciente_usuario FOREIGN KEY (id_usuario)
        REFERENCES usuarios(id_usuario) ON DELETE RESTRICT
) ENGINE=InnoDB;

CREATE TABLE medicos (
    id_medico BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    id_usuario BIGINT UNSIGNED NOT NULL UNIQUE,
    numero_registro_profesional VARCHAR(60) NOT NULL UNIQUE,
    activo BOOLEAN NOT NULL DEFAULT TRUE,
    CONSTRAINT fk_medico_usuario FOREIGN KEY (id_usuario)
        REFERENCES usuarios(id_usuario) ON DELETE RESTRICT
) ENGINE=InnoDB;

CREATE TABLE especialidades (
    id_especialidad INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    nombre VARCHAR(120) NOT NULL UNIQUE,
    descripcion VARCHAR(255)
) ENGINE=InnoDB;

CREATE TABLE medico_especialidad (
    id_medico BIGINT UNSIGNED NOT NULL,
    id_especialidad INT UNSIGNED NOT NULL,
    PRIMARY KEY (id_medico, id_especialidad),
    CONSTRAINT fk_me_medico FOREIGN KEY (id_medico)
        REFERENCES medicos(id_medico) ON DELETE CASCADE,
    CONSTRAINT fk_me_especialidad FOREIGN KEY (id_especialidad)
        REFERENCES especialidades(id_especialidad) ON DELETE RESTRICT
) ENGINE=InnoDB;

-- 3. HISTORIA CLINICA Y CONTEXTO DEL PACIENTE ------------------

CREATE TABLE historias_clinicas (
    id_historia BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    id_paciente BIGINT UNSIGNED NOT NULL UNIQUE, -- 1 historia por paciente
    numero_historia VARCHAR(40) NOT NULL UNIQUE,
    fecha_apertura DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    estado ENUM('activa','archivada') NOT NULL DEFAULT 'activa',
    CONSTRAINT fk_historia_paciente FOREIGN KEY (id_paciente)
        REFERENCES pacientes(id_paciente) ON DELETE RESTRICT
) ENGINE=InnoDB;

CREATE TABLE alergias (
    id_alergia INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    nombre VARCHAR(150) NOT NULL UNIQUE,
    tipo ENUM('medicamento','alimento','ambiental','otra') NOT NULL DEFAULT 'otra',
    descripcion VARCHAR(255)
) ENGINE=InnoDB;

CREATE TABLE paciente_alergia (
    id_paciente_alergia BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    id_paciente BIGINT UNSIGNED NOT NULL,
    id_alergia INT UNSIGNED NOT NULL,
    reaccion VARCHAR(255),
    severidad ENUM('leve','moderada','grave','desconocida') NOT NULL DEFAULT 'desconocida',
    registrada_en DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    UNIQUE KEY uq_paciente_alergia (id_paciente, id_alergia),
    CONSTRAINT fk_pa_paciente FOREIGN KEY (id_paciente)
        REFERENCES pacientes(id_paciente) ON DELETE RESTRICT,
    CONSTRAINT fk_pa_alergia FOREIGN KEY (id_alergia)
        REFERENCES alergias(id_alergia) ON DELETE RESTRICT
) ENGINE=InnoDB;

CREATE TABLE antecedentes (
    id_antecedente INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    nombre VARCHAR(150) NOT NULL UNIQUE,
    descripcion VARCHAR(255)
) ENGINE=InnoDB;

CREATE TABLE paciente_antecedente (
    id_paciente_antecedente BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    id_paciente BIGINT UNSIGNED NOT NULL,
    id_antecedente INT UNSIGNED NOT NULL,
    tipo ENUM('personal','familiar','quirurgico','farmacologico','habito','otro') NOT NULL,
    parentesco VARCHAR(50), -- P. ej. madre, padre, hermano (solo familiar)
    detalle TEXT,
    fecha_referencia DATE NULL,
    registrado_en DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    KEY idx_pac_ant (id_paciente, tipo),
    CONSTRAINT fk_pan_paciente FOREIGN KEY (id_paciente)
        REFERENCES pacientes(id_paciente) ON DELETE RESTRICT,
    CONSTRAINT fk_pan_antecedente FOREIGN KEY (id_antecedente)
        REFERENCES antecedentes(id_antecedente) ON DELETE RESTRICT
) ENGINE=InnoDB;

-- 4. CONSULTAS: TODA LA ATENCION CLINICA AQUI ------------------

CREATE TABLE consultas (
    id_consulta BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    id_historia BIGINT UNSIGNED NOT NULL,
    id_medico BIGINT UNSIGNED NOT NULL,
    fecha_hora DATETIME NOT NULL,
    tipo_consulta ENUM('primera_vez','control','urgencia','otra') NOT NULL DEFAULT 'otra',
    motivo_consulta TEXT NOT NULL,
    enfermedad_actual TEXT,
    anamnesis TEXT,
    revision_sistemas TEXT,
    examen_fisico TEXT,
    analisis_clinico TEXT,
    plan_manejo TEXT,
    observaciones TEXT,
    estado ENUM('borrador','finalizada','anulada') NOT NULL DEFAULT 'borrador',
    finalizada_en DATETIME NULL,
    creado_en DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    actualizado_en DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    KEY idx_consultas_historia_fecha (id_historia, fecha_hora),
    KEY idx_consultas_medico_fecha (id_medico, fecha_hora),
    CONSTRAINT fk_consulta_historia FOREIGN KEY (id_historia)
        REFERENCES historias_clinicas(id_historia) ON DELETE RESTRICT,
    CONSTRAINT fk_consulta_medico FOREIGN KEY (id_medico)
        REFERENCES medicos(id_medico) ON DELETE RESTRICT
) ENGINE=InnoDB;

CREATE TABLE diagnosticos (
    id_diagnostico INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    codigo_cie10 VARCHAR(20) NOT NULL UNIQUE,
    nombre VARCHAR(200) NOT NULL,
    descripcion TEXT
) ENGINE=InnoDB;

CREATE TABLE consulta_diagnostico (
    id_consulta BIGINT UNSIGNED NOT NULL,
    id_diagnostico INT UNSIGNED NOT NULL,
    tipo ENUM('principal','secundario','presuntivo') NOT NULL DEFAULT 'secundario',
    observaciones VARCHAR(255),
    PRIMARY KEY (id_consulta, id_diagnostico),
    CONSTRAINT fk_cd_consulta FOREIGN KEY (id_consulta)
        REFERENCES consultas(id_consulta) ON DELETE RESTRICT,
    CONSTRAINT fk_cd_diagnostico FOREIGN KEY (id_diagnostico)
        REFERENCES diagnosticos(id_diagnostico) ON DELETE RESTRICT
) ENGINE=InnoDB;

CREATE TABLE signos_vitales (
    id_signos BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    id_consulta BIGINT UNSIGNED NOT NULL,
    medido_en DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    presion_sistolica SMALLINT UNSIGNED,
    presion_diastolica SMALLINT UNSIGNED,
    frecuencia_cardiaca SMALLINT UNSIGNED,
    frecuencia_respiratoria SMALLINT UNSIGNED,
    temperatura_c DECIMAL(4,1),
    peso_kg DECIMAL(6,2),
    talla_cm DECIMAL(5,2),
    saturacion_oxigeno_pct DECIMAL(5,2),
    KEY idx_signos_consulta (id_consulta, medido_en),
    CONSTRAINT fk_signos_consulta FOREIGN KEY (id_consulta)
        REFERENCES consultas(id_consulta) ON DELETE RESTRICT,
    CONSTRAINT chk_signos_sat CHECK (
        saturacion_oxigeno_pct IS NULL OR saturacion_oxigeno_pct BETWEEN 0 AND 100
    )
) ENGINE=InnoDB;

-- 5. FORMULAS Y MEDICAMENTOS ----------------------------------

CREATE TABLE medicamentos (
    id_medicamento INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    nombre VARCHAR(150) NOT NULL,
    concentracion VARCHAR(100),
    forma_farmaceutica VARCHAR(100),
    codigo_catalogo VARCHAR(60) UNIQUE
) ENGINE=InnoDB;

CREATE TABLE recetas (
    id_receta BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    id_consulta BIGINT UNSIGNED NOT NULL,
    fecha_emision DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    indicaciones_generales TEXT,
    KEY idx_recetas_consulta (id_consulta),
    CONSTRAINT fk_receta_consulta FOREIGN KEY (id_consulta)
        REFERENCES consultas(id_consulta) ON DELETE RESTRICT
) ENGINE=InnoDB;

CREATE TABLE receta_detalle (
    id_receta_detalle BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    id_receta BIGINT UNSIGNED NOT NULL,
    id_medicamento INT UNSIGNED NOT NULL,
    dosis VARCHAR(100) NOT NULL,
    via_administracion VARCHAR(80),
    frecuencia VARCHAR(100),
    duracion VARCHAR(100),
    cantidad VARCHAR(80),
    indicaciones TEXT,
    KEY idx_rd_receta (id_receta),
    CONSTRAINT fk_rd_receta FOREIGN KEY (id_receta)
        REFERENCES recetas(id_receta) ON DELETE RESTRICT,
    CONSTRAINT fk_rd_medicamento FOREIGN KEY (id_medicamento)
        REFERENCES medicamentos(id_medicamento) ON DELETE RESTRICT
) ENGINE=InnoDB;

-- 6. EXAMENES Y RESULTADOS ------------------------------------

CREATE TABLE examenes (
    id_examen INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    nombre VARCHAR(160) NOT NULL,
    descripcion VARCHAR(255),
    codigo_catalogo VARCHAR(60) UNIQUE
) ENGINE=InnoDB;

CREATE TABLE ordenes_examen (
    id_orden BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    id_consulta BIGINT UNSIGNED NOT NULL,
    fecha_emision DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    observaciones TEXT,
    KEY idx_orden_consulta (id_consulta),
    CONSTRAINT fk_orden_consulta FOREIGN KEY (id_consulta)
        REFERENCES consultas(id_consulta) ON DELETE RESTRICT
) ENGINE=InnoDB;

CREATE TABLE orden_examen_detalle (
    id_orden_detalle BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    id_orden BIGINT UNSIGNED NOT NULL,
    id_examen INT UNSIGNED NOT NULL,
    estado ENUM('solicitado','en_proceso','informado','cancelado')
        NOT NULL DEFAULT 'solicitado',
    resultado_resumen TEXT,
    fecha_resultado DATETIME NULL,
    KEY idx_oed_orden (id_orden),
    CONSTRAINT fk_oed_orden FOREIGN KEY (id_orden)
        REFERENCES ordenes_examen(id_orden) ON DELETE RESTRICT,
    CONSTRAINT fk_oed_examen FOREIGN KEY (id_examen)
        REFERENCES examenes(id_examen) ON DELETE RESTRICT
) ENGINE=InnoDB;

-- 7. AUDITORIA BASICA DE ACCESOS A REGISTROS ------------------
-- Requiere que el backend escriba cada evento; para un sistema
-- real tambien se necesitan controles de integridad e inmutabilidad.

CREATE TABLE auditoria_accesos (
    id_auditoria BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    id_usuario BIGINT UNSIGNED NOT NULL,
    accion ENUM('consulta','creacion','modificacion','anulacion','exportacion') NOT NULL,
    entidad VARCHAR(80) NOT NULL,
    id_registro BIGINT UNSIGNED NOT NULL,
    fecha_hora DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    ip_origen VARCHAR(45),
    detalles JSON NULL,
    KEY idx_auditoria_usuario_fecha (id_usuario, fecha_hora),
    KEY idx_auditoria_entidad_registro (entidad, id_registro),
    CONSTRAINT fk_auditoria_usuario FOREIGN KEY (id_usuario)
        REFERENCES usuarios(id_usuario) ON DELETE RESTRICT
) ENGINE=InnoDB;
