-- =====================================================================
-- SIRDEPA · Sistema de Registro de Desembarque Pesquero Artesanal
-- 01_esquema.sql · Modelo físico (PostgreSQL 16 + PostGIS 3)
-- Crea extensiones, esquema, tipos, 28 tablas del modelo lógico y
-- 2 tablas técnicas de seguridad (codigo_otp y sesion).
-- Autor: equipo SIRDEPA (2026) · Repositorio: BaseDatos/
-- =====================================================================

CREATE EXTENSION IF NOT EXISTS pgcrypto;      -- gen_random_uuid(), digest()
CREATE EXTENSION IF NOT EXISTS btree_gist;    -- restricciones EXCLUDE con rangos
CREATE EXTENSION IF NOT EXISTS postgis;       -- geometría de las cuadrículas

DROP SCHEMA IF EXISTS sirdepa CASCADE;
CREATE SCHEMA sirdepa;
SET search_path = sirdepa, public;

-- ---------------------------------------------------------------------
-- 1. Tipos enumerados (dominios cerrados del negocio)
-- ---------------------------------------------------------------------
CREATE TYPE categoria_embarcacion AS ENUM ('ARTESANAL', 'MENOR_ESCALA');
CREATE TYPE tipo_lugar            AS ENUM ('DPA', 'CALETA');
CREATE TYPE tipo_comprador        AS ENUM ('COMERCIANTE', 'PLANTA_PROCESADORA', 'OTRO');
CREATE TYPE estado_aviso          AS ENUM ('PENDIENTE', 'VINCULADO', 'VENCIDO');
CREATE TYPE estado_validacion     AS ENUM ('CONFORME', 'OBSERVADO', 'NO_CONFORME');
CREATE TYPE estado_registro       AS ENUM ('VIGENTE', 'ANULADO');
CREATE TYPE estado_constancia     AS ENUM ('VIGENTE', 'ANULADA');
CREATE TYPE destino_saldo         AS ENUM ('CONSUMO_TRIPULACION', 'MERMA', 'ALMACENAMIENTO_DPA');
CREATE TYPE estado_lote           AS ENUM ('ASIGNADO', 'RECIBIDO', 'ANULADO');
CREATE TYPE tipo_notificacion     AS ENUM ('CODIGO_ACCESO', 'CONSTANCIA', 'LOTE',
                                           'PERMISO_POR_VENCER', 'PERMISO_VENCIDO');
CREATE TYPE estado_envio          AS ENUM ('PENDIENTE', 'ENVIADO', 'FALLIDO');
CREATE TYPE tipo_alerta           AS ENUM ('NO_CONFORME', 'OBSERVADO');
CREATE TYPE prioridad_alerta      AS ENUM ('ALTA', 'MEDIA');
CREATE TYPE estado_alerta         AS ENUM ('PENDIENTE', 'EN_ATENCION', 'ATENDIDA');
CREATE TYPE resultado_inspeccion  AS ENUM ('SIN_HALLAZGO', 'OBSERVACION', 'ACTA');

-- ---------------------------------------------------------------------
-- 2. Acceso y maestros
-- ---------------------------------------------------------------------
CREATE TABLE rol (
    id_rol      smallint     GENERATED ALWAYS AS IDENTITY,
    codigo      varchar(20)  NOT NULL,
    nombre      varchar(60)  NOT NULL,
    CONSTRAINT pk_rol PRIMARY KEY (id_rol),
    CONSTRAINT uq_rol_codigo UNIQUE (codigo)
);

CREATE TABLE lugar_desembarque (
    id_lugar    integer      GENERATED ALWAYS AS IDENTITY,
    codigo      varchar(10)  NOT NULL,
    nombre      varchar(80)  NOT NULL,
    tipo        tipo_lugar   NOT NULL DEFAULT 'DPA',
    region      varchar(40)  NOT NULL,
    CONSTRAINT pk_lugar PRIMARY KEY (id_lugar),
    CONSTRAINT uq_lugar_codigo UNIQUE (codigo)
);

