-- =====================================================================
-- SIRDEPA · 05_datos_prueba.sql
-- Datos SINTÉTICOS para medir índices (no son datos reales).
-- Escala: 60 DPA, 25 000 embarcaciones (RNF13) y ~600 000 desembarques
-- (ene-2025 a oct-2026) insertados en orden de llegada, intercalando DPA.
-- =====================================================================
SET search_path = sirdepa, public;
SELECT setseed(0.2026);
SET session_replication_role = replica;      -- carga masiva sin triggers

INSERT INTO rol (codigo, nombre) VALUES
 ('ADMIN_SISTEMA','Administrador del sistema'), ('ADMIN_DPA','Administrador del DPA'),
 ('REGISTRADOR','Registrador del DPA'), ('ARMADOR','Patrón / armador'),
 ('COMPRADOR','Comerciante / comprador'), ('FISCALIZADOR','Fiscalizador'), ('ANALISTA','Analista');

INSERT INTO lugar_desembarque (codigo, nombre, tipo, region)
SELECT 'DPA' || lpad(g::text, 3, '0'), 'DPA ' || g, CASE WHEN g % 5 = 0 THEN 'CALETA' ELSE 'DPA' END::tipo_lugar,
       (ARRAY['Piura','Lima','Arequipa','Ica','Tumbes','Áncash','La Libertad','Moquegua','Tacna','Lambayeque'])[1 + g % 10]
FROM generate_series(1, 60) g;

-- Usuarios del DPA (2 registradores y 1 administrador por lugar) + fiscalizadores y analistas
INSERT INTO usuario (dni, celular, pin_hash, id_rol, id_lugar)
SELECT lpad((40000000 + g)::text, 8, '0'), '9' || lpad((10000000 + g)::text, 8, '0'), 'argon2id$demo',
       CASE WHEN g <= 120 THEN 3 WHEN g <= 180 THEN 2 WHEN g <= 210 THEN 6 ELSE 7 END,
       CASE WHEN g <= 120 THEN 1 + (g - 1) % 60 WHEN g <= 180 THEN g - 120 END
FROM generate_series(1, 220) g;

INSERT INTO armador (tipo_doc, num_doc, nombre, celular)
SELECT 'DNI', lpad((10000000 + g)::text, 8, '0'), 'Armador ' || g, '9' || lpad((20000000 + g)::text, 8, '0')
FROM generate_series(1, 18000) g;

INSERT INTO comprador (tipo_doc, num_doc, nombre, tipo, celular)
SELECT 'RUC', '20' || lpad(g::text, 9, '0'), 'Comprador ' || g,
       (ARRAY['COMERCIANTE','PLANTA_PROCESADORA','OTRO'])[1 + g % 3]::tipo_comprador,
       '9' || lpad((30000000 + g)::text, 8, '0')
FROM generate_series(1, 3000) g;

INSERT INTO embarcacion (matricula, nombre, eslora_m, bodega_m3, categoria, id_armador)
SELECT 'PT-' || lpad(g::text, 5, '0') || '-BM', 'Embarcación ' || g,
       round((6 + random() * 9)::numeric, 2), round((2 + random() * 30.5)::numeric, 2),
       CASE WHEN random() < 0.85 THEN 'ARTESANAL' ELSE 'MENOR_ESCALA' END::categoria_embarcacion,
       1 + (g - 1) % 18000
FROM generate_series(1, 25000) g;

INSERT INTO especie (codigo_fao, nombre_comun, nombre_cientifico)
SELECT chr(65 + g / 26 % 26) || chr(65 + g % 26) || chr(65 + (g * 7) % 26), 'Especie ' || g, 'Genus species' || g
FROM generate_series(1, 40) g;

INSERT INTO arte_pesca (nombre, tipo, mecanizado)
SELECT a, t, m FROM (VALUES ('Cortina','Enmalle',false), ('Pinta','Anzuelo',false), ('Espinel','Anzuelo',false),
     ('Cerco artesanal','Cerco',false), ('Cerco mecanizado','Cerco',true), ('Buceo','Recolección',false),
     ('Arrastre de playa','Arrastre',false), ('Trampa','Trampa',false)) v(a, t, m);

