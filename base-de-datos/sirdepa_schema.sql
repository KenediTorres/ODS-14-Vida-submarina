-- =====================================================================
--  SIRDEPA - Sistema de Registro de Desembarque Pesquero Artesanal
--  Proyecto "Vida Submarina" (ODS 14) - Análisis y Diseño de Software
--  Motor: PostgreSQL 16 + PostGIS 3
--
--  Basado en el Modelo E-R del informe (Capítulo 3) y el diagrama de
--  clases (Capítulo 4): Embarcación, Pescador, Captura, DetalleCaptura,
--  Especie, Lote, Localización, SensorRegistro, MonitoreoGPS, Permiso,
--  Usuario y Alerta.
--
--  Uso:
--    createdb sirdepa
--    psql -d sirdepa -f sirdepa_schema.sql
-- =====================================================================

BEGIN;

CREATE EXTENSION IF NOT EXISTS postgis;
CREATE EXTENSION IF NOT EXISTS pgcrypto;   -- gen_random_uuid() para códigos QR

DROP SCHEMA IF EXISTS sirdepa CASCADE;
CREATE SCHEMA sirdepa;
SET search_path TO sirdepa, public;

-- ---------------------------------------------------------------------
-- 1. Tipos enumerados
-- ---------------------------------------------------------------------
CREATE TYPE rol_usuario        AS ENUM ('ADMIN', 'IMARPE', 'PRODUCE', 'INSPECTOR', 'ARMADOR', 'PESCADOR', 'INVESTIGADOR');
CREATE TYPE tipo_embarcacion   AS ENUM ('ARTESANAL', 'MENOR_ESCALA', 'MAYOR_ESCALA');
CREATE TYPE estado_embarcacion AS ENUM ('ACTIVA', 'EN_PUERTO', 'SUSPENDIDA', 'BAJA');
CREATE TYPE tipo_zona          AS ENUM ('PERMITIDA', 'RESTRINGIDA', 'RESERVA_MARINA', 'VEDA_ESPACIAL');
CREATE TYPE estado_permiso     AS ENUM ('VIGENTE', 'VENCIDO', 'SUSPENDIDO', 'REVOCADO');
CREATE TYPE estado_validacion  AS ENUM ('PENDIENTE', 'CONFORME', 'OBSERVADA');
CREATE TYPE estado_lote        AS ENUM ('GENERADO', 'EN_TRANSITO', 'COMERCIALIZADO', 'OBSERVADO');
CREATE TYPE tipo_alerta        AS ENUM ('ZONA_RESTRINGIDA', 'TALLA_MINIMA', 'VEDA', 'CUOTA_EXCEDIDA', 'PERMISO_VENCIDO', 'SIN_SENAL_GPS', 'METEOROLOGICA');
CREATE TYPE nivel_gravedad     AS ENUM ('BAJA', 'MEDIA', 'ALTA', 'CRITICA');
CREATE TYPE estado_atencion    AS ENUM ('PENDIENTE', 'EN_REVISION', 'ATENDIDA', 'DESCARTADA');

-- ---------------------------------------------------------------------
-- 2. Usuarios del sistema (RNF 01.2: 2FA para usuarios críticos)
-- ---------------------------------------------------------------------
CREATE TABLE usuario (
    id_usr          SERIAL       PRIMARY KEY,
    nombre          VARCHAR(120) NOT NULL,
    email           VARCHAR(150) NOT NULL UNIQUE,
    password_hash   VARCHAR(255) NOT NULL,
    rol             rol_usuario  NOT NULL,
    auth_2fa        BOOLEAN      NOT NULL DEFAULT FALSE,
    activo          BOOLEAN      NOT NULL DEFAULT TRUE,
    creado_en       TIMESTAMPTZ  NOT NULL DEFAULT now(),
    CONSTRAINT ck_usuario_email CHECK (email ~* '^[^@\s]+@[^@\s]+\.[^@\s]+$'),
    CONSTRAINT ck_usuario_2fa_criticos CHECK (rol NOT IN ('ADMIN', 'IMARPE', 'PRODUCE', 'INSPECTOR') OR auth_2fa)
);