CREATE TABLE usuario (
    id_usuario        uuid         NOT NULL DEFAULT gen_random_uuid(),
    dni               char(8)      NOT NULL,
    celular           varchar(9)   NOT NULL,
    pin_hash          varchar(100),                    -- Argon2id; NULL en roles sin PIN
    id_rol            smallint     NOT NULL,
    id_lugar          integer,                         -- solo roles del DPA
    activo            boolean      NOT NULL DEFAULT true,
    intentos_fallidos smallint     NOT NULL DEFAULT 0,
    bloqueado_hasta   timestamptz,
    CONSTRAINT pk_usuario PRIMARY KEY (id_usuario),
    CONSTRAINT uq_usuario_dni UNIQUE (dni),
    CONSTRAINT ck_usuario_dni CHECK (dni ~ '^[0-9]{8}$'),
    CONSTRAINT ck_usuario_celular CHECK (celular ~ '^9[0-9]{8}$'),
    CONSTRAINT ck_usuario_intentos CHECK (intentos_fallidos BETWEEN 0 AND 5),
    CONSTRAINT fk_usuario_rol FOREIGN KEY (id_rol) REFERENCES rol (id_rol),
    CONSTRAINT fk_usuario_lugar FOREIGN KEY (id_lugar) REFERENCES lugar_desembarque (id_lugar)
);

CREATE TABLE armador (
    id_armador  integer      GENERATED ALWAYS AS IDENTITY,
    tipo_doc    varchar(3)   NOT NULL,
    num_doc     varchar(11)  NOT NULL,
    nombre      varchar(120) NOT NULL,
    celular     varchar(9)   NOT NULL,
    id_usuario  uuid,
    CONSTRAINT pk_armador PRIMARY KEY (id_armador),
    CONSTRAINT uq_armador_doc UNIQUE (tipo_doc, num_doc),
    CONSTRAINT uq_armador_usuario UNIQUE (id_usuario),
    CONSTRAINT ck_armador_tipo_doc CHECK (tipo_doc IN ('DNI', 'RUC', 'CE')),
    CONSTRAINT fk_armador_usuario FOREIGN KEY (id_usuario) REFERENCES usuario (id_usuario)
);

CREATE TABLE comprador (
    id_comprador integer        GENERATED ALWAYS AS IDENTITY,
    tipo_doc     varchar(3)     NOT NULL,
    num_doc      varchar(11)    NOT NULL,
    nombre       varchar(120)   NOT NULL,
    tipo         tipo_comprador NOT NULL,
    celular      varchar(9)     NOT NULL,
    id_usuario   uuid,
    CONSTRAINT pk_comprador PRIMARY KEY (id_comprador),
    CONSTRAINT uq_comprador_doc UNIQUE (tipo_doc, num_doc),
    CONSTRAINT uq_comprador_usuario UNIQUE (id_usuario),
    CONSTRAINT ck_comprador_tipo_doc CHECK (tipo_doc IN ('DNI', 'RUC', 'CE')),
    CONSTRAINT fk_comprador_usuario FOREIGN KEY (id_usuario) REFERENCES usuario (id_usuario)
);

CREATE TABLE embarcacion (
    id_embarcacion integer               GENERATED ALWAYS AS IDENTITY,
    matricula      varchar(15)           NOT NULL,
    nombre         varchar(80)           NOT NULL,
    eslora_m       numeric(4,2)          NOT NULL,
    bodega_m3      numeric(5,2)          NOT NULL,
    categoria      categoria_embarcacion NOT NULL,
    id_armador     integer               NOT NULL,
    activo         boolean               NOT NULL DEFAULT true,
    actualizado_en timestamptz           NOT NULL DEFAULT now(),
    CONSTRAINT pk_embarcacion PRIMARY KEY (id_embarcacion),
    CONSTRAINT uq_embarcacion_matricula UNIQUE (matricula),
    -- RD01: solo embarcaciones de hasta 32,6 m3 de bodega y 15 m de eslora
    CONSTRAINT ck_embarcacion_bodega CHECK (bodega_m3 > 0 AND bodega_m3 <= 32.6),
    CONSTRAINT ck_embarcacion_eslora CHECK (eslora_m > 0 AND eslora_m <= 15),
    CONSTRAINT fk_embarcacion_armador FOREIGN KEY (id_armador) REFERENCES armador (id_armador)
);

