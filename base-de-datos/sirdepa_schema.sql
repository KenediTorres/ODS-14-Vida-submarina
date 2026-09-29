-- =====================================================================
--  SIRDEPA - Sistema de Registro de Desembarque Pesquero Artesanal
--  ODS 14: Vida submarina · Análisis y Diseño de Software · 2026
--  Motor: PostgreSQL 16 + PostGIS 3
--
--  Modelo relacional lógico derivado del modelo entidad-relación
--  (Figura 7) y del diagrama de clases (Figura 9) del informe.
--  Entidad central: DESEMBARQUE.
--
--  Uso:
--    createdb sirdepa
--    psql -d sirdepa -f sirdepa_schema.sql
-- =====================================================================

BEGIN;

CREATE EXTENSION IF NOT EXISTS postgis;
CREATE EXTENSION IF NOT EXISTS pgcrypto;          -- digest() SHA-256, gen_random_uuid()

DROP SCHEMA IF EXISTS sirdepa CASCADE;
CREATE SCHEMA sirdepa;
SET search_path TO sirdepa, public;

-- ---------------------------------------------------------------------
-- 1. Tipos enumerados (enumeraciones del diagrama de clases)
-- ---------------------------------------------------------------------
CREATE TYPE categoria_pesca    AS ENUM ('ARTESANAL', 'MENOR_ESCALA');                       -- RD01
CREATE TYPE estado_validacion  AS ENUM ('CONFORME', 'OBSERVADO', 'NO_CONFORME');            -- RF10
CREATE TYPE estado_registro    AS ENUM ('BORRADOR', 'EMITIDO', 'ANULADO');
CREATE TYPE origen_registro    AS ENUM ('APP_MOVIL', 'PORTAL_WEB');
CREATE TYPE estado_lote        AS ENUM ('DESPACHADO', 'RECIBIDO');                           -- RF14, RF15
CREATE TYPE estado_aviso       AS ENUM ('PENDIENTE', 'ATENDIDO', 'CANCELADO');              -- RF05

-- ---------------------------------------------------------------------
-- 2. Parámetros del motor de reglas (RNF12: parametrizable sin programar)
-- ---------------------------------------------------------------------
CREATE TABLE parametro (
    clave        VARCHAR(60)  PRIMARY KEY,
    valor        NUMERIC      NOT NULL,
    descripcion  TEXT         NOT NULL
);

-- ---------------------------------------------------------------------
-- 3. M1 Acceso y seguridad: Rol, Usuario
-- ---------------------------------------------------------------------
CREATE TABLE rol (
    id_rol       SMALLSERIAL  PRIMARY KEY,
    codigo       VARCHAR(20)  NOT NULL UNIQUE,
    nombre       VARCHAR(60)  NOT NULL
);

CREATE TABLE lugar_desembarque (
    id_lugar     SERIAL       PRIMARY KEY,
    codigo       VARCHAR(20)  NOT NULL UNIQUE,
    nombre       VARCHAR(120) NOT NULL,
    tipo         VARCHAR(20)  NOT NULL CHECK (tipo IN ('DPA', 'CALETA', 'PUNTO_DESEMBARQUE')),
    region       VARCHAR(40)  NOT NULL,
    ubicacion    geometry(Point, 4326)
);

CREATE TABLE usuario (
    id_usuario        UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
    dni               CHAR(8)      NOT NULL UNIQUE CHECK (dni ~ '^[0-9]{8}$'),        -- HU01: sin DNI duplicados
    nombres           VARCHAR(120) NOT NULL,
    celular           VARCHAR(15)  NOT NULL CHECK (celular ~ '^\+?[0-9]{9,14}$'),       -- OTP por SMS (RF01)
    pin_hash          VARCHAR(255) NOT NULL,                                            -- Argon2/bcrypt (RNF08)
    id_rol            SMALLINT     NOT NULL REFERENCES rol(id_rol),
    id_lugar          INTEGER      REFERENCES lugar_desembarque(id_lugar),              -- DPA asignado
    activo            BOOLEAN      NOT NULL DEFAULT TRUE,
    intentos_fallidos SMALLINT     NOT NULL DEFAULT 0 CHECK (intentos_fallidos >= 0),
    bloqueado_hasta   TIMESTAMPTZ,                                                      -- HU02: 5 intentos → 15 min
    creado_en         TIMESTAMPTZ  NOT NULL DEFAULT now()
);

-- ---------------------------------------------------------------------
-- 4. M2 Maestros: Armador, Embarcación, Permiso de pesca, Comprador
-- ---------------------------------------------------------------------
CREATE TABLE armador (
    id_armador          SERIAL       PRIMARY KEY,
    tipo_documento      VARCHAR(3)   NOT NULL CHECK (tipo_documento IN ('DNI', 'CE', 'RUC')),
    numero_documento    VARCHAR(11)  NOT NULL,
    nombre              VARCHAR(150) NOT NULL,
    celular             VARCHAR(15)  CHECK (celular ~ '^\+?[0-9]{9,14}$'),              -- recibe la constancia por SMS
    id_usuario          UUID         UNIQUE REFERENCES usuario(id_usuario),              -- acceso opcional (CU12)
    consentimiento_en   TIMESTAMPTZ,                                                     -- RD10 Ley 29733
    UNIQUE (tipo_documento, numero_documento)
);

CREATE TABLE embarcacion (
    id_embarcacion       SERIAL          PRIMARY KEY,
    matricula            VARCHAR(20)     NOT NULL UNIQUE,                                -- HU03
    nombre               VARCHAR(100)    NOT NULL,
    eslora_m             NUMERIC(5,2)    NOT NULL CHECK (eslora_m > 0),
    capacidad_bodega_m3  NUMERIC(6,2)    NOT NULL CHECK (capacidad_bodega_m3 > 0),
    trabajo_manual       BOOLEAN         NOT NULL DEFAULT TRUE,
    categoria            categoria_pesca NOT NULL,
    id_armador           INTEGER         NOT NULL REFERENCES armador(id_armador),
    activa               BOOLEAN         NOT NULL DEFAULT TRUE,
    -- RD01 (D.S. 002-2025-PRODUCE): artesanal ≤ 32,6 m³ de bodega y ≤ 15 m de eslora con predominio del trabajo manual
    CONSTRAINT ck_categoria_artesanal CHECK (
        categoria <> 'ARTESANAL' OR (capacidad_bodega_m3 <= 32.6 AND eslora_m <= 15 AND trabajo_manual)),
    -- Alcance del sistema: embarcaciones de hasta 32,6 m³
    CONSTRAINT ck_alcance_bodega CHECK (capacidad_bodega_m3 <= 32.6)
);

CREATE TABLE permiso_pesca (
    id_permiso          SERIAL       PRIMARY KEY,
    id_embarcacion      INTEGER      NOT NULL REFERENCES embarcacion(id_embarcacion),
    numero_resolucion   VARCHAR(60)  NOT NULL UNIQUE,
    entidad_emisora     VARCHAR(80)  NOT NULL,                                            -- PRODUCE o DIREPRO
    fecha_emision       DATE         NOT NULL,
    fecha_vencimiento   DATE         NOT NULL,
    CONSTRAINT ck_permiso_fechas CHECK (fecha_vencimiento >= fecha_emision)
);

CREATE TABLE comprador (
    id_comprador        SERIAL       PRIMARY KEY,
    tipo_documento      VARCHAR(3)   NOT NULL CHECK (tipo_documento IN ('DNI', 'CE', 'RUC')),
    numero_documento    VARCHAR(11)  NOT NULL,
    nombre              VARCHAR(150) NOT NULL,
    tipo                VARCHAR(20)  NOT NULL CHECK (tipo IN ('COMERCIANTE', 'PLANTA', 'MERCADO', 'CONSUMIDOR')),
    id_usuario          UUID         UNIQUE REFERENCES usuario(id_usuario),              -- confirma recepción (CU09)
    UNIQUE (tipo_documento, numero_documento)
);

-- ---------------------------------------------------------------------
-- 5. M3 Catálogo normativo: Especie, Talla mínima (versionada), Arte,
--    Zona de pesca (cuadrícula), Veda
-- ---------------------------------------------------------------------
CREATE TABLE especie (
    id_especie          SERIAL       PRIMARY KEY,
    codigo_fao          CHAR(3)      UNIQUE CHECK (codigo_fao ~ '^[A-Z]{3}$'),           -- lista ASFIS (RNF11)
    nombre_comun        VARCHAR(80)  NOT NULL,
    nombre_cientifico   VARCHAR(120) NOT NULL UNIQUE
);

-- HU05: un cambio de talla aplica a desembarques posteriores y no a los anteriores
CREATE TABLE talla_minima (
    id_talla                 SERIAL       PRIMARY KEY,
    id_especie               INTEGER      NOT NULL REFERENCES especie(id_especie),
    talla_minima_cm          NUMERIC(6,2) NOT NULL CHECK (talla_minima_cm > 0),
    tolerancia_juveniles_pct NUMERIC(5,2) NOT NULL CHECK (tolerancia_juveniles_pct BETWEEN 0 AND 100),
    norma                    VARCHAR(80)  NOT NULL,
    vigente_desde            DATE         NOT NULL,
    vigente_hasta            DATE,
    CONSTRAINT ck_talla_vigencia CHECK (vigente_hasta IS NULL OR vigente_hasta >= vigente_desde),
    CONSTRAINT uq_talla_desde UNIQUE (id_especie, vigente_desde)
);

