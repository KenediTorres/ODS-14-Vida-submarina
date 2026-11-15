-- =====================================================================
-- SIRDEPA · sirdepa_schema.sql · Script completo de la base de datos
-- PostgreSQL 16 + PostGIS 3. Orden: esquema, programación, índices, seguridad.
-- Ejecutar con: psql -d sirdepa -v ON_ERROR_STOP=1 -f sirdepa_schema.sql
-- =====================================================================

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

-- =====================================================================
-- SIRDEPA · 02_programacion.sql
-- Procedimientos almacenados, funciones, vistas y triggers aplicados al
-- proceso principal: registrar desembarque -> validar -> constancia ->
-- lotes -> verificación pública -> cierre diario.
-- =====================================================================
SET search_path = sirdepa, public;

-- ---------------------------------------------------------------------
-- 1. Registro idempotente del desembarque (RF06, RF07, RF12, RNF07)
--    La API envía el JSON recibido del celular. Si el UUID ya existe
--    (reintento tras un corte de red), no duplica: devuelve creado=false.
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION fn_registrar_desembarque(p_payload jsonb, p_id_registrador uuid)
RETURNS TABLE (id_desembarque uuid, creado boolean)
LANGUAGE plpgsql AS $$
DECLARE
    v_id uuid := (p_payload->>'id')::uuid;
    v_filas integer;
BEGIN
    INSERT INTO desembarque AS d (id_desembarque, id_embarcacion, id_lugar, id_registrador,
           id_aviso, id_zona, id_arte, fecha_zarpe, fecha_hora_arribo, tripulantes,
           validacion_preliminar, registrado_en)
    VALUES (v_id,
            (p_payload->>'idEmbarcacion')::int,
            (p_payload->>'idLugar')::int,
            p_id_registrador,
            NULLIF(p_payload->>'idAviso', '')::int,
            (p_payload->>'idZona')::int,
            (p_payload->>'idArte')::smallint,
            (p_payload->>'fechaZarpe')::timestamptz,
            (p_payload->>'fechaHoraArribo')::timestamptz,
            (p_payload->>'tripulantes')::smallint,
            NULLIF(p_payload->>'validacionPreliminar', '')::estado_validacion,
            (p_payload->>'registradoEn')::timestamptz)
    ON CONFLICT ON CONSTRAINT pk_desembarque DO NOTHING;

    GET DIAGNOSTICS v_filas = ROW_COUNT;

    IF v_filas = 1 THEN                                   -- primera vez: guarda el detalle
        INSERT INTO detalle_desembarque (id_desembarque, id_especie, peso_kg, presentacion, precio_playa_kg)
        SELECT v_id, (e->>'idEspecie')::int, (e->>'pesoKg')::numeric,
               COALESCE(e->>'presentacion', 'ENTERO'), NULLIF(e->>'precioPlayaKg', '')::numeric
        FROM jsonb_array_elements(p_payload->'detalles') AS e;

        IF p_payload->>'idAviso' IS NOT NULL THEN
            UPDATE aviso_arribo SET estado = 'VINCULADO'
            WHERE id_aviso = (p_payload->>'idAviso')::int;
        END IF;
    END IF;

    RETURN QUERY SELECT v_id, (v_filas = 1);
END;
$$;

-- ---------------------------------------------------------------------
-- 2. Persistir el resultado del motor de reglas y clasificar (RF10, Tabla 9)
--    El motor (patrón Strategy, capa de dominio) evalúa las 5 reglas; este
--    procedimiento guarda cada resultado y deriva el estado final en una
--    sola transacción: el peor nivel gana.
-- ---------------------------------------------------------------------
CREATE OR REPLACE PROCEDURE sp_guardar_validacion(p_id_desembarque uuid, p_resultados jsonb)
LANGUAGE plpgsql AS $$
DECLARE
    v_estado estado_validacion;
BEGIN
    DELETE FROM resultado_validacion WHERE id_desembarque = p_id_desembarque;  -- revalidación

    INSERT INTO resultado_validacion (id_desembarque, regla, nivel, mensaje, norma)
    SELECT p_id_desembarque, r->>'regla', (r->>'nivel')::estado_validacion, r->>'mensaje', r->>'norma'
    FROM jsonb_array_elements(p_resultados) AS r;

    SELECT CASE
             WHEN bool_or(nivel = 'NO_CONFORME') THEN 'NO_CONFORME'
             WHEN bool_or(nivel = 'OBSERVADO')   THEN 'OBSERVADO'
             ELSE 'CONFORME' END::estado_validacion
      INTO v_estado
      FROM resultado_validacion
     WHERE id_desembarque = p_id_desembarque;

    UPDATE desembarque SET estado_validacion = v_estado
     WHERE id_desembarque = p_id_desembarque;            -- dispara trg_alerta_validacion