INSERT INTO zona_pesca (codigo_cuadricula, dentro_5_millas, dentro_3_millas, geom)
SELECT 'C' || lpad(g::text, 4, '0'), g % 3 <> 0, g % 3 = 1,
       ST_MakeEnvelope(-81.5 + (g % 20) * 0.1, -18.0 + (g / 20) * 0.2,
                       -81.4 + (g % 20) * 0.1, -17.8 + (g / 20) * 0.2, 4326)
FROM generate_series(1, 300) g;

INSERT INTO talla_minima (id_especie, talla_min_cm, tolerancia_pct, norma, vigente_desde)
SELECT g, 15 + g % 30, 10, 'R.M. 209-2001-PE', DATE '2001-06-27' FROM generate_series(1, 40) g;

INSERT INTO limite_captura (id_especie, periodo_inicio, periodo_fin, limite_kg, norma)
SELECT g, DATE '2026-01-01', DATE '2026-12-31', 2000000 + g * 50000, 'R.M. límite ' || g
FROM generate_series(1, 40) g;

INSERT INTO veda (id_especie, id_zona, fecha_inicio, fecha_fin, norma)
SELECT 1 + g % 40, NULL, DATE '2026-01-01' + g * 15, DATE '2026-01-01' + g * 15 + 30, 'R.M. veda ' || g
FROM generate_series(1, 20) g;

INSERT INTO permiso_pesca (id_embarcacion, num_resolucion, entidad_emisora, fecha_emision, fecha_vencimiento)
SELECT g, 'R.D. ' || g || '-2024', 'DIREPRO', DATE '2024-01-01', DATE '2027-12-31'
FROM generate_series(1, 25000) g;
INSERT INTO permiso_especie SELECT p, 1 + (p + k) % 40 FROM generate_series(1, 25000) p, generate_series(0, 4) k;
INSERT INTO permiso_arte    SELECT p, 1 + (p + k) % 8  FROM generate_series(1, 25000) p, generate_series(0, 1) k;

-- Desembarques en orden cronológico, intercalando los 60 lugares
CREATE TEMP TABLE t_des AS
SELECT gen_random_uuid() AS id, g,
       TIMESTAMPTZ '2025-01-01 05:00-05' + (g * interval '96 seconds') AS arribo,
       1 + floor(random() * 60)::int AS lugar,
       1 + floor(random() * 25000)::int AS emb,
       random() AS r
FROM generate_series(1, 600000) g;

INSERT INTO desembarque (id_desembarque, id_embarcacion, id_lugar, id_registrador, id_zona, id_arte,
       fecha_zarpe, fecha_hora_arribo, tripulantes, estado_validacion, validacion_preliminar,
       registrado_en, sincronizado_en)
SELECT t.id, t.emb, t.lugar, u.id_usuario, 1 + t.g % 300, (1 + t.g % 8)::smallint,
       t.arribo - interval '14 hours', t.arribo, (2 + t.g % 5)::smallint,
       CASE WHEN t.r < 0.04 THEN 'NO_CONFORME' WHEN t.r < 0.12 THEN 'OBSERVADO' ELSE 'CONFORME' END::estado_validacion,
       CASE WHEN t.r < 0.04 THEN 'NO_CONFORME' WHEN t.r < 0.12 THEN 'OBSERVADO' ELSE 'CONFORME' END::estado_validacion,
       t.arribo + interval '20 minutes', t.arribo + interval '25 minutes'
FROM t_des t
JOIN usuario u ON u.dni = lpad((40000000 + t.lugar + 60 * (t.g % 2))::text, 8, '0')
ORDER BY t.g;

-- 1 a 4 especies por desembarque (promedio 2,5)
INSERT INTO detalle_desembarque (id_desembarque, id_especie, peso_kg, presentacion, precio_playa_kg)
SELECT t.id, 1 + (t.g * 7 + k * 11) % 40, round((20 + random() * 480)::numeric, 2), 'ENTERO',
       round((3 + random() * 12)::numeric, 2)
FROM t_des t, generate_series(0, 3) k
WHERE k < 1 + (t.g % 4)
ORDER BY t.g, k;

