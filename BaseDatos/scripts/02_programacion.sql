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