END;
$$;

-- ---------------------------------------------------------------------
-- 3. Emitir constancia (RF13): solo Conforme u Observado
-- ---------------------------------------------------------------------
CREATE SEQUENCE IF NOT EXISTS seq_constancia;

CREATE OR REPLACE FUNCTION fn_emitir_constancia(p_id_desembarque uuid, p_url_base text)
RETURNS varchar
LANGUAGE plpgsql AS $$
DECLARE
    v_estado estado_validacion;
    v_codigo varchar(12);
    v_hash   char(64);
BEGIN
    SELECT estado_validacion INTO v_estado
      FROM desembarque WHERE id_desembarque = p_id_desembarque AND estado_registro = 'VIGENTE';

    IF v_estado IS NULL OR v_estado = 'NO_CONFORME' THEN
        RAISE EXCEPTION 'No se emite constancia: desembarque % con estado %', p_id_desembarque, v_estado
              USING ERRCODE = 'P0001';
    END IF;

    v_codigo := 'SIR-' || lpad(nextval('seq_constancia')::text, 6, '0');
    v_hash   := encode(digest(p_id_desembarque::text || '|' || v_codigo || '|' || v_estado, 'sha256'), 'hex');

    INSERT INTO constancia (id_desembarque, codigo, hash_sha256, url_qr)
    VALUES (p_id_desembarque, v_codigo, v_hash, p_url_base || '/v/' || v_codigo || '?h=' || v_hash)
    ON CONFLICT ON CONSTRAINT uq_constancia_desembarque DO NOTHING;

    SELECT codigo INTO v_codigo FROM constancia WHERE id_desembarque = p_id_desembarque;
    RETURN v_codigo;
END;
$$;
-- ---------------------------------------------------------------------
-- 4. Asignar un lote a un comprador (RF14) con control de concurrencia:
--    bloquea la fila del detalle (FOR UPDATE) para que dos registradores
--    no asignen el mismo saldo a la vez.
-- ---------------------------------------------------------------------
CREATE OR REPLACE PROCEDURE sp_asignar_lote(
    p_id_detalle     bigint,
    p_id_comprador   integer,
    p_peso_kg        numeric,
    p_placa          varchar,
    p_dni_conductor  char(8),
    INOUT p_codigo_lote varchar DEFAULT NULL)
LANGUAGE plpgsql AS $$
DECLARE
    v_peso       numeric;
    v_asignado   numeric;
    v_constancia varchar(12);
    v_n          integer;
BEGIN
    SELECT dd.peso_kg, c.codigo
      INTO v_peso, v_constancia
      FROM detalle_desembarque dd
      JOIN desembarque d  ON d.id_desembarque = dd.id_desembarque
      LEFT JOIN constancia c ON c.id_desembarque = d.id_desembarque AND c.estado = 'VIGENTE'
     WHERE dd.id_detalle = p_id_detalle
       FOR UPDATE OF dd;                                   -- bloqueo pesimista de la fila

    IF v_constancia IS NULL THEN
        RAISE EXCEPTION 'Sin constancia vigente: no se asignan lotes (No conforme o anulado)';
    END IF;

    SELECT COALESCE(sum(peso_kg), 0) INTO v_asignado
      FROM lote_destino WHERE id_detalle = p_id_detalle AND estado <> 'ANULADO';

    IF v_asignado + p_peso_kg > v_peso THEN
        RAISE EXCEPTION 'Saldo insuficiente: disponible % kg, solicitado % kg', v_peso - v_asignado, p_peso_kg;
    END IF;

    SELECT count(*) + 1 INTO v_n
      FROM lote_destino l JOIN detalle_desembarque dd USING (id_detalle)
     WHERE dd.id_desembarque = (SELECT id_desembarque FROM detalle_desembarque WHERE id_detalle = p_id_detalle);

    p_codigo_lote := v_constancia || '-L' || lpad(v_n::text, 2, '0');

    INSERT INTO lote_destino (id_detalle, id_comprador, codigo_lote, hash_qr, peso_kg, placa_vehiculo, dni_conductor)
    VALUES (p_id_detalle, p_id_comprador, p_codigo_lote,
            encode(digest(p_codigo_lote || '|' || p_id_comprador || '|' || p_peso_kg, 'sha256'), 'hex'),
            p_peso_kg, p_placa, p_dni_conductor);