-- ---------------------------------------------------------------------
-- 3. Catálogo normativo
-- ---------------------------------------------------------------------
CREATE TABLE especie (
    id_especie        integer      GENERATED ALWAYS AS IDENTITY,
    codigo_fao        char(3)      NOT NULL,           -- lista ASFIS (RNF11)
    nombre_comun      varchar(60)  NOT NULL,
    nombre_cientifico varchar(80)  NOT NULL,
    actualizado_en    timestamptz  NOT NULL DEFAULT now(),
    CONSTRAINT pk_especie PRIMARY KEY (id_especie),
    CONSTRAINT uq_especie_fao UNIQUE (codigo_fao),
    CONSTRAINT ck_especie_fao CHECK (codigo_fao ~ '^[A-Z]{3}$')
);

CREATE TABLE arte_pesca (
    id_arte        smallint     GENERATED ALWAYS AS IDENTITY,
    nombre         varchar(60)  NOT NULL,
    tipo           varchar(30)  NOT NULL,
    mecanizado     boolean      NOT NULL DEFAULT false,
    actualizado_en timestamptz  NOT NULL DEFAULT now(),
    CONSTRAINT pk_arte PRIMARY KEY (id_arte),
    CONSTRAINT uq_arte_nombre UNIQUE (nombre)
);

CREATE TABLE zona_pesca (
    id_zona           integer      GENERATED ALWAYS AS IDENTITY,
    codigo_cuadricula varchar(10)  NOT NULL,
    dentro_5_millas   boolean      NOT NULL,
    dentro_3_millas   boolean      NOT NULL,
    geom              geometry(Polygon, 4326),         -- celda, no posición exacta
    actualizado_en    timestamptz  NOT NULL DEFAULT now(),
    CONSTRAINT pk_zona PRIMARY KEY (id_zona),
    CONSTRAINT uq_zona_cuadricula UNIQUE (codigo_cuadricula),
    CONSTRAINT ck_zona_millas CHECK (NOT dentro_3_millas OR dentro_5_millas)
);

CREATE TABLE talla_minima (
    id_talla       integer      GENERATED ALWAYS AS IDENTITY,
    id_especie     integer      NOT NULL,
    talla_min_cm   numeric(5,1) NOT NULL,
    tolerancia_pct numeric(5,2) NOT NULL,
    norma          varchar(60)  NOT NULL,
    vigente_desde  date         NOT NULL,
    vigente_hasta  date,                               -- NULL = vigente
    actualizado_en timestamptz  NOT NULL DEFAULT now(),
    CONSTRAINT pk_talla PRIMARY KEY (id_talla),
    CONSTRAINT ck_talla_valor CHECK (talla_min_cm > 0),
    CONSTRAINT ck_talla_tolerancia CHECK (tolerancia_pct BETWEEN 0 AND 100),
    CONSTRAINT ck_talla_vigencia CHECK (vigente_hasta IS NULL OR vigente_hasta >= vigente_desde),
    CONSTRAINT fk_talla_especie FOREIGN KEY (id_especie) REFERENCES especie (id_especie),
    -- RD03: una sola talla vigente por especie en cada fecha
    CONSTRAINT ex_talla_solapada EXCLUDE USING gist (
        id_especie WITH =,
        daterange(vigente_desde, vigente_hasta, '[]') WITH &&)
);