-- ---------------------------------------------------------------------
-- 3. Pescadores y embarcaciones
-- ---------------------------------------------------------------------
CREATE TABLE pescador (
    id_pesc         SERIAL       PRIMARY KEY,
    id_usr          INTEGER      UNIQUE REFERENCES usuario(id_usr) ON DELETE SET NULL,
    nombre          VARCHAR(120) NOT NULL,
    tipo_documento  VARCHAR(10)  NOT NULL DEFAULT 'DNI' CHECK (tipo_documento IN ('DNI', 'CE', 'RUC')),
    documento       VARCHAR(15)  NOT NULL UNIQUE,
    comunidad       VARCHAR(120),
    contacto        VARCHAR(60),
    creado_en       TIMESTAMPTZ  NOT NULL DEFAULT now()
);

CREATE TABLE embarcacion (
    id_emb             SERIAL             PRIMARY KEY,
    matricula          VARCHAR(20)        NOT NULL UNIQUE,
    nombre             VARCHAR(100)       NOT NULL,
    tipo               tipo_embarcacion   NOT NULL DEFAULT 'ARTESANAL',
    eslora_m           NUMERIC(5,2)       CHECK (eslora_m > 0),
    capacidad_bodega_m3 NUMERIC(7,2)      CHECK (capacidad_bodega_m3 >= 0),
    estado             estado_embarcacion NOT NULL DEFAULT 'ACTIVA',
    owner_id           INTEGER            NOT NULL REFERENCES pescador(id_pesc),
    creado_en          TIMESTAMPTZ        NOT NULL DEFAULT now()
);

-- ---------------------------------------------------------------------
-- 4. Zonas de pesca, especies y vedas
-- ---------------------------------------------------------------------
CREATE TABLE zona (
    id_zona         SERIAL       PRIMARY KEY,
    nombre          VARCHAR(120) NOT NULL,
    tipo            tipo_zona    NOT NULL,
    norma_legal     VARCHAR(120),
    vigente_desde   DATE         NOT NULL DEFAULT CURRENT_DATE,
    vigente_hasta   DATE,
    geom            geometry(MultiPolygon, 4326) NOT NULL,
    CONSTRAINT ck_zona_vigencia CHECK (vigente_hasta IS NULL OR vigente_hasta >= vigente_desde)
);

CREATE TABLE especie (
    id_esp            SERIAL        PRIMARY KEY,
    nombre_cientifico VARCHAR(120)  NOT NULL UNIQUE,
    nombre_comun      VARCHAR(80)   NOT NULL,
    talla_minima_cm   NUMERIC(6,2)  CHECK (talla_minima_cm > 0),
    cuota_anual_t     NUMERIC(12,2) CHECK (cuota_anual_t >= 0)
);

CREATE TABLE veda (
    id_veda         SERIAL       PRIMARY KEY,
    id_esp          INTEGER      NOT NULL REFERENCES especie(id_esp),
    id_zona         INTEGER      REFERENCES zona(id_zona),      -- NULL = todo el litoral
    fecha_inicio    DATE         NOT NULL,
    fecha_fin       DATE         NOT NULL,
    norma_legal     VARCHAR(120),
    CONSTRAINT ck_veda_fechas CHECK (fecha_fin >= fecha_inicio)
);