END;
$$;

-- ---------------------------------------------------------------------
-- 5. Cierre diario (RF24): no cierra si queda saldo sin justificar
-- ---------------------------------------------------------------------
CREATE OR REPLACE PROCEDURE sp_cerrar_dia(p_id_lugar integer, p_fecha date, p_usuario uuid)
LANGUAGE plpgsql AS $$
DECLARE
    v_registrado numeric; v_asignado numeric; v_justificado numeric;
BEGIN
    SELECT COALESCE(sum(dd.peso_kg), 0),
           COALESCE(sum(l.kg), 0),
           COALESCE(sum(CASE WHEN dd.destino_saldo IS NOT NULL
                             THEN dd.peso_kg - COALESCE(l.kg, 0) END), 0)
      INTO v_registrado, v_asignado, v_justificado
      FROM desembarque d
      JOIN detalle_desembarque dd ON dd.id_desembarque = d.id_desembarque
      LEFT JOIN LATERAL (SELECT sum(peso_kg) AS kg FROM lote_destino
                          WHERE id_detalle = dd.id_detalle AND estado <> 'ANULADO') l ON true
     WHERE d.id_lugar = p_id_lugar
       AND d.estado_registro = 'VIGENTE'
       AND d.fecha_hora_arribo >= p_fecha
       AND d.fecha_hora_arribo <  p_fecha + 1;

    IF v_registrado <> v_asignado + v_justificado THEN
        RAISE EXCEPTION 'Saldo sin justificar: % kg', v_registrado - v_asignado - v_justificado;
    END IF;

    INSERT INTO cierre_diario (id_lugar, cerrado_por, fecha, kg_registrados, kg_asignados, kg_saldo_justificado)
    VALUES (p_id_lugar, p_usuario, p_fecha, v_registrado, v_asignado, v_justificado);
END;
$$;

-- ---------------------------------------------------------------------
-- 6. Vistas
-- ---------------------------------------------------------------------
-- 6.1 Verificación pública (RF16, RNF09): sin DNI, nombres ni celulares
CREATE OR REPLACE VIEW v_verificacion_publica AS
SELECT c.codigo,
       'CONSTANCIA'::text                                   AS tipo,
       c.hash_sha256                                        AS hash,
       CASE WHEN c.estado = 'VIGENTE' AND d.estado_registro = 'VIGENTE'
            THEN 'VÁLIDA' ELSE 'NO VÁLIDA' END              AS validez,
       d.estado_validacion::text                            AS resultado,
       e.matricula,
       ld.nombre                                            AS lugar,
       d.fecha_hora_arribo                                  AS fecha,
       (SELECT string_agg(es.codigo_fao || ' ' || dd.peso_kg || ' kg', ', ')
          FROM detalle_desembarque dd JOIN especie es USING (id_especie)
         WHERE dd.id_desembarque = d.id_desembarque)        AS contenido
FROM constancia c
JOIN desembarque d        ON d.id_desembarque = c.id_desembarque
JOIN embarcacion e        ON e.id_embarcacion = d.id_embarcacion
JOIN lugar_desembarque ld ON ld.id_lugar = d.id_lugar
UNION ALL
SELECT l.codigo_lote, 'LOTE', l.hash_qr,
       CASE WHEN l.estado <> 'ANULADO' AND d.estado_registro = 'VIGENTE'
            THEN 'VÁLIDA' ELSE 'NO VÁLIDA' END,
       d.estado_validacion::text, e.matricula, ld.nombre, d.fecha_hora_arribo,
       es.codigo_fao || ' ' || l.peso_kg || ' kg'
FROM lote_destino l
JOIN detalle_desembarque dd ON dd.id_detalle = l.id_detalle
JOIN especie es             ON es.id_especie = dd.id_especie
JOIN desembarque d          ON d.id_desembarque = dd.id_desembarque
JOIN embarcacion e          ON e.id_embarcacion = d.id_embarcacion
JOIN lugar_desembarque ld   ON ld.id_lugar = d.id_lugar;