CREATE TABLE limite_captura (
    id_limite      integer       GENERATED ALWAYS AS IDENTITY,
    id_especie     integer       NOT NULL,
    periodo_inicio date          NOT NULL,
    periodo_fin    date          NOT NULL,
    limite_kg      numeric(14,2) NOT NULL,
    norma          varchar(60)   NOT NULL,
    actualizado_en timestamptz   NOT NULL DEFAULT now(),
    CONSTRAINT pk_limite PRIMARY KEY (id_limite),
    CONSTRAINT ck_limite_kg CHECK (limite_kg > 0),
    CONSTRAINT ck_limite_periodo CHECK (periodo_fin >= periodo_inicio),
    CONSTRAINT fk_limite_especie FOREIGN KEY (id_especie) REFERENCES especie (id_especie)
);

CREATE TABLE veda (
    id_veda        integer      GENERATED ALWAYS AS IDENTITY,
    id_especie     integer      NOT NULL,
    id_zona        integer,                            -- NULL = todo el litoral
    fecha_inicio   date         NOT NULL,
    fecha_fin      date         NOT NULL,
    norma          varchar(60)  NOT NULL,
    actualizado_en timestamptz  NOT NULL DEFAULT now(),
    CONSTRAINT pk_veda PRIMARY KEY (id_veda),
    CONSTRAINT ck_veda_fechas CHECK (fecha_fin >= fecha_inicio),
    CONSTRAINT fk_veda_especie FOREIGN KEY (id_especie) REFERENCES especie (id_especie),
    CONSTRAINT fk_veda_zona FOREIGN KEY (id_zona) REFERENCES zona_pesca (id_zona)
);

CREATE TABLE permiso_pesca (
    id_permiso        integer      GENERATED ALWAYS AS IDENTITY,
    id_embarcacion    integer      NOT NULL,
    num_resolucion    varchar(40)  NOT NULL,
    entidad_emisora   varchar(60)  NOT NULL,
    fecha_emision     date         NOT NULL,
    fecha_vencimiento date         NOT NULL,
    actualizado_en    timestamptz  NOT NULL DEFAULT now(),
    CONSTRAINT pk_permiso PRIMARY KEY (id_permiso),
    CONSTRAINT uq_permiso_resolucion UNIQUE (entidad_emisora, num_resolucion),
    CONSTRAINT ck_permiso_fechas CHECK (fecha_vencimiento > fecha_emision),
    CONSTRAINT fk_permiso_embarcacion FOREIGN KEY (id_embarcacion)
        REFERENCES embarcacion (id_embarcacion) ON DELETE CASCADE
);

-- Relaciones N:M resueltas con tablas intermedias (4FN)
CREATE TABLE permiso_especie (
    id_permiso integer NOT NULL,
    id_especie integer NOT NULL,
    CONSTRAINT pk_permiso_especie PRIMARY KEY (id_permiso, id_especie),
    CONSTRAINT fk_pe_permiso FOREIGN KEY (id_permiso) REFERENCES permiso_pesca (id_permiso) ON DELETE CASCADE,
    CONSTRAINT fk_pe_especie FOREIGN KEY (id_especie) REFERENCES especie (id_especie)
);

CREATE TABLE permiso_arte (
    id_permiso integer  NOT NULL,
    id_arte    smallint NOT NULL,
    CONSTRAINT pk_permiso_arte PRIMARY KEY (id_permiso, id_arte),
    CONSTRAINT fk_pa_permiso FOREIGN KEY (id_permiso) REFERENCES permiso_pesca (id_permiso) ON DELETE CASCADE,
    CONSTRAINT fk_pa_arte FOREIGN KEY (id_arte) REFERENCES arte_pesca (id_arte)
);

-- ---------------------------------------------------------------------
-- 4. Desembarque, validación y trazabilidad
-- ---------------------------------------------------------------------
CREATE TABLE aviso_arribo (
    id_aviso       integer      GENERATED ALWAYS AS IDENTITY,
    id_embarcacion integer      NOT NULL,
    id_lugar       integer      NOT NULL,
    hora_estimada  timestamptz  NOT NULL,
    captura_aprox  varchar(200),
    estado         estado_aviso NOT NULL DEFAULT 'PENDIENTE',
    CONSTRAINT pk_aviso PRIMARY KEY (id_aviso),
    CONSTRAINT fk_aviso_embarcacion FOREIGN KEY (id_embarcacion) REFERENCES embarcacion (id_embarcacion),
    CONSTRAINT fk_aviso_lugar FOREIGN KEY (id_lugar) REFERENCES lugar_desembarque (id_lugar)
);

