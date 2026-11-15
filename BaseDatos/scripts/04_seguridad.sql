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