-- Función pública: compara el hash del QR con el almacenado
CREATE OR REPLACE FUNCTION fn_verificar(p_codigo varchar, p_hash char(64))
RETURNS jsonb
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = sirdepa, public AS $$
    SELECT COALESCE(
        (SELECT jsonb_build_object(
                  'codigo', codigo, 'tipo', tipo,
                  'validez', CASE WHEN hash = p_hash THEN validez ELSE 'NO VÁLIDA' END,
                  'resultado', resultado, 'matricula', matricula, 'lugar', lugar,
                  'fecha', fecha, 'contenido', contenido)
           FROM v_verificacion_publica WHERE codigo = p_codigo),
        jsonb_build_object('codigo', p_codigo, 'validez', 'NO VÁLIDA', 'motivo', 'Código inexistente'));
$$;

-- 6.2 Tablero del DPA (RF18): kilos por día, especie, embarcación y arte
CREATE MATERIALIZED VIEW mv_tablero_diario AS
SELECT d.id_lugar,
       (d.fecha_hora_arribo AT TIME ZONE 'America/Lima')::date AS fecha,
       dd.id_especie,
       d.id_arte,
       count(DISTINCT d.id_desembarque)                         AS desembarques,
       sum(dd.peso_kg)                                          AS kg,
       count(DISTINCT d.id_desembarque) FILTER (WHERE d.estado_validacion = 'CONFORME') AS conformes
FROM desembarque d
JOIN detalle_desembarque dd ON dd.id_desembarque = d.id_desembarque
WHERE d.estado_registro = 'VIGENTE'
GROUP BY 1, 2, 3, 4
WITH NO DATA;
CREATE UNIQUE INDEX ux_mv_tablero ON mv_tablero_diario (id_lugar, fecha, id_especie, id_arte);
-- Se refresca cada 5 minutos sin bloquear lecturas:
-- REFRESH MATERIALIZED VIEW CONCURRENTLY sirdepa.mv_tablero_diario;

-- 6.3 Avance de capturas frente al límite (RF25): alertas al 80 % y 100 %
--     Lee la vista materializada del tablero (se actualiza cada 5 minutos),
--     no millones de filas de detalle.
CREATE OR REPLACE VIEW v_avance_cuotas AS
SELECT lc.id_limite, es.codigo_fao, es.nombre_comun, lc.periodo_inicio, lc.periodo_fin,
       lc.limite_kg,
       COALESCE(a.kg, 0)                                          AS acumulado_kg,
       round(100 * COALESCE(a.kg, 0) / lc.limite_kg, 1)           AS avance_pct,
       CASE WHEN COALESCE(a.kg, 0) >= lc.limite_kg       THEN 'LÍMITE ALCANZADO'
            WHEN COALESCE(a.kg, 0) >= 0.8 * lc.limite_kg THEN 'ALERTA 80 %'
            ELSE 'NORMAL' END                                      AS nivel
FROM limite_captura lc
JOIN especie es ON es.id_especie = lc.id_especie
LEFT JOIN LATERAL (
     SELECT sum(t.kg) AS kg
       FROM mv_tablero_diario t
      WHERE t.id_especie = lc.id_especie
        AND t.fecha BETWEEN lc.periodo_inicio AND lc.periodo_fin) a ON true;

-- 6.4 Archivo para el SITRAPESCA (RF20, RD05)
CREATE OR REPLACE VIEW v_exportacion_sitrapesca AS
SELECT ld.codigo                  AS punto_desembarque,
       e.matricula,
       d.id_desembarque           AS codigo_faena,
       d.fecha_hora_arribo        AS fecha_hora_descarga,
       es.codigo_fao              AS especie,
       l.peso_kg,
       l.placa_vehiculo,
       l.dni_conductor,
       c.tipo_doc || ' ' || c.num_doc AS destino
FROM desembarque d
JOIN lugar_desembarque ld   ON ld.id_lugar = d.id_lugar
JOIN embarcacion e          ON e.id_embarcacion = d.id_embarcacion
JOIN detalle_desembarque dd ON dd.id_desembarque = d.id_desembarque
JOIN especie es             ON es.id_especie = dd.id_especie
JOIN lote_destino l         ON l.id_detalle = dd.id_detalle AND l.estado <> 'ANULADO'
JOIN comprador c            ON c.id_comprador = l.id_comprador
WHERE d.estado_registro = 'VIGENTE';

-- ---------------------------------------------------------------------
-- 7. Triggers
-- ---------------------------------------------------------------------
-- 7.1 Auditoría genérica (RF23, RNF10). La API fija el usuario por
--     transacción: SET LOCAL sirdepa.id_usuario = '<uuid>';
CREATE OR REPLACE FUNCTION fn_auditar() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path = sirdepa, public AS $$
DECLARE
    v_usuario uuid := NULLIF(current_setting('sirdepa.id_usuario', true), '')::uuid;
    v_id text;