-- Constancia para Conforme u Observado
INSERT INTO constancia (id_desembarque, codigo, hash_sha256, url_qr, fecha_emision)
SELECT d.id_desembarque, 'SIR-' || lpad(t.g::text, 6, '0'),
       encode(digest(d.id_desembarque::text, 'sha256'), 'hex'),
       'https://sirdepa.pe/v/SIR-' || lpad(t.g::text, 6, '0'), d.sincronizado_en
FROM desembarque d JOIN t_des t ON t.id = d.id_desembarque
WHERE d.estado_validacion <> 'NO_CONFORME'
ORDER BY t.g;
SELECT setval('seq_constancia', 600000);

-- Lotes: uno por detalle con constancia (todo el peso a un comprador)
INSERT INTO lote_destino (id_detalle, id_comprador, codigo_lote, hash_qr, peso_kg, placa_vehiculo,
       dni_conductor, estado, recibido_en)
SELECT dd.id_detalle, 1 + (dd.id_detalle % 3000)::int,
       c.codigo || '-L' || lpad(row_number() OVER (PARTITION BY dd.id_desembarque ORDER BY dd.id_detalle)::text, 2, '0'),
       encode(digest(dd.id_detalle::text || 'lote', 'sha256'), 'hex'), dd.peso_kg,
       'ABC-' || lpad((dd.id_detalle % 999)::text, 3, '0'), lpad((70000000 + dd.id_detalle % 9999999)::text, 8, '0'),
       CASE WHEN dd.id_detalle % 5 = 0 THEN 'ASIGNADO' ELSE 'RECIBIDO' END::estado_lote,
       CASE WHEN dd.id_detalle % 5 = 0 THEN NULL ELSE c.fecha_emision + interval '2 hours' END
FROM detalle_desembarque dd JOIN constancia c ON c.id_desembarque = dd.id_desembarque
ORDER BY dd.id_detalle;

-- Cinco resultados de regla por desembarque
INSERT INTO resultado_validacion (id_desembarque, regla, nivel, mensaje, norma, evaluado_en)
SELECT d.id_desembarque, r.regla,
       CASE WHEN d.estado_validacion = 'NO_CONFORME' AND r.regla = 'PERMISO_VIGENTE' THEN 'NO_CONFORME'
            WHEN d.estado_validacion = 'OBSERVADO' AND r.regla = 'TALLA_MINIMA' THEN 'OBSERVADO'
            ELSE 'CONFORME' END::estado_validacion,
       'Regla ' || r.regla, 'Norma', d.sincronizado_en
FROM desembarque d
CROSS JOIN (VALUES ('PERMISO_VIGENTE'), ('ESPECIE_ARTE'), ('VEDA'), ('TALLA_MINIMA'), ('ZONA_ARTE')) r(regla);

-- Alertas: todas las No conforme y Observado; las de las 2 últimas semanas siguen abiertas
INSERT INTO alerta (id_desembarque, tipo, prioridad, estado, creada_en, atendida_en)
SELECT d.id_desembarque, d.estado_validacion::text::tipo_alerta,
       CASE d.estado_validacion WHEN 'NO_CONFORME' THEN 'ALTA' ELSE 'MEDIA' END::prioridad_alerta,
       CASE WHEN d.fecha_hora_arribo > TIMESTAMPTZ '2026-10-20' THEN 'PENDIENTE' ELSE 'ATENDIDA' END::estado_alerta,
       d.sincronizado_en,
       CASE WHEN d.fecha_hora_arribo > TIMESTAMPTZ '2026-10-20' THEN NULL ELSE d.sincronizado_en + interval '6 hours' END
FROM desembarque d WHERE d.estado_validacion IN ('NO_CONFORME', 'OBSERVADO')
ORDER BY d.sincronizado_en;

-- Bitácora: ~3 millones de eventos en orden cronológico
INSERT INTO auditoria (id_usuario, tabla, operacion, id_registro, datos_antes_despues, fecha)
SELECT NULL, (ARRAY['desembarque','lote_destino','constancia','permiso_pesca'])[1 + g % 4], 'I',
       g::text, jsonb_build_object('antes', NULL, 'despues', jsonb_build_object('n', g)),
       TIMESTAMPTZ '2025-01-01 05:00-05' + (g * interval '19 seconds')
FROM generate_series(1, 3000000) g;

SET session_replication_role = origin;
DROP TABLE t_des;
VACUUM ANALYZE;