-- ---------------------------------------------------------------------
-- 5. Permisos de pesca (Usuario 1..* gestiona Permiso; Permiso N..* Especie)
-- ---------------------------------------------------------------------
CREATE TABLE permiso (
    id_perm           SERIAL         PRIMARY KEY,
    id_emb            INTEGER        NOT NULL REFERENCES embarcacion(id_emb),
    gestionado_por    INTEGER        REFERENCES usuario(id_usr),
    tipo_permiso      VARCHAR(60)    NOT NULL,
    numero_resolucion VARCHAR(60)    NOT NULL UNIQUE,
    fecha_inicio      DATE           NOT NULL,
    fecha_fin         DATE           NOT NULL,
    estado            estado_permiso NOT NULL DEFAULT 'VIGENTE',
    CONSTRAINT ck_permiso_fechas CHECK (fecha_fin >= fecha_inicio)
);

CREATE TABLE permiso_especie (
    id_perm  INTEGER NOT NULL REFERENCES permiso(id_perm) ON DELETE CASCADE,
    id_esp   INTEGER NOT NULL REFERENCES especie(id_esp),
    PRIMARY KEY (id_perm, id_esp)
);

-- ---------------------------------------------------------------------
-- 6. Localizaciones (puntos de desembarque / faena)
-- ---------------------------------------------------------------------
CREATE TABLE localizacion (
    id_loc     SERIAL        PRIMARY KEY,
    nombre     VARCHAR(120)  NOT NULL,
    latitud    NUMERIC(9,6)  NOT NULL CHECK (latitud  BETWEEN -90  AND 90),
    longitud   NUMERIC(9,6)  NOT NULL CHECK (longitud BETWEEN -180 AND 180),
    geom       geometry(Point, 4326)
               GENERATED ALWAYS AS (ST_SetSRID(ST_MakePoint(longitud::float8, latitud::float8), 4326)) STORED,
    id_zona    INTEGER       REFERENCES zona(id_zona)
);

-- ---------------------------------------------------------------------
-- 7. Monitoreo GPS (RF01.1: posición cada 15 min) y sensores (RF01.6)
-- ---------------------------------------------------------------------
CREATE TABLE posicion_gps (
    id_pos             BIGSERIAL     PRIMARY KEY,
    id_emb             INTEGER       NOT NULL REFERENCES embarcacion(id_emb),
    fecha_hora         TIMESTAMPTZ   NOT NULL,
    latitud            NUMERIC(9,6)  NOT NULL CHECK (latitud  BETWEEN -90  AND 90),
    longitud           NUMERIC(9,6)  NOT NULL CHECK (longitud BETWEEN -180 AND 180),
    geom               geometry(Point, 4326)
                       GENERATED ALWAYS AS (ST_SetSRID(ST_MakePoint(longitud::float8, latitud::float8), 4326)) STORED,
    velocidad_nudos    NUMERIC(5,2)  CHECK (velocidad_nudos >= 0),
    rumbo_grados       NUMERIC(5,2)  CHECK (rumbo_grados >= 0 AND rumbo_grados < 360),
    en_zona_permitida  BOOLEAN       NOT NULL DEFAULT TRUE,
    recibido_en        TIMESTAMPTZ   NOT NULL DEFAULT now(),   -- sync inmediata o batch
    CONSTRAINT uq_posicion UNIQUE (id_emb, fecha_hora)
);

CREATE TABLE sensor_registro (
    id_reg       BIGSERIAL    PRIMARY KEY,
    id_emb       INTEGER      NOT NULL REFERENCES embarcacion(id_emb),
    ts           TIMESTAMPTZ  NOT NULL,
    latitud      NUMERIC(9,6),
    longitud     NUMERIC(9,6),
    tipo_sensor  VARCHAR(40)  NOT NULL CHECK (tipo_sensor IN ('TEMPERATURA_AGUA', 'SALINIDAD', 'OXIGENO', 'VIENTO', 'OLEAJE', 'PRESION')),
    valor        NUMERIC(10,3) NOT NULL,
    unidad       VARCHAR(15)  NOT NULL
);