BEGIN
    v_id := COALESCE(to_jsonb(NEW), to_jsonb(OLD)) ->> TG_ARGV[0];
    INSERT INTO auditoria (id_usuario, tabla, operacion, id_registro, datos_antes_despues)
    VALUES (v_usuario, TG_TABLE_NAME, left(TG_OP, 1), v_id,
            jsonb_build_object('antes', to_jsonb(OLD), 'despues', to_jsonb(NEW)));
    RETURN NULL;
END;
$$;

CREATE TRIGGER trg_aud_desembarque AFTER INSERT OR UPDATE OR DELETE ON desembarque
    FOR EACH ROW EXECUTE FUNCTION fn_auditar('id_desembarque');
CREATE TRIGGER trg_aud_lote AFTER INSERT OR UPDATE OR DELETE ON lote_destino
    FOR EACH ROW EXECUTE FUNCTION fn_auditar('id_lote');
CREATE TRIGGER trg_aud_constancia AFTER INSERT OR UPDATE OR DELETE ON constancia
    FOR EACH ROW EXECUTE FUNCTION fn_auditar('id_constancia');
CREATE TRIGGER trg_aud_permiso AFTER INSERT OR UPDATE OR DELETE ON permiso_pesca
    FOR EACH ROW EXECUTE FUNCTION fn_auditar('id_permiso');
CREATE TRIGGER trg_aud_usuario AFTER INSERT OR UPDATE OR DELETE ON usuario
    FOR EACH ROW EXECUTE FUNCTION fn_auditar('id_usuario');

-- 7.2 La bitácora es inmutable: nadie la modifica ni la borra
CREATE OR REPLACE FUNCTION fn_auditoria_inmutable() RETURNS trigger
LANGUAGE plpgsql AS $$
BEGIN
    RAISE EXCEPTION 'La bitácora de auditoría es inmutable (operación % rechazada)', TG_OP;
END;
$$;
CREATE TRIGGER trg_auditoria_inmutable BEFORE UPDATE OR DELETE ON auditoria
    FOR EACH ROW EXECUTE FUNCTION fn_auditoria_inmutable();

-- 7.3 Alerta automática al fiscalizador según el resultado (RF22, Tabla 9)
CREATE OR REPLACE FUNCTION fn_alerta_validacion() RETURNS trigger
LANGUAGE plpgsql AS $$
BEGIN
    IF NEW.estado_validacion IN ('NO_CONFORME', 'OBSERVADO')
       AND NOT EXISTS (SELECT 1 FROM alerta
                        WHERE id_desembarque = NEW.id_desembarque AND estado <> 'ATENDIDA') THEN
        INSERT INTO alerta (id_desembarque, tipo, prioridad)
        VALUES (NEW.id_desembarque,
                NEW.estado_validacion::text::tipo_alerta,
                CASE NEW.estado_validacion WHEN 'NO_CONFORME' THEN 'ALTA' ELSE 'MEDIA' END::prioridad_alerta);
    END IF;
    RETURN NEW;
END;
$$;
CREATE TRIGGER trg_alerta_validacion
    AFTER UPDATE OF estado_validacion ON desembarque
    FOR EACH ROW WHEN (NEW.estado_validacion IS DISTINCT FROM OLD.estado_validacion)
    EXECUTE FUNCTION fn_alerta_validacion();

-- 7.4 Al anular un desembarque, su constancia y lotes pasan a NO VÁLIDA (RF23)
CREATE OR REPLACE FUNCTION fn_anular_derivados() RETURNS trigger
LANGUAGE plpgsql AS $$
BEGIN
    UPDATE constancia SET estado = 'ANULADA' WHERE id_desembarque = NEW.id_desembarque;
    UPDATE lote_destino SET estado = 'ANULADO'
     WHERE id_detalle IN (SELECT id_detalle FROM detalle_desembarque
                           WHERE id_desembarque = NEW.id_desembarque);
    RETURN NEW;
END;
$$;
CREATE TRIGGER trg_anular_derivados
    AFTER UPDATE OF estado_registro ON desembarque
    FOR EACH ROW WHEN (NEW.estado_registro = 'ANULADO' AND OLD.estado_registro = 'VIGENTE')
    EXECUTE FUNCTION fn_anular_derivados();