CREATE TABLE desembarque (
    id_desembarque        uuid              NOT NULL,      -- UUID v4 generado en el celular
    id_embarcacion        integer           NOT NULL,
    id_lugar              integer           NOT NULL,
    id_registrador        uuid              NOT NULL,
    id_aviso              integer,
    id_zona               integer           NOT NULL,
    id_arte               smallint          NOT NULL,
    fecha_zarpe           timestamptz       NOT NULL,
    fecha_hora_arribo     timestamptz       NOT NULL,
    tripulantes           smallint          NOT NULL,
    estado_validacion     estado_validacion,               -- NULL hasta validar en el servidor
    validacion_preliminar estado_validacion,               -- calculada sin conexión
    estado_registro       estado_registro   NOT NULL DEFAULT 'VIGENTE',
    registrado_en         timestamptz       NOT NULL,      -- hora del celular
    sincronizado_en       timestamptz       NOT NULL DEFAULT now(),
    motivo_anulacion      varchar(300),
    CONSTRAINT pk_desembarque PRIMARY KEY (id_desembarque),
    CONSTRAINT uq_desembarque_aviso UNIQUE (id_aviso),
    CONSTRAINT ck_desembarque_fechas CHECK (fecha_hora_arribo >= fecha_zarpe),
    CONSTRAINT ck_desembarque_tripulantes CHECK (tripulantes BETWEEN 1 AND 30),
    CONSTRAINT ck_desembarque_anulacion CHECK (estado_registro = 'VIGENTE' OR motivo_anulacion IS NOT NULL),
    CONSTRAINT fk_desembarque_embarcacion FOREIGN KEY (id_embarcacion) REFERENCES embarcacion (id_embarcacion),
    CONSTRAINT fk_desembarque_lugar FOREIGN KEY (id_lugar) REFERENCES lugar_desembarque (id_lugar),
    CONSTRAINT fk_desembarque_registrador FOREIGN KEY (id_registrador) REFERENCES usuario (id_usuario),
    CONSTRAINT fk_desembarque_aviso FOREIGN KEY (id_aviso) REFERENCES aviso_arribo (id_aviso),
    CONSTRAINT fk_desembarque_zona FOREIGN KEY (id_zona) REFERENCES zona_pesca (id_zona),
    CONSTRAINT fk_desembarque_arte FOREIGN KEY (id_arte) REFERENCES arte_pesca (id_arte)
);

CREATE TABLE detalle_desembarque (
    id_detalle      bigint        GENERATED ALWAYS AS IDENTITY,
    id_desembarque  uuid          NOT NULL,
    id_especie      integer       NOT NULL,
    peso_kg         numeric(10,2) NOT NULL,
    presentacion    varchar(20)   NOT NULL DEFAULT 'ENTERO',
    precio_playa_kg numeric(8,2),
    destino_saldo   destino_saldo,                     -- justificación del saldo (RF24)
    CONSTRAINT pk_detalle PRIMARY KEY (id_detalle),
    CONSTRAINT uq_detalle_especie UNIQUE (id_desembarque, id_especie),
    CONSTRAINT ck_detalle_peso CHECK (peso_kg > 0),
    CONSTRAINT ck_detalle_precio CHECK (precio_playa_kg IS NULL OR precio_playa_kg >= 0),
    CONSTRAINT fk_detalle_desembarque FOREIGN KEY (id_desembarque)
        REFERENCES desembarque (id_desembarque) ON DELETE CASCADE,
    CONSTRAINT fk_detalle_especie FOREIGN KEY (id_especie) REFERENCES especie (id_especie)
);