CREATE TABLE arte_pesca (
    id_arte       SERIAL       PRIMARY KEY,
    nombre        VARCHAR(80)  NOT NULL UNIQUE,
    tipo          VARCHAR(40)  NOT NULL,
    mecanizado    BOOLEAN      NOT NULL DEFAULT FALSE                                    -- RD08: cerco mecanizado
);

-- RNF09 / N04: se registra la cuadrícula, no la coordenada exacta del caladero
CREATE TABLE zona_pesca (
    id_zona            SERIAL       PRIMARY KEY,
    codigo_cuadricula  VARCHAR(20)  NOT NULL UNIQUE,
    dentro_5_millas    BOOLEAN      NOT NULL,                                             -- RD08
    dentro_3_millas    BOOLEAN      NOT NULL,
    geom               geometry(Polygon, 4326),
    CONSTRAINT ck_millas CHECK (NOT dentro_3_millas OR dentro_5_millas)
);

CREATE TABLE veda (
    id_veda        SERIAL       PRIMARY KEY,
    id_especie     INTEGER      NOT NULL REFERENCES especie(id_especie),
    id_zona        INTEGER      REFERENCES zona_pesca(id_zona),                          -- NULL = todo el litoral
    fecha_inicio   DATE         NOT NULL,
    fecha_fin      DATE         NOT NULL,
    norma          VARCHAR(80)  NOT NULL,                                                 -- RD04
    CONSTRAINT ck_veda_fechas CHECK (fecha_fin >= fecha_inicio)
);

-- Permiso N:M Especie y Permiso N:M Arte (resueltas con tablas intermedias)
CREATE TABLE permiso_especie (
    id_permiso  INTEGER NOT NULL REFERENCES permiso_pesca(id_permiso) ON DELETE CASCADE,
    id_especie  INTEGER NOT NULL REFERENCES especie(id_especie),
    PRIMARY KEY (id_permiso, id_especie)
);

CREATE TABLE permiso_arte (
    id_permiso  INTEGER NOT NULL REFERENCES permiso_pesca(id_permiso) ON DELETE CASCADE,
    id_arte     INTEGER NOT NULL REFERENCES arte_pesca(id_arte),
    PRIMARY KEY (id_permiso, id_arte)
);

-- ---------------------------------------------------------------------
-- 6. M4 Registro de desembarque
-- ---------------------------------------------------------------------
CREATE TABLE aviso_arribo (
    id_aviso             SERIAL        PRIMARY KEY,
    id_embarcacion       INTEGER       NOT NULL REFERENCES embarcacion(id_embarcacion),
    id_lugar             INTEGER       NOT NULL REFERENCES lugar_desembarque(id_lugar),
    hora_estimada        TIMESTAMPTZ   NOT NULL,
    captura_aproximada   TEXT,
    estado               estado_aviso  NOT NULL DEFAULT 'PENDIENTE',
    creado_en            TIMESTAMPTZ   NOT NULL DEFAULT now()
);

CREATE TABLE desembarque (
    id_desembarque     UUID              PRIMARY KEY,                                     -- UUID generado en el celular = Idempotency-Key (RF12)
    id_embarcacion     INTEGER           NOT NULL REFERENCES embarcacion(id_embarcacion),
    id_lugar           INTEGER           NOT NULL REFERENCES lugar_desembarque(id_lugar),
    id_registrador     UUID              NOT NULL REFERENCES usuario(id_usuario),
    id_aviso           INTEGER           UNIQUE REFERENCES aviso_arribo(id_aviso),
    codigo_faena       VARCHAR(30),
    fecha_zarpe        TIMESTAMPTZ       NOT NULL,
    fecha_hora_arribo  TIMESTAMPTZ       NOT NULL,
    id_zona            INTEGER           NOT NULL REFERENCES zona_pesca(id_zona),
    id_arte            INTEGER           NOT NULL REFERENCES arte_pesca(id_arte),
    tripulantes        SMALLINT          CHECK (tripulantes > 0),
    estado_validacion  estado_validacion,                                                 -- NULL hasta validar
    estado_registro    estado_registro   NOT NULL DEFAULT 'BORRADOR',
    origen             origen_registro   NOT NULL DEFAULT 'APP_MOVIL',
    registrado_en      TIMESTAMPTZ       NOT NULL,                                        -- hora del celular
    sincronizado_en    TIMESTAMPTZ       NOT NULL DEFAULT now(),                          -- hora de llegada al servidor
    motivo_anulacion   TEXT,
    anulado_por        UUID              REFERENCES usuario(id_usuario),
    anulado_en         TIMESTAMPTZ,
    CONSTRAINT ck_fechas_faena CHECK (fecha_hora_arribo >= fecha_zarpe),
    -- RF23: anular solo con motivo, usuario y fecha
    CONSTRAINT ck_anulacion CHECK (
        (estado_registro = 'ANULADO') = (motivo_anulacion IS NOT NULL AND anulado_por IS NOT NULL AND anulado_en IS NOT NULL))
);

CREATE TABLE detalle_desembarque (
    id_detalle         SERIAL        PRIMARY KEY,
    id_desembarque     UUID          NOT NULL REFERENCES desembarque(id_desembarque) ON DELETE CASCADE,
    id_especie         INTEGER       NOT NULL REFERENCES especie(id_especie),
    peso_kg            NUMERIC(10,2) NOT NULL CHECK (peso_kg > 0),                        -- HU07: peso ≤ 0 no se permite
    unidades           INTEGER       CHECK (unidades > 0),
    presentacion       VARCHAR(30)   NOT NULL DEFAULT 'ENTERO',
    precio_playa_kg    NUMERIC(8,2)  CHECK (precio_playa_kg >= 0),
    CONSTRAINT uq_detalle UNIQUE (id_desembarque, id_especie, presentacion)
);

CREATE TABLE muestreo_talla (
    id_muestreo        SERIAL          PRIMARY KEY,
    id_detalle         INTEGER         NOT NULL UNIQUE REFERENCES detalle_desembarque(id_detalle) ON DELETE CASCADE,
    tallas_cm          NUMERIC(6,2)[]  NOT NULL CHECK (cardinality(tallas_cm) > 0),
    pct_bajo_talla     NUMERIC(5,2),                                                      -- calculado en la validación
    registrado_en      TIMESTAMPTZ     NOT NULL DEFAULT now()
);

CREATE TABLE evidencia_foto (
    id_foto            SERIAL       PRIMARY KEY,
    id_desembarque     UUID         NOT NULL REFERENCES desembarque(id_desembarque) ON DELETE CASCADE,
    url                TEXT         NOT NULL,
    hash_sha256        CHAR(64)     NOT NULL CHECK (hash_sha256 ~ '^[0-9a-f]{64}$'),
    tamano_kb          INTEGER      NOT NULL CHECK (tamano_kb BETWEEN 1 AND 300),         -- RNF05, HU23
    tomada_en          TIMESTAMPTZ  NOT NULL DEFAULT now()
);

-- ---------------------------------------------------------------------
-- 7. M5 Validación normativa: resultado de cada regla
-- ---------------------------------------------------------------------
CREATE TABLE resultado_validacion (
    id_resultado    SERIAL             PRIMARY KEY,
    id_desembarque  UUID               NOT NULL REFERENCES desembarque(id_desembarque) ON DELETE CASCADE,
    regla           VARCHAR(30)        NOT NULL,
    nivel           estado_validacion  NOT NULL,
    mensaje         TEXT               NOT NULL,                                          -- lenguaje sencillo
    norma           VARCHAR(80),
    evaluado_en     TIMESTAMPTZ        NOT NULL DEFAULT now()
);

-- ---------------------------------------------------------------------
-- 8. M6 Constancia y trazabilidad
-- ---------------------------------------------------------------------
CREATE TABLE constancia (
    id_constancia    SERIAL       PRIMARY KEY,
    id_desembarque   UUID         NOT NULL UNIQUE REFERENCES desembarque(id_desembarque),  -- 0..1 por desembarque
    codigo           VARCHAR(20)  NOT NULL UNIQUE,
    hash_sha256      CHAR(64)     NOT NULL,                                               -- RNF10
    url_qr           TEXT         NOT NULL,
    fecha_emision    TIMESTAMPTZ  NOT NULL DEFAULT now(),
    sms_enviado_en   TIMESTAMPTZ
);

CREATE TABLE lote_destino (
    id_lote          SERIAL        PRIMARY KEY,
    id_detalle       INTEGER       NOT NULL REFERENCES detalle_desembarque(id_detalle),
    id_comprador     INTEGER       NOT NULL REFERENCES comprador(id_comprador),
    peso_kg          NUMERIC(10,2) NOT NULL CHECK (peso_kg > 0),
    placa_vehiculo   VARCHAR(10),
    dni_conductor    CHAR(8)       CHECK (dni_conductor ~ '^[0-9]{8}$'),                  -- RD05
    destino          VARCHAR(120),
    estado           estado_lote   NOT NULL DEFAULT 'DESPACHADO',
    despachado_en    TIMESTAMPTZ   NOT NULL DEFAULT now(),
    recibido_en      TIMESTAMPTZ,
    recibido_por     UUID          REFERENCES usuario(id_usuario),
    CONSTRAINT ck_recepcion CHECK ((estado = 'RECIBIDO') = (recibido_en IS NOT NULL))
);