-- 7.5 Defensa en profundidad del saldo de lotes (RF14)
CREATE OR REPLACE FUNCTION fn_control_saldo_lote() RETURNS trigger
LANGUAGE plpgsql AS $$
DECLARE v_peso numeric; v_otros numeric;
BEGIN
    SELECT peso_kg INTO v_peso FROM detalle_desembarque WHERE id_detalle = NEW.id_detalle;
    SELECT COALESCE(sum(peso_kg), 0) INTO v_otros FROM lote_destino
     WHERE id_detalle = NEW.id_detalle AND estado <> 'ANULADO' AND id_lote <> NEW.id_lote;
    IF NEW.estado <> 'ANULADO' AND v_otros + NEW.peso_kg > v_peso THEN
        RAISE EXCEPTION 'La suma de lotes (% kg) supera el peso registrado (% kg)', v_otros + NEW.peso_kg, v_peso;
    END IF;
    RETURN NEW;
END;
$$;
CREATE TRIGGER trg_control_saldo_lote
    BEFORE INSERT OR UPDATE OF peso_kg, estado ON lote_destino
    FOR EACH ROW EXECUTE FUNCTION fn_control_saldo_lote();

-- 7.6 Máximo tres fotografías por desembarque (RF11)
CREATE OR REPLACE FUNCTION fn_max_fotos() RETURNS trigger
LANGUAGE plpgsql AS $$
BEGIN
    IF (SELECT count(*) FROM evidencia_foto WHERE id_desembarque = NEW.id_desembarque) >= 3 THEN
        RAISE EXCEPTION 'Máximo 3 fotografías por desembarque';
    END IF;
    RETURN NEW;
END;
$$;
CREATE TRIGGER trg_max_fotos BEFORE INSERT ON evidencia_foto
    FOR EACH ROW EXECUTE FUNCTION fn_max_fotos();

-- 7.7 Marca de actualización del catálogo para la sincronización delta (cap. 8)
CREATE OR REPLACE FUNCTION fn_marcar_actualizado() RETURNS trigger
LANGUAGE plpgsql AS $$
BEGIN
    NEW.actualizado_en := now();
    RETURN NEW;
END;
$$;
CREATE TRIGGER trg_upd_especie  BEFORE UPDATE ON especie        FOR EACH ROW EXECUTE FUNCTION fn_marcar_actualizado();
CREATE TRIGGER trg_upd_talla    BEFORE UPDATE ON talla_minima   FOR EACH ROW EXECUTE FUNCTION fn_marcar_actualizado();
CREATE TRIGGER trg_upd_veda     BEFORE UPDATE ON veda           FOR EACH ROW EXECUTE FUNCTION fn_marcar_actualizado();
CREATE TRIGGER trg_upd_limite   BEFORE UPDATE ON limite_captura FOR EACH ROW EXECUTE FUNCTION fn_marcar_actualizado();
CREATE TRIGGER trg_upd_permiso  BEFORE UPDATE ON permiso_pesca  FOR EACH ROW EXECUTE FUNCTION fn_marcar_actualizado();
CREATE TRIGGER trg_upd_emb      BEFORE UPDATE ON embarcacion    FOR EACH ROW EXECUTE FUNCTION fn_marcar_actualizado();

-- =====================================================================
-- SIRDEPA · 03_indices.sql
-- Índices non-clustered (B-tree, parciales, de cobertura, BRIN y GiST)
-- y agrupamiento físico (equivalente PostgreSQL del índice clustered).
-- Las PK y UNIQUE ya crean su propio índice B-tree non-clustered.
-- =====================================================================
SET search_path = sirdepa, public;

-- 1. Índice de agrupamiento: tablero diario y cierre del DPA (RF18, RF24)
CREATE INDEX ix_desembarque_lugar_arribo
    ON desembarque (id_lugar, fecha_hora_arribo);
ALTER TABLE desembarque SET (fillfactor = 90);       -- espacio para actualizaciones HOT
CLUSTER desembarque USING ix_desembarque_lugar_arribo;

-- Los detalles de un desembarque quedan físicamente contiguos
CREATE INDEX ix_detalle_desembarque ON detalle_desembarque (id_desembarque);
CLUSTER detalle_desembarque USING ix_detalle_desembarque;

-- 2. Historial del armador (RF21): últimas faenas de una embarcación
CREATE INDEX ix_desembarque_embarcacion_arribo
    ON desembarque (id_embarcacion, fecha_hora_arribo DESC);