-- ---------------------------------------------------------------------
-- 8. Trazabilidad: lotes con código QR (RF01.5)
-- ---------------------------------------------------------------------
CREATE TABLE lote (
    id_lote              SERIAL      PRIMARY KEY,
    codigo_qr            UUID        NOT NULL UNIQUE DEFAULT gen_random_uuid(),
    fecha_creacion       TIMESTAMPTZ NOT NULL DEFAULT now(),
    estado_trazabilidad  estado_lote NOT NULL DEFAULT 'GENERADO',
    destino              VARCHAR(150)
);

-- ---------------------------------------------------------------------
-- 9. Capturas / bitácora digital (RF01.3) y detalle por especie
-- ---------------------------------------------------------------------
CREATE TABLE captura (
    id_capt            SERIAL            PRIMARY KEY,
    id_emb             INTEGER           NOT NULL REFERENCES embarcacion(id_emb),
    id_lote            INTEGER           REFERENCES lote(id_lote),
    id_loc             INTEGER           REFERENCES localizacion(id_loc),
    registrado_por     INTEGER           REFERENCES usuario(id_usr),
    fecha_hora         TIMESTAMPTZ       NOT NULL,
    total_kg           NUMERIC(12,2)     NOT NULL DEFAULT 0 CHECK (total_kg >= 0),
    temperatura_agua_c NUMERIC(4,1),
    arte_pesca         VARCHAR(60),
    estado_validacion  estado_validacion NOT NULL DEFAULT 'PENDIENTE',
    observaciones      TEXT,
    creado_en          TIMESTAMPTZ       NOT NULL DEFAULT now()
);

CREATE TABLE detalle_captura (
    id_det               SERIAL        PRIMARY KEY,
    id_capt              INTEGER       NOT NULL REFERENCES captura(id_capt) ON DELETE CASCADE,
    id_esp               INTEGER       NOT NULL REFERENCES especie(id_esp),
    cantidad_kg          NUMERIC(12,2) NOT NULL CHECK (cantidad_kg > 0),
    cantidad_unidades    INTEGER       CHECK (cantidad_unidades >= 0),
    talla_promedio_cm    NUMERIC(6,2)  CHECK (talla_promedio_cm > 0),
    cumple_talla_minima  BOOLEAN,       -- calculado por trigger
    CONSTRAINT uq_detalle_especie UNIQUE (id_capt, id_esp)
);

-- Evidencia fotográfica (RF01.4)
CREATE TABLE evidencia_foto (
    id_foto      SERIAL       PRIMARY KEY,
    id_capt      INTEGER      NOT NULL REFERENCES captura(id_capt) ON DELETE CASCADE,
    url          TEXT         NOT NULL,
    hash_sha256  CHAR(64)     NOT NULL,
    tomada_en    TIMESTAMPTZ  NOT NULL DEFAULT now()
);

-- ---------------------------------------------------------------------
-- 10. Alertas (RF01.2, RF01.7)
-- ---------------------------------------------------------------------
CREATE TABLE alerta (
    id_alerta        SERIAL          PRIMARY KEY,
    id_emb           INTEGER         NOT NULL REFERENCES embarcacion(id_emb),
    id_pos           BIGINT          REFERENCES posicion_gps(id_pos),
    id_capt          INTEGER         REFERENCES captura(id_capt) ON DELETE SET NULL,
    tipo_alerta      tipo_alerta     NOT NULL,
    descripcion      TEXT            NOT NULL,
    nivel_gravedad   nivel_gravedad  NOT NULL DEFAULT 'MEDIA',
    estado_atencion  estado_atencion NOT NULL DEFAULT 'PENDIENTE',
    fecha_hora       TIMESTAMPTZ     NOT NULL DEFAULT now(),
    atendida_por     INTEGER         REFERENCES usuario(id_usr),
    atendida_en      TIMESTAMPTZ
);