CREATE TABLE muestreo_talla (
    id_muestreo    bigint         GENERATED ALWAYS AS IDENTITY,
    id_detalle     bigint         NOT NULL,
    tallas_cm      numeric(5,1)[] NOT NULL,
    pct_bajo_talla numeric(5,2)   NOT NULL,
    CONSTRAINT pk_muestreo PRIMARY KEY (id_muestreo),
    CONSTRAINT uq_muestreo_detalle UNIQUE (id_detalle),
    CONSTRAINT ck_muestreo_tallas CHECK (cardinality(tallas_cm) >= 1),
    CONSTRAINT ck_muestreo_pct CHECK (pct_bajo_talla BETWEEN 0 AND 100),
    CONSTRAINT fk_muestreo_detalle FOREIGN KEY (id_detalle)
        REFERENCES detalle_desembarque (id_detalle) ON DELETE CASCADE
);

CREATE TABLE resultado_validacion (
    id_resultado   bigint            GENERATED ALWAYS AS IDENTITY,
    id_desembarque uuid              NOT NULL,
    regla          varchar(30)       NOT NULL,
    nivel          estado_validacion NOT NULL,
    mensaje        varchar(200)      NOT NULL,
    norma          varchar(60),
    evaluado_en    timestamptz       NOT NULL DEFAULT now(),
    CONSTRAINT pk_resultado PRIMARY KEY (id_resultado),
    CONSTRAINT ck_resultado_regla CHECK (regla IN ('PERMISO_VIGENTE', 'ESPECIE_ARTE',
                                         'VEDA', 'TALLA_MINIMA', 'ZONA_ARTE')),
    CONSTRAINT fk_resultado_desembarque FOREIGN KEY (id_desembarque)
        REFERENCES desembarque (id_desembarque) ON DELETE CASCADE
);

CREATE TABLE constancia (
    id_constancia  integer           GENERATED ALWAYS AS IDENTITY,
    id_desembarque uuid              NOT NULL,
    codigo         varchar(12)       NOT NULL,          -- SIR-000123
    hash_sha256    char(64)          NOT NULL,
    url_qr         varchar(200)      NOT NULL,
    estado         estado_constancia NOT NULL DEFAULT 'VIGENTE',
    fecha_emision  timestamptz       NOT NULL DEFAULT now(),
    CONSTRAINT pk_constancia PRIMARY KEY (id_constancia),
    CONSTRAINT uq_constancia_desembarque UNIQUE (id_desembarque),   -- cardinalidad 0..1
    CONSTRAINT uq_constancia_codigo UNIQUE (codigo),
    CONSTRAINT ck_constancia_hash CHECK (hash_sha256 ~ '^[0-9a-f]{64}$'),
    CONSTRAINT fk_constancia_desembarque FOREIGN KEY (id_desembarque) REFERENCES desembarque (id_desembarque)
);

CREATE TABLE evidencia_foto (
    id_foto        bigint       GENERATED ALWAYS AS IDENTITY,
    id_desembarque uuid         NOT NULL,
    url            varchar(200) NOT NULL,
    hash_sha256    char(64)     NOT NULL,
    tamano_kb      integer      NOT NULL,
    CONSTRAINT pk_foto PRIMARY KEY (id_foto),
    CONSTRAINT ck_foto_tamano CHECK (tamano_kb BETWEEN 1 AND 300),      -- RNF05
    CONSTRAINT fk_foto_desembarque FOREIGN KEY (id_desembarque)
        REFERENCES desembarque (id_desembarque) ON DELETE CASCADE
);