-- ---------------------------------------------------------------------
-- 9. M7 Fiscalización: Inspección y alertas
-- ---------------------------------------------------------------------
CREATE TABLE inspeccion (
    id_inspeccion    SERIAL       PRIMARY KEY,
    id_desembarque   UUID         NOT NULL REFERENCES desembarque(id_desembarque),
    id_fiscalizador  UUID         NOT NULL REFERENCES usuario(id_usuario),
    fecha_hora       TIMESTAMPTZ  NOT NULL DEFAULT now(),
    resultado        VARCHAR(20)  NOT NULL CHECK (resultado IN ('SIN_OBSERVACION', 'OBSERVACION', 'ACTA')),
    numero_acta      VARCHAR(30),
    observacion      TEXT,
    CONSTRAINT ck_acta CHECK (resultado <> 'ACTA' OR numero_acta IS NOT NULL)
);

CREATE TABLE alerta (
    id_alerta        SERIAL       PRIMARY KEY,
    tipo             VARCHAR(30)  NOT NULL CHECK (tipo IN ('NO_CONFORME', 'PERMISO_POR_VENCER')),   -- RF22
    id_desembarque   UUID         REFERENCES desembarque(id_desembarque),
    id_permiso       INTEGER      REFERENCES permiso_pesca(id_permiso),
    mensaje          TEXT         NOT NULL,
    creada_en        TIMESTAMPTZ  NOT NULL DEFAULT now(),
    atendida_por     UUID         REFERENCES usuario(id_usuario),
    atendida_en      TIMESTAMPTZ,
    CONSTRAINT ck_alerta_origen CHECK (id_desembarque IS NOT NULL OR id_permiso IS NOT NULL)
);

-- ---------------------------------------------------------------------
-- 10. M8 Información: cierre diario (RF24)
-- ---------------------------------------------------------------------
CREATE TABLE cierre_diario (
    id_cierre     SERIAL       PRIMARY KEY,
    id_lugar      INTEGER      NOT NULL REFERENCES lugar_desembarque(id_lugar),
    fecha         DATE         NOT NULL,
    kg_registrados NUMERIC(12,2) NOT NULL,
    kg_despachados NUMERIC(12,2) NOT NULL,
    cerrado_por   UUID         NOT NULL REFERENCES usuario(id_usuario),
    cerrado_en    TIMESTAMPTZ  NOT NULL DEFAULT now(),
    UNIQUE (id_lugar, fecha)
);

-- ---------------------------------------------------------------------
-- 11. Bitácora de auditoría inmutable (RF23, RNF10)
-- ---------------------------------------------------------------------
CREATE TABLE auditoria (
    id_auditoria   BIGSERIAL    PRIMARY KEY,
    tabla          VARCHAR(40)  NOT NULL,
    operacion      CHAR(1)      NOT NULL CHECK (operacion IN ('I', 'U', 'D')),
    id_registro    TEXT         NOT NULL,
    datos_antes    JSONB,
    datos_despues  JSONB,
    usuario_app    TEXT,                                                                  -- SET sirdepa.usuario = '<uuid>'
    fecha          TIMESTAMPTZ  NOT NULL DEFAULT now()
);

-- ---------------------------------------------------------------------
-- 12. Índices (RNF04: p95 ≤ 2 s; RNF13: ≥ 25 000 embarcaciones)
-- ---------------------------------------------------------------------
CREATE INDEX ix_embarcacion_matricula_pref ON embarcacion (lower(matricula) text_pattern_ops);   -- HU06: búsqueda por prefijo
CREATE INDEX ix_embarcacion_armador   ON embarcacion (id_armador);
CREATE INDEX ix_permiso_vigencia      ON permiso_pesca (id_embarcacion, fecha_vencimiento);
CREATE INDEX ix_talla_especie         ON talla_minima (id_especie, vigente_desde DESC);
CREATE INDEX ix_veda_especie          ON veda (id_especie, fecha_inicio, fecha_fin);
CREATE INDEX ix_zona_geom             ON zona_pesca USING GIST (geom);
CREATE INDEX ix_lugar_geom            ON lugar_desembarque USING GIST (ubicacion);
CREATE INDEX ix_desembarque_lugar_dia ON desembarque (id_lugar, fecha_hora_arribo DESC);
CREATE INDEX ix_desembarque_emb       ON desembarque (id_embarcacion, fecha_hora_arribo DESC);
CREATE INDEX ix_detalle_desembarque   ON detalle_desembarque (id_desembarque);
CREATE INDEX ix_detalle_especie       ON detalle_desembarque (id_especie);
CREATE INDEX ix_resultado_desembarque ON resultado_validacion (id_desembarque);
CREATE INDEX ix_lote_detalle          ON lote_destino (id_detalle);
CREATE INDEX ix_lote_comprador        ON lote_destino (id_comprador, estado);
CREATE INDEX ix_alerta_pendiente      ON alerta (creada_en DESC) WHERE atendida_en IS NULL;
CREATE INDEX ix_auditoria_registro    ON auditoria (tabla, id_registro);

-- =====================================================================
-- 13. Reglas de negocio en la base de datos
-- =====================================================================

-- 13.1 Máximo 3 fotos por desembarque (RF11, HU23)
CREATE OR REPLACE FUNCTION fn_max_fotos() RETURNS trigger AS $$
BEGIN
    IF (SELECT count(*) FROM evidencia_foto WHERE id_desembarque = NEW.id_desembarque) >= 3 THEN
        RAISE EXCEPTION 'Máximo 3 fotografías por desembarque' USING ERRCODE = 'check_violation';
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER tg_max_fotos BEFORE INSERT ON evidencia_foto
FOR EACH ROW EXECUTE FUNCTION fn_max_fotos();

-- 13.2 La suma asignada a lotes no puede superar lo desembarcado (RF14, HU12)
CREATE OR REPLACE FUNCTION fn_saldo_lote() RETURNS trigger AS $$
DECLARE
    v_peso      NUMERIC;
    v_asignado  NUMERIC;
BEGIN
    SELECT peso_kg INTO v_peso FROM detalle_desembarque WHERE id_detalle = NEW.id_detalle FOR UPDATE;
    SELECT COALESCE(SUM(peso_kg), 0) INTO v_asignado
      FROM lote_destino WHERE id_detalle = NEW.id_detalle AND id_lote <> COALESCE(NEW.id_lote, -1);
    IF v_asignado + NEW.peso_kg > v_peso THEN
        RAISE EXCEPTION 'La suma asignada (% kg) supera lo desembarcado (% kg). Saldo pendiente: % kg',
              v_asignado + NEW.peso_kg, v_peso, v_peso - v_asignado USING ERRCODE = 'check_violation';
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER tg_saldo_lote BEFORE INSERT OR UPDATE OF peso_kg, id_detalle ON lote_destino
FOR EACH ROW EXECUTE FUNCTION fn_saldo_lote();

-- 13.3 Tras el cierre diario no se editan los registros del día (RF24, HU24)
CREATE OR REPLACE FUNCTION fn_bloqueo_cierre() RETURNS trigger AS $$
DECLARE
    v_des        desembarque%ROWTYPE;
    v_anulacion  BOOLEAN := FALSE;     -- la anulación sigue permitida, porque deja rastro en la auditoría
BEGIN
    IF TG_TABLE_NAME = 'desembarque' THEN
        IF TG_OP = 'DELETE' THEN v_des := OLD; ELSE v_des := NEW; END IF;
        IF TG_OP = 'UPDATE' THEN
            v_anulacion := v_des.estado_registro = 'ANULADO';
        END IF;
    ELSE
        SELECT * INTO v_des FROM desembarque
         WHERE id_desembarque = CASE WHEN TG_OP = 'DELETE' THEN OLD.id_desembarque ELSE NEW.id_desembarque END;
    END IF;
    IF EXISTS (SELECT 1 FROM cierre_diario c
                WHERE c.id_lugar = v_des.id_lugar
                  AND c.fecha = (v_des.fecha_hora_arribo AT TIME ZONE 'America/Lima')::date)
       AND NOT v_anulacion THEN
        RAISE EXCEPTION 'El día % ya fue cerrado en este lugar de desembarque',
              (v_des.fecha_hora_arribo AT TIME ZONE 'America/Lima')::date USING ERRCODE = 'check_violation';
    END IF;
    RETURN CASE WHEN TG_OP = 'DELETE' THEN OLD ELSE NEW END;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER tg_cierre_desembarque BEFORE UPDATE OR DELETE ON desembarque
FOR EACH ROW EXECUTE FUNCTION fn_bloqueo_cierre();
CREATE TRIGGER tg_cierre_detalle BEFORE INSERT OR UPDATE OR DELETE ON detalle_desembarque
FOR EACH ROW EXECUTE FUNCTION fn_bloqueo_cierre();

-- 13.4 Auditoría genérica
CREATE OR REPLACE FUNCTION fn_auditoria() RETURNS trigger AS $$
BEGIN
    INSERT INTO auditoria (tabla, operacion, id_registro, datos_antes, datos_despues, usuario_app)
    VALUES (TG_TABLE_NAME, left(TG_OP, 1),
            COALESCE(to_jsonb(NEW) ->> TG_ARGV[0], to_jsonb(OLD) ->> TG_ARGV[0]),
            CASE WHEN TG_OP <> 'INSERT' THEN to_jsonb(OLD) END,
            CASE WHEN TG_OP <> 'DELETE' THEN to_jsonb(NEW) END,
            current_setting('sirdepa.usuario', TRUE));
    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER tg_aud_desembarque AFTER INSERT OR UPDATE OR DELETE ON desembarque         FOR EACH ROW EXECUTE FUNCTION fn_auditoria('id_desembarque');