-- ---------------------------------------------------------------------
-- 11. Auditoría de cambios
-- ---------------------------------------------------------------------
CREATE TABLE auditoria (
    id_aud         BIGSERIAL    PRIMARY KEY,
    tabla          VARCHAR(60)  NOT NULL,
    operacion      CHAR(1)      NOT NULL CHECK (operacion IN ('I', 'U', 'D')),
    id_registro    TEXT,
    datos_antes    JSONB,
    datos_despues  JSONB,
    usuario_db     TEXT         NOT NULL DEFAULT current_user,
    fecha          TIMESTAMPTZ  NOT NULL DEFAULT now()
);

-- ---------------------------------------------------------------------
-- 12. Índices (RNF 01.1: consultas < 3 s; RNF 01.4: 10 000 embarcaciones)
-- ---------------------------------------------------------------------
CREATE INDEX ix_embarcacion_owner     ON embarcacion (owner_id);
CREATE INDEX ix_zona_geom             ON zona USING GIST (geom);
CREATE INDEX ix_localizacion_geom     ON localizacion USING GIST (geom);
CREATE INDEX ix_posicion_emb_fecha    ON posicion_gps (id_emb, fecha_hora DESC);
CREATE INDEX ix_posicion_geom         ON posicion_gps USING GIST (geom);
CREATE INDEX ix_sensor_emb_ts         ON sensor_registro (id_emb, ts DESC);
CREATE INDEX ix_captura_emb_fecha     ON captura (id_emb, fecha_hora DESC);
CREATE INDEX ix_captura_lote          ON captura (id_lote);
CREATE INDEX ix_detalle_especie       ON detalle_captura (id_esp);
CREATE INDEX ix_permiso_emb_vigencia  ON permiso (id_emb, fecha_inicio, fecha_fin);
CREATE INDEX ix_veda_especie_fechas   ON veda (id_esp, fecha_inicio, fecha_fin);
CREATE INDEX ix_alerta_pendientes     ON alerta (estado_atencion, nivel_gravedad) WHERE estado_atencion IN ('PENDIENTE', 'EN_REVISION');
CREATE INDEX ix_auditoria_tabla_fecha ON auditoria (tabla, fecha DESC);

-- ---------------------------------------------------------------------
-- 13. Funciones y triggers de validación automática
-- ---------------------------------------------------------------------

-- 13.1 Posición GPS dentro de zona restringida -> marca y genera alerta (RF01.2)
CREATE OR REPLACE FUNCTION fn_validar_zona_gps() RETURNS trigger AS $$
DECLARE
    v_zona RECORD;
BEGIN
    SELECT z.id_zona, z.nombre, z.tipo INTO v_zona
      FROM zona z
     WHERE z.tipo IN ('RESTRINGIDA', 'RESERVA_MARINA', 'VEDA_ESPACIAL')
       AND NEW.fecha_hora::date >= z.vigente_desde
       AND (z.vigente_hasta IS NULL OR NEW.fecha_hora::date <= z.vigente_hasta)
       AND ST_Intersects(z.geom, ST_SetSRID(ST_MakePoint(NEW.longitud::float8, NEW.latitud::float8), 4326))
     LIMIT 1;

    IF FOUND THEN
        UPDATE posicion_gps SET en_zona_permitida = FALSE WHERE id_pos = NEW.id_pos;
        INSERT INTO alerta (id_emb, id_pos, tipo_alerta, descripcion, nivel_gravedad, fecha_hora)
        VALUES (NEW.id_emb, NEW.id_pos, 'ZONA_RESTRINGIDA',
                format('Embarcación %s ingresó a zona %s (%s)', NEW.id_emb, v_zona.nombre, v_zona.tipo),
                'ALTA', NEW.fecha_hora);
    END IF;
    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER tg_posicion_zona
AFTER INSERT ON posicion_gps
FOR EACH ROW EXECUTE FUNCTION fn_validar_zona_gps();

-- 13.2 Talla mínima y veda en cada detalle de captura
CREATE OR REPLACE FUNCTION fn_validar_detalle() RETURNS trigger AS $$
DECLARE
    v_esp     especie%ROWTYPE;
    v_capt    captura%ROWTYPE;