CREATE TABLE lote_destino (
    id_lote        bigint        GENERATED ALWAYS AS IDENTITY,
    id_detalle     bigint        NOT NULL,
    id_comprador   integer       NOT NULL,
    codigo_lote    varchar(16)   NOT NULL,              -- SIR-000123-L02
    hash_qr        char(64)      NOT NULL,
    peso_kg        numeric(10,2) NOT NULL,
    placa_vehiculo varchar(8),
    dni_conductor  char(8),
    estado         estado_lote   NOT NULL DEFAULT 'ASIGNADO',
    recibido_en    timestamptz,
    CONSTRAINT pk_lote PRIMARY KEY (id_lote),
    CONSTRAINT uq_lote_codigo UNIQUE (codigo_lote),
    CONSTRAINT ck_lote_peso CHECK (peso_kg > 0),
    CONSTRAINT ck_lote_conductor CHECK (dni_conductor IS NULL OR dni_conductor ~ '^[0-9]{8}$'),
    CONSTRAINT ck_lote_recepcion CHECK (estado <> 'RECIBIDO' OR recibido_en IS NOT NULL),
    CONSTRAINT fk_lote_detalle FOREIGN KEY (id_detalle) REFERENCES detalle_desembarque (id_detalle),
    CONSTRAINT fk_lote_comprador FOREIGN KEY (id_comprador) REFERENCES comprador (id_comprador)
);

CREATE TABLE notificacion (
    id_notificacion bigint            GENERATED ALWAYS AS IDENTITY,
    id_lote         bigint,
    id_constancia   integer,
    id_permiso      integer,
    tipo            tipo_notificacion NOT NULL,
    celular         varchar(9)        NOT NULL,
    estado          estado_envio      NOT NULL DEFAULT 'PENDIENTE',
    intentos        smallint          NOT NULL DEFAULT 0,
    creada_en       timestamptz       NOT NULL DEFAULT now(),
    enviada_en      timestamptz,
    CONSTRAINT pk_notificacion PRIMARY KEY (id_notificacion),
    CONSTRAINT ck_notificacion_origen CHECK (num_nonnulls(id_lote, id_constancia, id_permiso) <= 1),
    CONSTRAINT ck_notificacion_intentos CHECK (intentos BETWEEN 0 AND 5),
    CONSTRAINT fk_notificacion_lote FOREIGN KEY (id_lote) REFERENCES lote_destino (id_lote),
    CONSTRAINT fk_notificacion_constancia FOREIGN KEY (id_constancia) REFERENCES constancia (id_constancia),
    CONSTRAINT fk_notificacion_permiso FOREIGN KEY (id_permiso) REFERENCES permiso_pesca (id_permiso)
);

CREATE TABLE alerta (
    id_alerta      integer          GENERATED ALWAYS AS IDENTITY,
    id_desembarque uuid             NOT NULL,
    tipo           tipo_alerta      NOT NULL,
    prioridad      prioridad_alerta NOT NULL,
    estado         estado_alerta    NOT NULL DEFAULT 'PENDIENTE',
    creada_en      timestamptz      NOT NULL DEFAULT now(),
    atendida_en    timestamptz,
    CONSTRAINT pk_alerta PRIMARY KEY (id_alerta),
    CONSTRAINT ck_alerta_atencion CHECK (estado <> 'ATENDIDA' OR atendida_en IS NOT NULL),
    CONSTRAINT fk_alerta_desembarque FOREIGN KEY (id_desembarque) REFERENCES desembarque (id_desembarque)
);

CREATE TABLE inspeccion (
    id_inspeccion   integer              GENERATED ALWAYS AS IDENTITY,
    id_desembarque  uuid                 NOT NULL,
    id_alerta       integer,
    id_fiscalizador uuid                 NOT NULL,
    resultado       resultado_inspeccion NOT NULL,
    numero_acta     varchar(30),
    observacion     varchar(500),
    registrada_en   timestamptz          NOT NULL DEFAULT now(),
    CONSTRAINT pk_inspeccion PRIMARY KEY (id_inspeccion),
    CONSTRAINT uq_inspeccion_acta UNIQUE (numero_acta),
    CONSTRAINT ck_inspeccion_acta CHECK (resultado <> 'ACTA' OR numero_acta IS NOT NULL),
    CONSTRAINT fk_inspeccion_desembarque FOREIGN KEY (id_desembarque) REFERENCES desembarque (id_desembarque),
    CONSTRAINT fk_inspeccion_alerta FOREIGN KEY (id_alerta) REFERENCES alerta (id_alerta),
    CONSTRAINT fk_inspeccion_fiscalizador FOREIGN KEY (id_fiscalizador) REFERENCES usuario (id_usuario)
);