CREATE TRIGGER tg_aud_detalle     AFTER INSERT OR UPDATE OR DELETE ON detalle_desembarque FOR EACH ROW EXECUTE FUNCTION fn_auditoria('id_detalle');
CREATE TRIGGER tg_aud_lote        AFTER INSERT OR UPDATE OR DELETE ON lote_destino        FOR EACH ROW EXECUTE FUNCTION fn_auditoria('id_lote');
CREATE TRIGGER tg_aud_embarcacion AFTER INSERT OR UPDATE OR DELETE ON embarcacion         FOR EACH ROW EXECUTE FUNCTION fn_auditoria('id_embarcacion');
CREATE TRIGGER tg_aud_permiso     AFTER INSERT OR UPDATE OR DELETE ON permiso_pesca       FOR EACH ROW EXECUTE FUNCTION fn_auditoria('id_permiso');
CREATE TRIGGER tg_aud_talla       AFTER INSERT OR UPDATE OR DELETE ON talla_minima        FOR EACH ROW EXECUTE FUNCTION fn_auditoria('id_talla');
CREATE TRIGGER tg_aud_veda        AFTER INSERT OR UPDATE OR DELETE ON veda                FOR EACH ROW EXECUTE FUNCTION fn_auditoria('id_veda');
CREATE TRIGGER tg_aud_inspeccion  AFTER INSERT OR UPDATE OR DELETE ON inspeccion          FOR EACH ROW EXECUTE FUNCTION fn_auditoria('id_inspeccion');

-- La bitácora es inmutable (RNF10)
CREATE OR REPLACE FUNCTION fn_auditoria_inmutable() RETURNS trigger AS $$
BEGIN
    RAISE EXCEPTION 'La bitácora de auditoría no se puede modificar ni borrar' USING ERRCODE = 'insufficient_privilege';
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER tg_auditoria_inmutable BEFORE UPDATE OR DELETE ON auditoria
FOR EACH ROW EXECUTE FUNCTION fn_auditoria_inmutable();

-- =====================================================================
-- 14. Motor de validación normativa (RF10, CU06)
--     Referencia en BD del patrón Strategy del back-end: cada bloque es
--     una regla independiente que agrega su resultado. La validación no
--     bloquea el registro; clasifica y deja el motivo exacto.
-- =====================================================================
CREATE OR REPLACE FUNCTION validar_desembarque(p_id UUID) RETURNS estado_validacion AS $$
DECLARE
    d          desembarque%ROWTYPE;
    e          embarcacion%ROWTYPE;
    v_fecha    DATE;
    v_permiso  permiso_pesca%ROWTYPE;
    v_arte     arte_pesca%ROWTYPE;
    v_zona     zona_pesca%ROWTYPE;
    r          RECORD;
    v_total    NUMERIC;
    v_factor   NUMERIC;
    v_estado   estado_validacion;
BEGIN
    SELECT * INTO d FROM desembarque WHERE id_desembarque = p_id;
    IF NOT FOUND THEN RAISE EXCEPTION 'Desembarque % no existe', p_id; END IF;
    SELECT * INTO e      FROM embarcacion WHERE id_embarcacion = d.id_embarcacion;
    SELECT * INTO v_arte FROM arte_pesca  WHERE id_arte = d.id_arte;
    SELECT * INTO v_zona FROM zona_pesca  WHERE id_zona = d.id_zona;
    v_fecha := (d.fecha_hora_arribo AT TIME ZONE 'America/Lima')::date;

    DELETE FROM resultado_validacion WHERE id_desembarque = p_id;

    -- Regla PERMISO_VIGENTE
    SELECT * INTO v_permiso FROM permiso_pesca
     WHERE id_embarcacion = d.id_embarcacion AND v_fecha BETWEEN fecha_emision AND fecha_vencimiento
     ORDER BY fecha_vencimiento DESC LIMIT 1;
    IF NOT FOUND THEN
        INSERT INTO resultado_validacion (id_desembarque, regla, nivel, mensaje, norma)
        VALUES (p_id, 'PERMISO_VIGENTE', 'NO_CONFORME',
                format('La embarcación %s no tiene permiso de pesca vigente el %s.', e.matricula, to_char(v_fecha, 'DD/MM/YYYY')),
                'D.L. 25977, Ley General de Pesca');
    ELSE
        -- Regla ARTE_AUTORIZADO
        IF NOT EXISTS (SELECT 1 FROM permiso_arte WHERE id_permiso = v_permiso.id_permiso AND id_arte = d.id_arte) THEN
            INSERT INTO resultado_validacion (id_desembarque, regla, nivel, mensaje, norma)
            VALUES (p_id, 'ARTE_AUTORIZADO', 'NO_CONFORME',
                    format('El permiso %s no autoriza pescar con %s.', v_permiso.numero_resolucion, lower(v_arte.nombre)),
                    v_permiso.numero_resolucion);
        END IF;
        -- Regla ESPECIE_AUTORIZADA
        FOR r IN SELECT DISTINCT es.nombre_comun FROM detalle_desembarque dd JOIN especie es USING (id_especie)
                  WHERE dd.id_desembarque = p_id
                    AND NOT EXISTS (SELECT 1 FROM permiso_especie pe
                                     WHERE pe.id_permiso = v_permiso.id_permiso AND pe.id_especie = dd.id_especie) LOOP
            INSERT INTO resultado_validacion (id_desembarque, regla, nivel, mensaje, norma)
            VALUES (p_id, 'ESPECIE_AUTORIZADA', 'NO_CONFORME',
                    format('El permiso %s no autoriza la especie %s.', v_permiso.numero_resolucion, lower(r.nombre_comun)),
                    v_permiso.numero_resolucion);
        END LOOP;
    END IF;

    -- Regla VEDA (RD04)
    FOR r IN SELECT DISTINCT es.nombre_comun, v.norma FROM detalle_desembarque dd
               JOIN especie es USING (id_especie)
               JOIN veda v ON v.id_especie = dd.id_especie
                          AND v_fecha BETWEEN v.fecha_inicio AND v.fecha_fin
                          AND (v.id_zona IS NULL OR v.id_zona = d.id_zona)
              WHERE dd.id_desembarque = p_id LOOP
        INSERT INTO resultado_validacion (id_desembarque, regla, nivel, mensaje, norma)
        VALUES (p_id, 'VEDA', 'NO_CONFORME',
                format('La %s está en veda en esta fecha.', lower(r.nombre_comun)), r.norma);
    END LOOP;

    -- Regla TALLA_MINIMA (RD03): % bajo talla vs tolerancia vigente a la fecha del arribo
    FOR r IN SELECT mt.id_muestreo, es.nombre_comun, t.talla_minima_cm, t.tolerancia_juveniles_pct, t.norma,
                    ROUND(100.0 * (SELECT count(*) FROM unnest(mt.tallas_cm) x WHERE x < t.talla_minima_cm)
                          / cardinality(mt.tallas_cm), 2) AS pct
               FROM detalle_desembarque dd
               JOIN muestreo_talla mt USING (id_detalle)
               JOIN especie es USING (id_especie)
               JOIN LATERAL (SELECT * FROM talla_minima tm
                              WHERE tm.id_especie = dd.id_especie AND tm.vigente_desde <= v_fecha
                                AND (tm.vigente_hasta IS NULL OR tm.vigente_hasta >= v_fecha)
                              ORDER BY tm.vigente_desde DESC LIMIT 1) t ON TRUE
              WHERE dd.id_desembarque = p_id LOOP
        UPDATE muestreo_talla SET pct_bajo_talla = r.pct WHERE id_muestreo = r.id_muestreo;
        IF r.pct > r.tolerancia_juveniles_pct THEN
            INSERT INTO resultado_validacion (id_desembarque, regla, nivel, mensaje, norma)
            VALUES (p_id, 'TALLA_MINIMA', 'OBSERVADO',
                    format('%s: el %s %% de la muestra mide menos de %s cm; la tolerancia es %s %%.',
                           r.nombre_comun, r.pct, r.talla_minima_cm, r.tolerancia_juveniles_pct),
                    r.norma);
        END IF;
    END LOOP;

    -- Regla ZONA_ARTE (RD08): sin cerco mecanizado en las 3 primeras millas;
    -- la franja de 0 a 5 millas es solo para artesanal y menor escala
    IF v_arte.mecanizado AND v_arte.tipo = 'CERCO' AND v_zona.dentro_3_millas THEN
        INSERT INTO resultado_validacion (id_desembarque, regla, nivel, mensaje, norma)
        VALUES (p_id, 'ZONA_ARTE', 'OBSERVADO',
                format('La cuadrícula %s está dentro de las 3 millas, donde no se permite el cerco mecanizado.', v_zona.codigo_cuadricula),
                'D.S. 002-2025-PRODUCE');
    END IF;

    -- Regla CAPACIDAD_BODEGA: los kilos no deben superar la capacidad declarada
    SELECT COALESCE(SUM(peso_kg), 0) INTO v_total FROM detalle_desembarque WHERE id_desembarque = p_id;
    SELECT valor INTO v_factor FROM parametro WHERE clave = 'KG_POR_M3_BODEGA';
    IF v_total > e.capacidad_bodega_m3 * v_factor THEN
        INSERT INTO resultado_validacion (id_desembarque, regla, nivel, mensaje, norma)
        VALUES (p_id, 'CAPACIDAD_BODEGA', 'OBSERVADO',
                format('Se registraron %s kg, más de lo que admite una bodega de %s m³ (%s kg).',
                       v_total, e.capacidad_bodega_m3, e.capacidad_bodega_m3 * v_factor), NULL);
    END IF;

    -- Clasificación final: el peor nivel encontrado
    SELECT COALESCE(max(nivel), 'CONFORME') INTO v_estado FROM resultado_validacion WHERE id_desembarque = p_id;
    IF v_estado = 'CONFORME' THEN
        INSERT INTO resultado_validacion (id_desembarque, regla, nivel, mensaje)
        VALUES (p_id, 'RESUMEN', 'CONFORME', 'El desembarque cumple todas las reglas vigentes.');
    END IF;

    UPDATE desembarque SET estado_validacion = v_estado WHERE id_desembarque = p_id;

    -- RF22: alerta al fiscalizador ante un No conforme
    IF v_estado = 'NO_CONFORME' THEN
        INSERT INTO alerta (tipo, id_desembarque, mensaje)
        SELECT 'NO_CONFORME', p_id,
               format('Desembarque No conforme de %s: %s', e.matricula, string_agg(mensaje, ' '))
          FROM resultado_validacion WHERE id_desembarque = p_id AND nivel = 'NO_CONFORME';
    END IF;

    RETURN v_estado;