BEGIN
    SELECT * INTO v_esp  FROM especie WHERE id_esp  = NEW.id_esp;
    SELECT * INTO v_capt FROM captura WHERE id_capt = NEW.id_capt;

    NEW.cumple_talla_minima :=
        CASE WHEN v_esp.talla_minima_cm IS NULL OR NEW.talla_promedio_cm IS NULL THEN NULL
             ELSE NEW.talla_promedio_cm >= v_esp.talla_minima_cm END;

    IF NEW.cumple_talla_minima IS FALSE THEN
        INSERT INTO alerta (id_emb, id_capt, tipo_alerta, descripcion, nivel_gravedad)
        VALUES (v_capt.id_emb, NEW.id_capt, 'TALLA_MINIMA',
                format('%s: talla promedio %s cm < mínima %s cm', v_esp.nombre_comun, NEW.talla_promedio_cm, v_esp.talla_minima_cm),
                'MEDIA');
    END IF;

    IF EXISTS (SELECT 1 FROM veda v
                WHERE v.id_esp = NEW.id_esp
                  AND v_capt.fecha_hora::date BETWEEN v.fecha_inicio AND v.fecha_fin) THEN
        INSERT INTO alerta (id_emb, id_capt, tipo_alerta, descripcion, nivel_gravedad)
        VALUES (v_capt.id_emb, NEW.id_capt, 'VEDA',
                format('Captura de %s durante periodo de veda', v_esp.nombre_comun), 'ALTA');
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER tg_detalle_validar
BEFORE INSERT OR UPDATE OF id_esp, talla_promedio_cm ON detalle_captura
FOR EACH ROW EXECUTE FUNCTION fn_validar_detalle();

-- 13.3 Mantener total_kg de la captura sincronizado con su detalle
CREATE OR REPLACE FUNCTION fn_recalcular_total() RETURNS trigger AS $$
DECLARE
    v_id INTEGER := COALESCE(NEW.id_capt, OLD.id_capt);
BEGIN
    UPDATE captura
       SET total_kg = COALESCE((SELECT SUM(cantidad_kg) FROM detalle_captura WHERE id_capt = v_id), 0)
     WHERE id_capt = v_id;
    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER tg_detalle_total
AFTER INSERT OR UPDATE OR DELETE ON detalle_captura
FOR EACH ROW EXECUTE FUNCTION fn_recalcular_total();

-- 13.4 Captura sin permiso vigente -> alerta
CREATE OR REPLACE FUNCTION fn_validar_permiso() RETURNS trigger AS $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM permiso p
                    WHERE p.id_emb = NEW.id_emb
                      AND p.estado = 'VIGENTE'
                      AND NEW.fecha_hora::date BETWEEN p.fecha_inicio AND p.fecha_fin) THEN
        INSERT INTO alerta (id_emb, id_capt, tipo_alerta, descripcion, nivel_gravedad)
        VALUES (NEW.id_emb, NEW.id_capt, 'PERMISO_VENCIDO',
                'Captura registrada sin permiso de pesca vigente', 'CRITICA');
    END IF;
    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER tg_captura_permiso
AFTER INSERT ON captura
FOR EACH ROW EXECUTE FUNCTION fn_validar_permiso();

-- 13.5 Auditoría genérica
CREATE OR REPLACE FUNCTION fn_auditoria() RETURNS trigger AS $$
BEGIN
    INSERT INTO auditoria (tabla, operacion, id_registro, datos_antes, datos_despues)
    VALUES (TG_TABLE_NAME,
            left(TG_OP, 1),
            COALESCE((to_jsonb(NEW) ->> TG_ARGV[0]), (to_jsonb(OLD) ->> TG_ARGV[0])),
            CASE WHEN TG_OP IN ('UPDATE', 'DELETE') THEN to_jsonb(OLD) END,
            CASE WHEN TG_OP IN ('INSERT', 'UPDATE') THEN to_jsonb(NEW) END);
    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER tg_aud_embarcacion AFTER INSERT OR UPDATE OR DELETE ON embarcacion     FOR EACH ROW EXECUTE FUNCTION fn_auditoria('id_emb');
