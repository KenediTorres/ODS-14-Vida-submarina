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