END;
$$ LANGUAGE plpgsql;

-- =====================================================================
-- 15. Emisión y verificación de la constancia (RF13, RF16, CU07, CU10)
-- =====================================================================
CREATE SEQUENCE seq_constancia;

CREATE OR REPLACE FUNCTION contenido_constancia(p_id UUID) RETURNS TEXT AS $$
    -- Texto canónico sobre el que se calcula el hash SHA-256
    SELECT concat_ws('|', d.id_desembarque, e.matricula, to_char(d.fecha_hora_arribo AT TIME ZONE 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS"Z"'),
                     l.codigo, d.estado_validacion,
                     (SELECT string_agg(COALESCE(es.codigo_fao, '---') || ':' || es.nombre_cientifico || ':' || dd.presentacion || ':' || dd.peso_kg,
                                        ';' ORDER BY es.nombre_cientifico, dd.presentacion)
                        FROM detalle_desembarque dd JOIN especie es USING (id_especie)
                       WHERE dd.id_desembarque = d.id_desembarque))
      FROM desembarque d
      JOIN embarcacion e USING (id_embarcacion)
      JOIN lugar_desembarque l USING (id_lugar)
     WHERE d.id_desembarque = p_id;
$$ LANGUAGE sql STABLE;

CREATE OR REPLACE FUNCTION emitir_constancia(p_id UUID, p_url_base TEXT DEFAULT 'https://sirdepa.pe/v/')
RETURNS constancia AS $$
DECLARE
    d       desembarque%ROWTYPE;
    v_cod   VARCHAR(20);
    v_row   constancia;
BEGIN
    SELECT * INTO d FROM desembarque WHERE id_desembarque = p_id FOR UPDATE;
    IF d.estado_registro = 'ANULADO' THEN RAISE EXCEPTION 'No se puede emitir un desembarque anulado'; END IF;
    IF d.estado_validacion IS NULL THEN PERFORM validar_desembarque(p_id); END IF;
    IF NOT EXISTS (SELECT 1 FROM detalle_desembarque WHERE id_desembarque = p_id) THEN
        RAISE EXCEPTION 'El desembarque no tiene especies registradas';
    END IF;

    SELECT * INTO v_row FROM constancia WHERE id_desembarque = p_id;
    IF FOUND THEN RETURN v_row; END IF;                                                  -- idempotente

    v_cod := format('SRD-%s-%s', to_char(d.fecha_hora_arribo AT TIME ZONE 'America/Lima', 'YYYY'),
                    lpad(nextval('seq_constancia')::text, 6, '0'));
    UPDATE desembarque SET estado_registro = 'EMITIDO' WHERE id_desembarque = p_id;
    INSERT INTO constancia (id_desembarque, codigo, hash_sha256, url_qr)
    VALUES (p_id, v_cod, encode(digest(contenido_constancia(p_id), 'sha256'), 'hex'), p_url_base || v_cod)
    RETURNING * INTO v_row;
    RETURN v_row;
END;
$$ LANGUAGE plpgsql;

-- Anulación con motivo (RF23, HU21)
CREATE OR REPLACE FUNCTION anular_desembarque(p_id UUID, p_usuario UUID, p_motivo TEXT) RETURNS VOID AS $$
BEGIN
    IF COALESCE(trim(p_motivo), '') = '' THEN RAISE EXCEPTION 'La anulación exige un motivo'; END IF;
    IF NOT EXISTS (SELECT 1 FROM usuario u JOIN rol r USING (id_rol)
                    WHERE u.id_usuario = p_usuario AND r.codigo IN ('ADMIN_DPA', 'ADMIN_SISTEMA')) THEN
        RAISE EXCEPTION 'Solo el administrador del DPA puede anular desembarques';
    END IF;
    PERFORM set_config('sirdepa.usuario', p_usuario::text, TRUE);
    UPDATE desembarque
       SET estado_registro = 'ANULADO', motivo_anulacion = p_motivo, anulado_por = p_usuario, anulado_en = now()
     WHERE id_desembarque = p_id;
END;
$$ LANGUAGE plpgsql;

-- Verificación pública por QR, sin datos personales (RF16, RNF09).
-- «NO VÁLIDA» si está anulada o si el hash ya no coincide con los datos.
CREATE OR REPLACE VIEW v_verificacion_publica AS
SELECT c.codigo,
       CASE WHEN d.estado_registro = 'ANULADO' THEN 'NO VÁLIDA'
            WHEN c.hash_sha256 <> encode(digest(contenido_constancia(d.id_desembarque), 'sha256'), 'hex') THEN 'NO VÁLIDA'
            ELSE 'VÁLIDA' END                                  AS estado_constancia,
       c.fecha_emision,
       e.matricula,
       e.nombre                                                AS embarcacion,
       l.nombre                                                AS lugar_desembarque,
       (d.fecha_hora_arribo AT TIME ZONE 'America/Lima')::date AS fecha_desembarque,
       d.estado_validacion,
       (SELECT json_agg(json_build_object('especie', es.nombre_comun, 'presentacion', dd.presentacion, 'kg', dd.peso_kg)
                        ORDER BY es.nombre_comun)
          FROM detalle_desembarque dd JOIN especie es USING (id_especie)
         WHERE dd.id_desembarque = d.id_desembarque)           AS especies
  FROM constancia c
  JOIN desembarque d       USING (id_desembarque)
  JOIN embarcacion e       USING (id_embarcacion)
  JOIN lugar_desembarque l ON l.id_lugar = d.id_lugar;

-- =====================================================================
-- 16. Vistas de información (M8)
-- =====================================================================

-- Saldo pendiente por detalle (DetalleDesembarque.saldoPendienteKg)
CREATE OR REPLACE VIEW v_saldo_detalle AS
SELECT dd.id_detalle, dd.id_desembarque, es.nombre_comun, dd.presentacion, dd.peso_kg,
       COALESCE(SUM(ld.peso_kg), 0)              AS asignado_kg,
       dd.peso_kg - COALESCE(SUM(ld.peso_kg), 0) AS saldo_pendiente_kg
  FROM detalle_desembarque dd
  JOIN especie es USING (id_especie)
  LEFT JOIN lote_destino ld USING (id_detalle)
 GROUP BY dd.id_detalle, es.nombre_comun;

-- Tablero del DPA (RF18, HU16)
CREATE OR REPLACE VIEW v_tablero_diario AS
SELECT d.id_lugar,
       (d.fecha_hora_arribo AT TIME ZONE 'America/Lima')::date AS fecha,
       es.nombre_comun AS especie, a.nombre AS arte, e.matricula,
       SUM(dd.peso_kg)                         AS kg,
       COUNT(DISTINCT d.id_desembarque)        AS desembarques,
       COUNT(DISTINCT d.id_desembarque) FILTER (WHERE d.estado_validacion = 'CONFORME') AS conformes
  FROM desembarque d
  JOIN detalle_desembarque dd USING (id_desembarque)
  JOIN especie es    ON es.id_especie = dd.id_especie
  JOIN arte_pesca a  ON a.id_arte = d.id_arte
  JOIN embarcacion e ON e.id_embarcacion = d.id_embarcacion
 WHERE d.estado_registro <> 'ANULADO'
 GROUP BY d.id_lugar, 2, es.nombre_comun, a.nombre, e.matricula;

-- Reporte mensual de captura y esfuerzo para el IMARPE (RF19, HU17)
CREATE OR REPLACE VIEW v_reporte_imarpe AS
WITH esfuerzo AS (                       -- esfuerzo por embarcación, arte, zona y mes
    SELECT date_trunc('month', d.fecha_hora_arribo AT TIME ZONE 'America/Lima')::date AS mes,
           d.id_embarcacion, d.id_arte, d.id_zona,
           COUNT(DISTINCT (d.fecha_hora_arribo AT TIME ZONE 'America/Lima')::date)  AS dias_pesca,
           COUNT(*)                                                                AS viajes,
           ROUND(SUM(EXTRACT(EPOCH FROM (d.fecha_hora_arribo - d.fecha_zarpe)) / 3600), 1) AS horas_faena
      FROM desembarque d
     WHERE d.estado_registro = 'EMITIDO'
     GROUP BY 1, 2, 3, 4
), captura AS (
    SELECT date_trunc('month', d.fecha_hora_arribo AT TIME ZONE 'America/Lima')::date AS mes,
           d.id_embarcacion, d.id_arte, d.id_zona, dd.id_especie, SUM(dd.peso_kg) AS kg
      FROM desembarque d JOIN detalle_desembarque dd USING (id_desembarque)
     WHERE d.estado_registro = 'EMITIDO'
     GROUP BY 1, 2, 3, 4, 5
)
SELECT c.mes, e.matricula, a.nombre AS arte, z.codigo_cuadricula AS zona,
       f.dias_pesca, f.viajes, f.horas_faena,
       es.codigo_fao, es.nombre_cientifico, c.kg
  FROM captura c
  JOIN esfuerzo f    USING (mes, id_embarcacion, id_arte, id_zona)
  JOIN embarcacion e ON e.id_embarcacion = c.id_embarcacion
  JOIN arte_pesca a  ON a.id_arte = c.id_arte
  JOIN zona_pesca z  ON z.id_zona = c.id_zona
  JOIN especie es    ON es.id_especie = c.id_especie;

-- Exportación con la estructura del módulo de descarga del SITRAPESCA (RF20, RD05)
CREATE OR REPLACE VIEW v_export_sitrapesca AS
SELECT l.codigo                       AS punto_desembarque,
       e.matricula                    AS embarcacion,
       d.codigo_faena,
       d.fecha_hora_arribo            AS fecha_hora_descarga,
       es.codigo_fao                  AS especie_fao,
       dd.presentacion,
       ld.peso_kg,
       'TERRESTRE'                    AS tipo_transporte,
       ld.dni_conductor,
       ld.placa_vehiculo              AS placa,
       ld.destino,
       c.codigo                       AS constancia
  FROM lote_destino ld
  JOIN detalle_desembarque dd ON dd.id_detalle = ld.id_detalle
  JOIN especie es             ON es.id_especie = dd.id_especie
  JOIN desembarque d          ON d.id_desembarque = dd.id_desembarque
  JOIN embarcacion e          ON e.id_embarcacion = d.id_embarcacion
  JOIN lugar_desembarque l    ON l.id_lugar = d.id_lugar
  LEFT JOIN constancia c      ON c.id_desembarque = d.id_desembarque
 WHERE d.estado_registro = 'EMITIDO';

-- Permisos que vencen en 30 días (RF22)
CREATE OR REPLACE VIEW v_permisos_por_vencer AS
SELECT p.id_permiso, p.numero_resolucion, p.fecha_vencimiento, e.matricula, a.nombre AS armador, a.celular
  FROM permiso_pesca p
  JOIN embarcacion e USING (id_embarcacion)
  JOIN armador a     ON a.id_armador = e.id_armador
 WHERE p.fecha_vencimiento BETWEEN CURRENT_DATE AND CURRENT_DATE + 30;

-- =====================================================================
-- 17. Datos iniciales
--     Tallas mínimas: R.M. 209-2001-PE y modificatorias R.M. 000109-2025-PRODUCE
--     (lorna) y R.M. 000191-2025-PRODUCE (cabrilla). Verificar contra la
--     normativa vigente antes de pasar a producción.
-- =====================================================================
INSERT INTO parametro VALUES
    ('KG_POR_M3_BODEGA',      1000, 'Kilos máximos esperados por m³ de bodega (regla CAPACIDAD_BODEGA)'),
    ('MAX_INTENTOS_LOGIN',       5, 'Intentos fallidos antes del bloqueo (RNF08)'),
    ('MINUTOS_BLOQUEO',         15, 'Minutos de bloqueo tras superar los intentos (HU02)'),
    ('DIAS_AVISO_PERMISO',      30, 'Días de anticipación para avisar el vencimiento del permiso (RF22)'),
    ('MAX_FOTOS',                3, 'Fotografías por desembarque (RF11)'),
    ('MAX_KB_FOTO',            300, 'Tamaño máximo de cada foto en KB (RNF05)');

INSERT INTO rol (codigo, nombre) VALUES                                                   -- RF01: siete roles
    ('REGISTRADOR',   'Registrador del DPA'),
    ('ADMIN_DPA',     'Administrador del DPA'),
    ('ARMADOR',       'Patrón / armador'),
    ('COMERCIANTE',   'Comerciante / planta'),
    ('FISCALIZADOR',  'Fiscalizador (PRODUCE / DIREPRO)'),
    ('ANALISTA',      'Analista (IMARPE / PRODUCE)'),
    ('ADMIN_SISTEMA', 'Administrador del sistema');

INSERT INTO especie (codigo_fao, nombre_comun, nombre_cientifico) VALUES
    ('VET', 'Anchoveta', 'Engraulis ringens'),
    ('CJM', 'Jurel',     'Trachurus murphyi'),
    ('MAS', 'Caballa',   'Scomber japonicus'),
    ('BEP', 'Bonito',    'Sarda chiliensis chiliensis'),
    ('GIS', 'Pota',      'Dosidicus gigas'),
    (NULL,  'Lorna',     'Callaus deliciosa'),                                            -- completar código ASFIS
    (NULL,  'Cabrilla',  'Paralabrax humeralis');

INSERT INTO talla_minima (id_especie, talla_minima_cm, tolerancia_juveniles_pct, norma, vigente_desde, vigente_hasta) VALUES
    (1, 12, 10, 'R.M. 209-2001-PE',           '2001-06-28', NULL),
    (2, 31, 30, 'R.M. 209-2001-PE',           '2001-06-28', NULL),
    (3, 29, 30, 'R.M. 209-2001-PE',           '2001-06-28', NULL),
    (4, 52, 10, 'R.M. 209-2001-PE',           '2001-06-28', NULL),
    (6, 24, 10, 'R.M. 209-2001-PE',           '2001-06-28', '2025-03-08'),
    (6, 21, 25, 'R.M. 000109-2025-PRODUCE',   '2025-03-09', NULL),
    (7, 32, 20, 'R.M. 209-2001-PE',           '2001-06-28', '2025-05-30'),
    (7, 27, 25, 'R.M. 000191-2025-PRODUCE',   '2025-05-31', NULL);

INSERT INTO arte_pesca (nombre, tipo, mecanizado) VALUES
    ('Cerco artesanal',     'CERCO',     FALSE),
    ('Cerco mecanizado',    'CERCO',     TRUE),
    ('Cortina (enmalle)',   'ENMALLE',   FALSE),
    ('Pinta (línea de mano)', 'ANZUELO', FALSE),
    ('Espinel',             'ANZUELO',   FALSE),
    ('Potera',              'ANZUELO',   FALSE);

INSERT INTO lugar_desembarque (codigo, nombre, tipo, region, ubicacion) VALUES
    ('DPA-PAITA', 'Desembarcadero Pesquero Artesanal de Paita (piloto)', 'DPA', 'Piura',
     ST_SetSRID(ST_MakePoint(-81.1100, -5.0870), 4326));

INSERT INTO zona_pesca (codigo_cuadricula, dentro_5_millas, dentro_3_millas, geom) VALUES
    ('PIU-0501', TRUE,  TRUE,  ST_MakeEnvelope(-81.20, -5.10, -81.15, -5.05, 4326)),
    ('PIU-0502', TRUE,  FALSE, ST_MakeEnvelope(-81.25, -5.10, -81.20, -5.05, 4326)),
    ('PIU-1001', FALSE, FALSE, ST_MakeEnvelope(-81.40, -5.10, -81.30, -5.00, 4326));

-- ---------------------------------------------------------------------
-- 18. Descripciones (fuente del diccionario de datos y del DBML)
-- ---------------------------------------------------------------------
COMMENT ON TABLE parametro IS 'Parámetros del motor de reglas que se ajustan sin programar (RNF12).';
COMMENT ON TABLE rol IS 'Siete roles con permisos diferenciados (RF01).';
COMMENT ON TABLE lugar_desembarque IS 'DPA, caletas y puntos donde la pesca artesanal llega a tierra.';
COMMENT ON TABLE usuario IS 'Persona autenticada con DNI, PIN y código por SMS (RF01, RNF08).';
COMMENT ON TABLE armador IS 'Titular de embarcaciones; recibe la constancia por SMS.';
COMMENT ON TABLE embarcacion IS 'Embarcación artesanal o de menor escala de hasta 32,6 m³ de bodega (RF02, RD01).';
COMMENT ON TABLE permiso_pesca IS 'Permiso de pesca con resolución, entidad emisora y vigencia (RF03).';
COMMENT ON TABLE comprador IS 'Comerciante, planta o mercado que recibe lotes (RF14).';
COMMENT ON TABLE especie IS 'Especie hidrobiológica con código 3-alfa ASFIS de la FAO (RF04, RNF11).';
COMMENT ON TABLE talla_minima IS 'Talla mínima y tolerancia de juveniles con vigencia; un cambio aplica solo a desembarques posteriores (RD03, HU05).';
COMMENT ON TABLE arte_pesca IS 'Artes y aparejos de pesca (RF04).';
COMMENT ON TABLE zona_pesca IS 'Cuadrícula de pesca; se registra la cuadrícula y no la coordenada exacta del caladero (RNF09, RD08).';
COMMENT ON TABLE veda IS 'Veda por especie y, opcionalmente, por zona, con su norma (RD04).';
COMMENT ON TABLE permiso_especie IS 'Especies autorizadas por cada permiso (N:M).';
COMMENT ON TABLE permiso_arte IS 'Artes autorizadas por cada permiso (N:M).';
COMMENT ON TABLE aviso_arribo IS 'Aviso previo del patrón con hora estimada y captura aproximada (RF05).';
COMMENT ON TABLE desembarque IS 'Entidad central: llegada de una faena de una embarcación a un lugar de desembarque (RF06).';
COMMENT ON TABLE detalle_desembarque IS 'Kilos por especie y presentación de un desembarque (RF07).';
COMMENT ON TABLE muestreo_talla IS 'Tallas de una muestra de ejemplares de un detalle (RF09).';
COMMENT ON TABLE evidencia_foto IS 'Hasta tres fotografías comprimidas por desembarque (RF11).';
COMMENT ON TABLE resultado_validacion IS 'Resultado de cada regla del motor normativo, no solo el estado final (RF10).';
COMMENT ON TABLE constancia IS 'Constancia digital con código único, QR y hash SHA-256 (RF13).';
COMMENT ON TABLE lote_destino IS 'Kilos de un detalle entregados a un comprador; base de la trazabilidad (RF14, RF15, RD05).';
COMMENT ON TABLE inspeccion IS 'Observación o acta del fiscalizador vinculada al desembarque (RF17).';
COMMENT ON TABLE alerta IS 'Alertas al fiscalizador y avisos de vencimiento de permisos (RF22).';
COMMENT ON TABLE cierre_diario IS 'Cierre del día por lugar de desembarque; bloquea la edición de sus registros (RF24).';
COMMENT ON TABLE auditoria IS 'Bitácora inmutable de creaciones, ediciones y anulaciones (RF23, RNF10).';
COMMENT ON COLUMN parametro.clave IS 'Nombre del parámetro';
COMMENT ON COLUMN parametro.valor IS 'Valor numérico';
COMMENT ON COLUMN parametro.descripcion IS 'Para qué sirve el parámetro';
COMMENT ON COLUMN rol.id_rol IS 'Identificador del rol';
COMMENT ON COLUMN rol.codigo IS 'Código del rol (REGISTRADOR, ADMIN_DPA, ...)';
COMMENT ON COLUMN rol.nombre IS 'Nombre visible del rol';
COMMENT ON COLUMN lugar_desembarque.id_lugar IS 'Identificador del lugar';
COMMENT ON COLUMN lugar_desembarque.codigo IS 'Código único del lugar';
COMMENT ON COLUMN lugar_desembarque.nombre IS 'Nombre del DPA o caleta';
COMMENT ON COLUMN lugar_desembarque.tipo IS 'DPA, CALETA o PUNTO_DESEMBARQUE';
COMMENT ON COLUMN lugar_desembarque.region IS 'Región';
COMMENT ON COLUMN lugar_desembarque.ubicacion IS 'Punto geográfico WGS84 (SRID 4326)';
COMMENT ON COLUMN usuario.id_usuario IS 'Identificador UUID del usuario';
COMMENT ON COLUMN usuario.dni IS 'DNI de 8 dígitos, único';
COMMENT ON COLUMN usuario.nombres IS 'Nombres y apellidos';
COMMENT ON COLUMN usuario.celular IS 'Celular que recibe el código OTP por SMS';
COMMENT ON COLUMN usuario.pin_hash IS 'PIN cifrado con Argon2 o bcrypt';
COMMENT ON COLUMN usuario.id_rol IS 'Rol asignado';
COMMENT ON COLUMN usuario.id_lugar IS 'DPA asignado';
COMMENT ON COLUMN usuario.activo IS 'Usuario habilitado';
COMMENT ON COLUMN usuario.intentos_fallidos IS 'Intentos fallidos consecutivos de ingreso';
COMMENT ON COLUMN usuario.bloqueado_hasta IS 'Fin del bloqueo temporal tras 5 intentos fallidos';
COMMENT ON COLUMN usuario.creado_en IS 'Fecha de creación';
COMMENT ON COLUMN armador.id_armador IS 'Identificador del armador';
COMMENT ON COLUMN armador.tipo_documento IS 'DNI, CE o RUC';
COMMENT ON COLUMN armador.numero_documento IS 'Número de documento';
COMMENT ON COLUMN armador.nombre IS 'Nombre o razón social';
COMMENT ON COLUMN armador.celular IS 'Celular donde recibe el enlace de la constancia';
COMMENT ON COLUMN armador.id_usuario IS 'Cuenta de acceso para consultar su historial (opcional)';
COMMENT ON COLUMN armador.consentimiento_en IS 'Fecha del consentimiento para el tratamiento de datos personales (Ley 29733)';
COMMENT ON COLUMN embarcacion.id_embarcacion IS 'Identificador de la embarcación';
COMMENT ON COLUMN embarcacion.matricula IS 'Matrícula única';
COMMENT ON COLUMN embarcacion.nombre IS 'Nombre de la embarcación';
COMMENT ON COLUMN embarcacion.eslora_m IS 'Eslora en metros';
COMMENT ON COLUMN embarcacion.capacidad_bodega_m3 IS 'Capacidad de bodega en m³ (máximo 32,6)';
COMMENT ON COLUMN embarcacion.trabajo_manual IS 'Predominio del trabajo manual';
COMMENT ON COLUMN embarcacion.categoria IS 'ARTESANAL o MENOR_ESCALA';
COMMENT ON COLUMN embarcacion.id_armador IS 'Armador titular';
COMMENT ON COLUMN embarcacion.activa IS 'Embarcación habilitada';
COMMENT ON COLUMN permiso_pesca.id_permiso IS 'Identificador del permiso';
COMMENT ON COLUMN permiso_pesca.id_embarcacion IS 'Embarcación autorizada';
COMMENT ON COLUMN permiso_pesca.numero_resolucion IS 'Número de la resolución que otorga el permiso';
COMMENT ON COLUMN permiso_pesca.entidad_emisora IS 'PRODUCE o Gobierno Regional (DIREPRO)';
COMMENT ON COLUMN permiso_pesca.fecha_emision IS 'Inicio de vigencia';
COMMENT ON COLUMN permiso_pesca.fecha_vencimiento IS 'Fin de vigencia';
COMMENT ON COLUMN comprador.id_comprador IS 'Identificador del comprador';
COMMENT ON COLUMN comprador.tipo_documento IS 'DNI, CE o RUC';
COMMENT ON COLUMN comprador.numero_documento IS 'Número de documento';
COMMENT ON COLUMN comprador.nombre IS 'Nombre o razón social';
COMMENT ON COLUMN comprador.tipo IS 'COMERCIANTE, PLANTA, MERCADO o CONSUMIDOR';
COMMENT ON COLUMN comprador.id_usuario IS 'Cuenta para confirmar la recepción de lotes';
COMMENT ON COLUMN especie.id_especie IS 'Identificador de la especie';
COMMENT ON COLUMN especie.codigo_fao IS 'Código 3-alfa de la lista ASFIS de la FAO';
COMMENT ON COLUMN especie.nombre_comun IS 'Nombre común usado en el muelle';
COMMENT ON COLUMN especie.nombre_cientifico IS 'Nombre científico';
COMMENT ON COLUMN talla_minima.id_talla IS 'Identificador de la regla de talla';
COMMENT ON COLUMN talla_minima.id_especie IS 'Especie';
COMMENT ON COLUMN talla_minima.talla_minima_cm IS 'Talla mínima de captura en cm';
COMMENT ON COLUMN talla_minima.tolerancia_juveniles_pct IS 'Porcentaje máximo de ejemplares bajo la talla mínima';
COMMENT ON COLUMN talla_minima.norma IS 'Resolución que fija la talla';
COMMENT ON COLUMN talla_minima.vigente_desde IS 'Inicio de vigencia';
COMMENT ON COLUMN talla_minima.vigente_hasta IS 'Fin de vigencia (NULL = vigente)';
COMMENT ON COLUMN arte_pesca.id_arte IS 'Identificador del arte';
COMMENT ON COLUMN arte_pesca.nombre IS 'Nombre del arte de pesca';
COMMENT ON COLUMN arte_pesca.tipo IS 'Familia del arte (CERCO, ENMALLE, ANZUELO)';
COMMENT ON COLUMN arte_pesca.mecanizado IS 'Arte con sistemas mecanizados';
COMMENT ON COLUMN zona_pesca.id_zona IS 'Identificador de la zona';
COMMENT ON COLUMN zona_pesca.codigo_cuadricula IS 'Código de la cuadrícula de pesca';
COMMENT ON COLUMN zona_pesca.dentro_5_millas IS 'Cuadrícula dentro de las 5 millas';
COMMENT ON COLUMN zona_pesca.dentro_3_millas IS 'Cuadrícula dentro de las 3 millas';
COMMENT ON COLUMN zona_pesca.geom IS 'Polígono de la cuadrícula (SRID 4326)';
COMMENT ON COLUMN veda.id_veda IS 'Identificador de la veda';
COMMENT ON COLUMN veda.id_especie IS 'Especie en veda';
COMMENT ON COLUMN veda.id_zona IS 'Zona de la veda (NULL = todo el litoral)';
COMMENT ON COLUMN veda.fecha_inicio IS 'Inicio de la veda';
COMMENT ON COLUMN veda.fecha_fin IS 'Fin de la veda';
COMMENT ON COLUMN veda.norma IS 'Resolución que dispone la veda';
COMMENT ON COLUMN permiso_especie.id_permiso IS 'Permiso';
COMMENT ON COLUMN permiso_especie.id_especie IS 'Especie autorizada';
COMMENT ON COLUMN permiso_arte.id_permiso IS 'Permiso';
COMMENT ON COLUMN permiso_arte.id_arte IS 'Arte autorizada';
COMMENT ON COLUMN aviso_arribo.id_aviso IS 'Identificador del aviso';
COMMENT ON COLUMN aviso_arribo.id_embarcacion IS 'Embarcación que llega';
COMMENT ON COLUMN aviso_arribo.id_lugar IS 'DPA de llegada';
COMMENT ON COLUMN aviso_arribo.hora_estimada IS 'Hora estimada de llegada';
COMMENT ON COLUMN aviso_arribo.captura_aproximada IS 'Descripción libre de lo que trae';
COMMENT ON COLUMN aviso_arribo.estado IS 'PENDIENTE, ATENDIDO o CANCELADO';
COMMENT ON COLUMN aviso_arribo.creado_en IS 'Fecha de envío del aviso';
COMMENT ON COLUMN desembarque.id_desembarque IS 'UUID generado en el celular; también es la Idempotency-Key';
COMMENT ON COLUMN desembarque.id_embarcacion IS 'Embarcación';
COMMENT ON COLUMN desembarque.id_lugar IS 'Lugar de desembarque';
COMMENT ON COLUMN desembarque.id_registrador IS 'Usuario que registró';
COMMENT ON COLUMN desembarque.id_aviso IS 'Aviso de arribo que lo originó';
COMMENT ON COLUMN desembarque.codigo_faena IS 'Código de faena (RD05)';
COMMENT ON COLUMN desembarque.fecha_zarpe IS 'Fecha y hora de zarpe';
COMMENT ON COLUMN desembarque.fecha_hora_arribo IS 'Fecha y hora de arribo';
COMMENT ON COLUMN desembarque.id_zona IS 'Cuadrícula de pesca';
COMMENT ON COLUMN desembarque.id_arte IS 'Arte de pesca empleado';
COMMENT ON COLUMN desembarque.tripulantes IS 'Número de tripulantes';
COMMENT ON COLUMN desembarque.estado_validacion IS 'CONFORME, OBSERVADO o NO_CONFORME';
COMMENT ON COLUMN desembarque.estado_registro IS 'BORRADOR, EMITIDO o ANULADO';
COMMENT ON COLUMN desembarque.origen IS 'APP_MOVIL o PORTAL_WEB';
COMMENT ON COLUMN desembarque.registrado_en IS 'Hora de registro en el celular';
COMMENT ON COLUMN desembarque.sincronizado_en IS 'Hora de llegada al servidor';
COMMENT ON COLUMN desembarque.motivo_anulacion IS 'Motivo obligatorio de la anulación';
COMMENT ON COLUMN desembarque.anulado_por IS 'Usuario que anuló';
COMMENT ON COLUMN desembarque.anulado_en IS 'Fecha de anulación';
COMMENT ON COLUMN detalle_desembarque.id_detalle IS 'Identificador del detalle';
COMMENT ON COLUMN detalle_desembarque.id_desembarque IS 'Desembarque';
COMMENT ON COLUMN detalle_desembarque.id_especie IS 'Especie';
COMMENT ON COLUMN detalle_desembarque.peso_kg IS 'Peso en kg (mayor que cero)';
COMMENT ON COLUMN detalle_desembarque.unidades IS 'Número de ejemplares (opcional)';
COMMENT ON COLUMN detalle_desembarque.presentacion IS 'Presentación (entero, eviscerado, ...)';
COMMENT ON COLUMN detalle_desembarque.precio_playa_kg IS 'Precio en playa por kg (S/)';
COMMENT ON COLUMN muestreo_talla.id_muestreo IS 'Identificador del muestreo';
COMMENT ON COLUMN muestreo_talla.id_detalle IS 'Detalle muestreado';
COMMENT ON COLUMN muestreo_talla.tallas_cm IS 'Tallas medidas en cm';
COMMENT ON COLUMN muestreo_talla.pct_bajo_talla IS 'Porcentaje bajo la talla mínima vigente (lo calcula la validación)';
COMMENT ON COLUMN muestreo_talla.registrado_en IS 'Fecha del muestreo';
COMMENT ON COLUMN evidencia_foto.id_foto IS 'Identificador de la foto';
COMMENT ON COLUMN evidencia_foto.id_desembarque IS 'Desembarque';
COMMENT ON COLUMN evidencia_foto.url IS 'Ubicación del archivo';
COMMENT ON COLUMN evidencia_foto.hash_sha256 IS 'Hash SHA-256 de la imagen';
COMMENT ON COLUMN evidencia_foto.tamano_kb IS 'Tamaño en KB (máximo 300)';
COMMENT ON COLUMN evidencia_foto.tomada_en IS 'Fecha de la foto';
COMMENT ON COLUMN resultado_validacion.id_resultado IS 'Identificador del resultado';
COMMENT ON COLUMN resultado_validacion.id_desembarque IS 'Desembarque evaluado';
COMMENT ON COLUMN resultado_validacion.regla IS 'Regla evaluada (PERMISO_VIGENTE, VEDA, TALLA_MINIMA, ...)';
COMMENT ON COLUMN resultado_validacion.nivel IS 'Nivel del resultado';
COMMENT ON COLUMN resultado_validacion.mensaje IS 'Explicación en lenguaje sencillo';
COMMENT ON COLUMN resultado_validacion.norma IS 'Norma que sustenta la regla';
COMMENT ON COLUMN resultado_validacion.evaluado_en IS 'Fecha de evaluación';
COMMENT ON COLUMN constancia.id_constancia IS 'Identificador de la constancia';
COMMENT ON COLUMN constancia.id_desembarque IS 'Desembarque certificado (0..1 constancia por desembarque)';
COMMENT ON COLUMN constancia.codigo IS 'Código único impreso en la constancia';
COMMENT ON COLUMN constancia.hash_sha256 IS 'Huella SHA-256 del contenido canónico';
COMMENT ON COLUMN constancia.url_qr IS 'Enlace de verificación codificado en el QR';
COMMENT ON COLUMN constancia.fecha_emision IS 'Fecha de emisión';
COMMENT ON COLUMN constancia.sms_enviado_en IS 'Fecha de envío del SMS al armador';
COMMENT ON COLUMN lote_destino.id_lote IS 'Identificador del lote';
COMMENT ON COLUMN lote_destino.id_detalle IS 'Detalle del que sale el lote';
COMMENT ON COLUMN lote_destino.id_comprador IS 'Comprador';
COMMENT ON COLUMN lote_destino.peso_kg IS 'Kilos asignados';
COMMENT ON COLUMN lote_destino.placa_vehiculo IS 'Placa del vehículo';
COMMENT ON COLUMN lote_destino.dni_conductor IS 'DNI del conductor';
COMMENT ON COLUMN lote_destino.destino IS 'Destino declarado';
COMMENT ON COLUMN lote_destino.estado IS 'DESPACHADO o RECIBIDO';
COMMENT ON COLUMN lote_destino.despachado_en IS 'Fecha de despacho';
COMMENT ON COLUMN lote_destino.recibido_en IS 'Fecha de recepción confirmada';
COMMENT ON COLUMN lote_destino.recibido_por IS 'Usuario que confirmó la recepción';
COMMENT ON COLUMN inspeccion.id_inspeccion IS 'Identificador de la inspección';
COMMENT ON COLUMN inspeccion.id_desembarque IS 'Desembarque inspeccionado';
COMMENT ON COLUMN inspeccion.id_fiscalizador IS 'Fiscalizador';
COMMENT ON COLUMN inspeccion.fecha_hora IS 'Fecha y hora';
COMMENT ON COLUMN inspeccion.resultado IS 'SIN_OBSERVACION, OBSERVACION o ACTA';
COMMENT ON COLUMN inspeccion.numero_acta IS 'Número de acta (obligatorio si hay acta)';
COMMENT ON COLUMN inspeccion.observacion IS 'Detalle de la observación';
COMMENT ON COLUMN alerta.id_alerta IS 'Identificador de la alerta';
COMMENT ON COLUMN alerta.tipo IS 'NO_CONFORME o PERMISO_POR_VENCER';
COMMENT ON COLUMN alerta.id_desembarque IS 'Desembarque relacionado';
COMMENT ON COLUMN alerta.id_permiso IS 'Permiso relacionado';
COMMENT ON COLUMN alerta.mensaje IS 'Texto de la alerta';
COMMENT ON COLUMN alerta.creada_en IS 'Fecha de creación';
COMMENT ON COLUMN alerta.atendida_por IS 'Usuario que la atendió';
COMMENT ON COLUMN alerta.atendida_en IS 'Fecha de atención';
COMMENT ON COLUMN cierre_diario.id_cierre IS 'Identificador del cierre';
COMMENT ON COLUMN cierre_diario.id_lugar IS 'Lugar de desembarque';
COMMENT ON COLUMN cierre_diario.fecha IS 'Día cerrado';
COMMENT ON COLUMN cierre_diario.kg_registrados IS 'Kilos registrados en el día';
COMMENT ON COLUMN cierre_diario.kg_despachados IS 'Kilos despachados en lotes';
COMMENT ON COLUMN cierre_diario.cerrado_por IS 'Usuario que cerró el día';
COMMENT ON COLUMN cierre_diario.cerrado_en IS 'Fecha del cierre';
COMMENT ON COLUMN auditoria.id_auditoria IS 'Identificador del registro de auditoría';
COMMENT ON COLUMN auditoria.tabla IS 'Tabla afectada';
COMMENT ON COLUMN auditoria.operacion IS 'I (creación), U (edición) o D (eliminación)';
COMMENT ON COLUMN auditoria.id_registro IS 'Clave del registro afectado';
COMMENT ON COLUMN auditoria.datos_antes IS 'Registro antes del cambio (JSON)';
COMMENT ON COLUMN auditoria.datos_despues IS 'Registro después del cambio (JSON)';
COMMENT ON COLUMN auditoria.usuario_app IS 'Usuario de la aplicación que hizo el cambio';
COMMENT ON COLUMN auditoria.fecha IS 'Fecha del cambio';

COMMIT;