CREATE TRIGGER tg_aud_permiso     AFTER INSERT OR UPDATE OR DELETE ON permiso         FOR EACH ROW EXECUTE FUNCTION fn_auditoria('id_perm');
CREATE TRIGGER tg_aud_captura     AFTER INSERT OR UPDATE OR DELETE ON captura         FOR EACH ROW EXECUTE FUNCTION fn_auditoria('id_capt');
CREATE TRIGGER tg_aud_detalle     AFTER INSERT OR UPDATE OR DELETE ON detalle_captura FOR EACH ROW EXECUTE FUNCTION fn_auditoria('id_det');
CREATE TRIGGER tg_aud_alerta      AFTER UPDATE ON alerta                              FOR EACH ROW EXECUTE FUNCTION fn_auditoria('id_alerta');

-- ---------------------------------------------------------------------
-- 14. Vistas para reportes y dashboards
-- ---------------------------------------------------------------------
CREATE OR REPLACE VIEW v_desembarque_por_especie AS
SELECT e.nombre_comun,
       e.nombre_cientifico,
       date_trunc('month', c.fecha_hora)::date       AS mes,
       SUM(d.cantidad_kg)                            AS total_kg,
       COUNT(DISTINCT c.id_capt)                     AS n_capturas,
       ROUND(100.0 * AVG(CASE WHEN d.cumple_talla_minima THEN 1 ELSE 0 END), 1) AS pct_cumple_talla
  FROM detalle_captura d
  JOIN captura c ON c.id_capt = d.id_capt
  JOIN especie e ON e.id_esp  = d.id_esp
 GROUP BY e.nombre_comun, e.nombre_cientifico, date_trunc('month', c.fecha_hora);

CREATE OR REPLACE VIEW v_avance_cuota AS
SELECT e.id_esp,
       e.nombre_comun,
       e.cuota_anual_t,
       ROUND(COALESCE(SUM(d.cantidad_kg), 0) / 1000.0, 3) AS capturado_t,
       CASE WHEN e.cuota_anual_t > 0
            THEN ROUND(100.0 * COALESCE(SUM(d.cantidad_kg), 0) / 1000.0 / e.cuota_anual_t, 2) END AS pct_cuota
  FROM especie e
  LEFT JOIN detalle_captura d ON d.id_esp = e.id_esp
  LEFT JOIN captura c ON c.id_capt = d.id_capt
                     AND date_trunc('year', c.fecha_hora) = date_trunc('year', now())
 GROUP BY e.id_esp, e.nombre_comun, e.cuota_anual_t;

CREATE OR REPLACE VIEW v_alertas_pendientes AS
SELECT a.id_alerta, a.fecha_hora, a.tipo_alerta, a.nivel_gravedad,
       em.matricula, em.nombre AS embarcacion, a.descripcion
  FROM alerta a
  JOIN embarcacion em ON em.id_emb = a.id_emb
 WHERE a.estado_atencion IN ('PENDIENTE', 'EN_REVISION')
 ORDER BY a.nivel_gravedad DESC, a.fecha_hora DESC;

CREATE OR REPLACE VIEW v_ultima_posicion AS
SELECT DISTINCT ON (p.id_emb)
       p.id_emb, em.matricula, em.nombre, p.fecha_hora, p.latitud, p.longitud,
       p.en_zona_permitida, p.geom
  FROM posicion_gps p
  JOIN embarcacion em ON em.id_emb = p.id_emb
 ORDER BY p.id_emb, p.fecha_hora DESC;