-- 3. Detalle por especie (reportes IMARPE, RF19): índice de cobertura
CREATE INDEX ix_detalle_especie_cobertura
    ON detalle_desembarque (id_especie) INCLUDE (id_desembarque, peso_kg);

-- Vista materializada del tablero: búsqueda por especie y periodo (RF25)
CREATE INDEX ix_mv_tablero_especie_fecha
    ON mv_tablero_diario (id_especie, fecha) INCLUDE (kg);

-- 4. Lotes: claves foráneas consultadas en cada verificación y cierre
CREATE INDEX ix_lote_detalle   ON lote_destino (id_detalle);
CREATE INDEX ix_lote_comprador ON lote_destino (id_comprador);
-- uq_lote_codigo (UNIQUE) atiende la verificación pública por QR (RF16)

-- 5. Bandeja del fiscalizador (RF22): índice parcial, solo alertas abiertas
CREATE INDEX ix_alerta_pendiente
    ON alerta (prioridad, creada_en)
    WHERE estado <> 'ATENDIDA';

-- 6. Cola de SMS del worker: índice parcial de pendientes
CREATE INDEX ix_notificacion_pendiente
    ON notificacion (creada_en)
    WHERE estado = 'PENDIENTE';

-- 7. Resultados y fotos por desembarque (FK)
CREATE INDEX ix_resultado_desembarque ON resultado_validacion (id_desembarque);
CREATE INDEX ix_foto_desembarque      ON evidencia_foto (id_desembarque);
CREATE INDEX ix_alerta_desembarque    ON alerta (id_desembarque);

-- 8. Bitácora de auditoría: BRIN por fecha (tabla de solo inserción)
CREATE INDEX brin_auditoria_fecha ON auditoria USING brin (fecha) WITH (pages_per_range = 32);
CREATE INDEX ix_auditoria_registro ON auditoria (tabla, id_registro);

-- 9. Catálogo y seguridad
CREATE INDEX gist_zona_geom      ON zona_pesca USING gist (geom);
CREATE INDEX ix_veda_especie     ON veda (id_especie, fecha_inicio, fecha_fin);
CREATE INDEX ix_permiso_emb_venc ON permiso_pesca (id_embarcacion, fecha_vencimiento DESC);
CREATE INDEX ix_otp_usuario      ON codigo_otp (id_usuario, expira_en DESC);
CREATE INDEX ix_sesion_usuario   ON sesion (id_usuario) WHERE revocada_en IS NULL;

ANALYZE;

-- =====================================================================
-- SIRDEPA · 04_seguridad.sql
-- Roles de base de datos con mínimo privilegio, permisos y seguridad a
-- nivel de fila (RLS). Las contraseñas reales se cargan desde el gestor
-- de secretos; aquí se muestran como marcadores.
-- =====================================================================
SET search_path = sirdepa, public;

-- 1. Roles y cuentas de servicio. Se crean solo si no existen, para poder ejecutar el script de nuevo.
DO $$ BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'sirdepa_owner') THEN CREATE ROLE sirdepa_owner NOLOGIN; END IF;  -- dueño de los objetos
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'sirdepa_app') THEN                 -- API REST (pool de conexiones)
        CREATE ROLE sirdepa_app LOGIN PASSWORD 'CAMBIAR_EN_GESTOR_DE_SECRETOS' CONNECTION LIMIT 60; END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'sirdepa_reportes') THEN CREATE ROLE sirdepa_reportes LOGIN PASSWORD 'CAMBIAR_EN_GESTOR_DE_SECRETOS' CONNECTION LIMIT 10; END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'sirdepa_verificacion') THEN CREATE ROLE sirdepa_verificacion LOGIN PASSWORD 'CAMBIAR_EN_GESTOR_DE_SECRETOS' CONNECTION LIMIT 20; END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'sirdepa_backup') THEN CREATE ROLE sirdepa_backup LOGIN REPLICATION PASSWORD 'CAMBIAR_EN_GESTOR_DE_SECRETOS'; END IF;
END $$;