CREATE TABLE cierre_diario (
    id_cierre            integer       GENERATED ALWAYS AS IDENTITY,
    id_lugar             integer       NOT NULL,
    cerrado_por          uuid          NOT NULL,
    fecha                date          NOT NULL,
    kg_registrados       numeric(14,2) NOT NULL,
    kg_asignados         numeric(14,2) NOT NULL,
    kg_saldo_justificado numeric(14,2) NOT NULL,
    cerrado_en           timestamptz   NOT NULL DEFAULT now(),
    CONSTRAINT pk_cierre PRIMARY KEY (id_cierre),
    CONSTRAINT uq_cierre_lugar_fecha UNIQUE (id_lugar, fecha),
    -- RF24: el día solo se cierra si todo el saldo está justificado
    CONSTRAINT ck_cierre_cuadre CHECK (kg_registrados = kg_asignados + kg_saldo_justificado),
    CONSTRAINT fk_cierre_lugar FOREIGN KEY (id_lugar) REFERENCES lugar_desembarque (id_lugar),
    CONSTRAINT fk_cierre_usuario FOREIGN KEY (cerrado_por) REFERENCES usuario (id_usuario)
);

CREATE TABLE auditoria (
    id_auditoria          bigint       GENERATED ALWAYS AS IDENTITY,
    id_usuario            uuid,
    tabla                 varchar(40)  NOT NULL,
    operacion             char(1)      NOT NULL,
    id_registro           varchar(40)  NOT NULL,
    datos_antes_despues   jsonb        NOT NULL,
    fecha                 timestamptz  NOT NULL DEFAULT now(),
    CONSTRAINT pk_auditoria PRIMARY KEY (id_auditoria),
    CONSTRAINT ck_auditoria_operacion CHECK (operacion IN ('I', 'U', 'D')),
    CONSTRAINT fk_auditoria_usuario FOREIGN KEY (id_usuario) REFERENCES usuario (id_usuario)
);

-- ---------------------------------------------------------------------
-- 5. Tablas técnicas de seguridad (capítulo 8.4)
-- ---------------------------------------------------------------------
CREATE TABLE codigo_otp (
    id_otp      bigint      GENERATED ALWAYS AS IDENTITY,
    id_usuario  uuid        NOT NULL,
    codigo_hash char(64)    NOT NULL,                  -- SHA-256 del código de 6 dígitos
    expira_en   timestamptz NOT NULL,                  -- emisión + 5 minutos (RNF08)
    usado_en    timestamptz,
    intentos    smallint    NOT NULL DEFAULT 0,
    CONSTRAINT pk_otp PRIMARY KEY (id_otp),
    CONSTRAINT ck_otp_intentos CHECK (intentos BETWEEN 0 AND 5),
    CONSTRAINT fk_otp_usuario FOREIGN KEY (id_usuario) REFERENCES usuario (id_usuario) ON DELETE CASCADE
);

CREATE TABLE sesion (
    id_sesion     uuid        NOT NULL DEFAULT gen_random_uuid(),
    id_usuario    uuid        NOT NULL,
    id_dispositivo varchar(64),                        -- celular del registrador
    refresh_hash  char(64)    NOT NULL,                -- token de renovación (hash)
    creada_en     timestamptz NOT NULL DEFAULT now(),
    expira_en     timestamptz NOT NULL,
    revocada_en   timestamptz,
    CONSTRAINT pk_sesion PRIMARY KEY (id_sesion),
    CONSTRAINT uq_sesion_refresh UNIQUE (refresh_hash),
    CONSTRAINT fk_sesion_usuario FOREIGN KEY (id_usuario) REFERENCES usuario (id_usuario) ON DELETE CASCADE
);

COMMENT ON TABLE desembarque IS 'Llegada de una faena a un lugar de desembarque. PK UUID generado en el celular (RNF07).';
COMMENT ON TABLE auditoria  IS 'Bitácora inmutable (RF23, RNF10). Solo se inserta mediante triggers.';