-- Consulta pública de trazabilidad por QR (Mercado / Consumidores)
CREATE OR REPLACE VIEW v_trazabilidad_lote AS
SELECT l.codigo_qr, l.estado_trazabilidad, l.fecha_creacion,
       em.matricula, em.nombre AS embarcacion,
       c.fecha_hora AS fecha_captura, loc.nombre AS lugar_desembarque,
       e.nombre_comun, e.nombre_cientifico, d.cantidad_kg, d.cumple_talla_minima,
       c.estado_validacion
  FROM lote l
  JOIN captura c         ON c.id_lote = l.id_lote
  JOIN embarcacion em    ON em.id_emb = c.id_emb
  LEFT JOIN localizacion loc ON loc.id_loc = c.id_loc
  JOIN detalle_captura d ON d.id_capt = c.id_capt
  JOIN especie e         ON e.id_esp = d.id_esp;

-- ---------------------------------------------------------------------
-- 15. Datos semilla (referenciales para pruebas)
--     Las tallas mínimas y cuotas son valores de ejemplo; verificar
--     contra la normativa vigente de PRODUCE antes de usarlas en producción.
-- ---------------------------------------------------------------------
INSERT INTO especie (nombre_cientifico, nombre_comun, talla_minima_cm, cuota_anual_t) VALUES
    ('Engraulis ringens',          'Anchoveta', 12, NULL),
    ('Trachurus murphyi',          'Jurel',     31, NULL),
    ('Scomber japonicus',          'Caballa',   29, NULL),
    ('Merluccius gayi peruanus',   'Merluza',   28, NULL),
    ('Coryphaena hippurus',        'Perico',    70, NULL),
    ('Sarda chiliensis chiliensis','Bonito',    52, NULL),
    ('Dosidicus gigas',            'Pota',      NULL, NULL);

INSERT INTO usuario (nombre, email, password_hash, rol, auth_2fa) VALUES
    ('Administrador SIRDEPA', 'admin@sirdepa.pe',     'CAMBIAR_HASH', 'ADMIN',   TRUE),
    ('Analista IMARPE',       'analista@imarpe.pe',   'CAMBIAR_HASH', 'IMARPE',  TRUE),
    ('Fiscalizador PRODUCE',  'fiscal@produce.pe',    'CAMBIAR_HASH', 'PRODUCE', TRUE),
    ('Juan Quispe',           'jquispe@example.com',  'CAMBIAR_HASH', 'PESCADOR', FALSE);

INSERT INTO pescador (id_usr, nombre, documento, comunidad, contacto) VALUES
    (4, 'Juan Quispe', '40000001', 'Caleta San José - Lambayeque', '+51 900000001');

INSERT INTO embarcacion (matricula, nombre, tipo, eslora_m, capacidad_bodega_m3, owner_id) VALUES
    ('PL-00001-BM', 'Estrella del Mar', 'ARTESANAL', 9.50, 8.00, 1);

INSERT INTO zona (nombre, tipo, norma_legal, vigente_desde, geom) VALUES
    ('Primeras 5 millas - ejemplo', 'RESTRINGIDA', 'Ejemplo de zona restringida', '2026-01-01',
     ST_Multi(ST_GeomFromText('POLYGON((-80.00 -6.90, -79.90 -6.90, -79.90 -6.70, -80.00 -6.70, -80.00 -6.90))', 4326)));

INSERT INTO localizacion (nombre, latitud, longitud) VALUES
    ('Desembarcadero Pesquero Artesanal San José', -6.768, -79.972);

INSERT INTO permiso (id_emb, gestionado_por, tipo_permiso, numero_resolucion, fecha_inicio, fecha_fin) VALUES
    (1, 3, 'Permiso de pesca artesanal', 'RD-0001-2026-PRODUCE', '2026-01-01', '2026-12-31');
INSERT INTO permiso_especie VALUES (1, 2), (1, 3), (1, 5);

COMMIT;