ALTER SCHEMA sirdepa OWNER TO sirdepa_owner;
DO $$
DECLARE r record;
BEGIN
    -- tablas, vistas y vistas materializadas (las secuencias IDENTITY siguen a su tabla)
    FOR r IN SELECT c.relname, c.relkind FROM pg_class c
              JOIN pg_namespace n ON n.oid = c.relnamespace
             WHERE n.nspname = 'sirdepa' AND c.relkind IN ('r', 'v', 'm') LOOP
        EXECUTE format('ALTER %s sirdepa.%I OWNER TO sirdepa_owner',
                       CASE r.relkind WHEN 'v' THEN 'VIEW' WHEN 'm' THEN 'MATERIALIZED VIEW'
                                      ELSE 'TABLE' END, r.relname);
    END LOOP;
    -- funciones y procedimientos (las SECURITY DEFINER se ejecutan como sirdepa_owner)
    FOR r IN SELECT p.oid::regprocedure AS firma FROM pg_proc p
              JOIN pg_namespace n ON n.oid = p.pronamespace WHERE n.nspname = 'sirdepa' LOOP
        EXECUTE format('ALTER ROUTINE %s OWNER TO sirdepa_owner', r.firma);
    END LOOP;
END $$;
ALTER SEQUENCE seq_constancia OWNER TO sirdepa_owner;

-- 2. Nadie crea objetos en public ni accede por defecto
REVOKE ALL ON SCHEMA public FROM PUBLIC;
REVOKE ALL ON ALL TABLES IN SCHEMA sirdepa FROM PUBLIC;
REVOKE EXECUTE ON ALL FUNCTIONS IN SCHEMA sirdepa FROM PUBLIC;

-- 3. API: lectura y escritura de datos operativos, sin DDL ni borrado
GRANT USAGE ON SCHEMA sirdepa TO sirdepa_app, sirdepa_reportes, sirdepa_verificacion;
GRANT SELECT, INSERT, UPDATE ON ALL TABLES IN SCHEMA sirdepa TO sirdepa_app;
REVOKE INSERT, UPDATE ON auditoria FROM sirdepa_app;      -- solo la escriben los triggers
GRANT USAGE ON ALL SEQUENCES IN SCHEMA sirdepa TO sirdepa_app;
GRANT EXECUTE ON FUNCTION fn_registrar_desembarque(jsonb, uuid),
                          fn_emitir_constancia(uuid, text),
                          fn_verificar(varchar, char) TO sirdepa_app;
GRANT EXECUTE ON PROCEDURE sp_guardar_validacion(uuid, jsonb),
                           sp_asignar_lote(bigint, integer, numeric, varchar, char, varchar),
                           sp_cerrar_dia(integer, date, uuid) TO sirdepa_app;

-- 4. Reportes: solo vistas agregadas, sin tablas con datos personales
GRANT SELECT ON mv_tablero_diario, v_avance_cuotas, v_exportacion_sitrapesca TO sirdepa_reportes;

-- 5. Verificación pública: solo puede ejecutar fn_verificar
GRANT EXECUTE ON FUNCTION fn_verificar(varchar, char) TO sirdepa_verificacion;

-- 6. Seguridad a nivel de fila: cada usuario del DPA ve solo su lugar.
--    La API fija el contexto en cada transacción:
--    SET LOCAL sirdepa.rol = 'REGISTRADOR'; SET LOCAL sirdepa.id_lugar = '12';
ALTER TABLE desembarque ENABLE ROW LEVEL SECURITY;

CREATE POLICY p_desembarque_lugar ON desembarque
    FOR ALL TO sirdepa_app
    USING (
        current_setting('sirdepa.rol', true) IN ('ADMIN_SISTEMA', 'FISCALIZADOR', 'ANALISTA')
        OR id_lugar = NULLIF(current_setting('sirdepa.id_lugar', true), '')::int
        OR (current_setting('sirdepa.rol', true) = 'ARMADOR'
            AND id_embarcacion IN (SELECT e.id_embarcacion FROM embarcacion e
                                     JOIN armador a ON a.id_armador = e.id_armador
                                    WHERE a.id_usuario = NULLIF(current_setting('sirdepa.id_usuario', true), '')::uuid)))
    WITH CHECK (
        id_lugar = NULLIF(current_setting('sirdepa.id_lugar', true), '')::int
        OR current_setting('sirdepa.rol', true) = 'ADMIN_SISTEMA');

-- 7. Parámetros del servidor (postgresql.conf / pg_hba.conf), como referencia:
--    ssl = on ; ssl_min_protocol_version = 'TLSv1.2'
--    password_encryption = scram-sha-256 ; log_connections = on
--    hostssl  sirdepa  sirdepa_app,sirdepa_reportes,sirdepa_verificacion  10.20.1.0/24  scram-sha-256
--    hostssl  replication  sirdepa_backup  10.20.9.10/32  scram-sha-256
--    host     all  all  0.0.0.0/0  reject

