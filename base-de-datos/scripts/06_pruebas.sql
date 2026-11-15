-- =====================================================================
-- SIRDEPA · 06_pruebas.sql · Pruebas de procedimientos, vistas y triggers
-- Ejecutar sobre la base con datos de prueba (05_datos_prueba.sql).
-- =====================================================================
SET search_path = sirdepa, public;
\set ON_ERROR_STOP 0
\set VERBOSITY terse
\set ON_ERROR_ROLLBACK on
BEGIN;   -- todas las pruebas se deshacen al final
SELECT set_config('sirdepa.id_usuario', (SELECT id_usuario::text FROM usuario WHERE dni = '40000017'), false);

\echo '--- P1. Registro idempotente: el mismo UUID enviado dos veces'
SELECT * FROM fn_registrar_desembarque('{
  "id":"9b2e6a51-8c3d-4f7e-b1a2-0c4d5e6f7a81","idEmbarcacion":12345,"idLugar":17,"idZona":42,"idArte":1,
  "fechaZarpe":"2026-11-10T02:00:00-05","fechaHoraArribo":"2026-11-10T09:30:00-05","tripulantes":4,
  "validacionPreliminar":"CONFORME","registradoEn":"2026-11-10T09:41:00-05",
  "detalles":[{"idEspecie":5,"pesoKg":320.5,"precioPlayaKg":6.5},{"idEspecie":12,"pesoKg":80}]}'::jsonb,
  (SELECT id_usuario FROM usuario WHERE dni = '40000017'));
SELECT * FROM fn_registrar_desembarque('{
  "id":"9b2e6a51-8c3d-4f7e-b1a2-0c4d5e6f7a81","idEmbarcacion":12345,"idLugar":17,"idZona":42,"idArte":1,
  "fechaZarpe":"2026-11-10T02:00:00-05","fechaHoraArribo":"2026-11-10T09:30:00-05","tripulantes":4,
  "registradoEn":"2026-11-10T09:41:00-05","detalles":[{"idEspecie":5,"pesoKg":320.5}]}'::jsonb,
  (SELECT id_usuario FROM usuario WHERE dni = '40000017'));
SELECT count(*) AS detalles_guardados FROM detalle_desembarque
 WHERE id_desembarque = '9b2e6a51-8c3d-4f7e-b1a2-0c4d5e6f7a81';

\echo '--- P2. Validación: un resultado Observado clasifica el desembarque y crea alerta MEDIA'
CALL sp_guardar_validacion('9b2e6a51-8c3d-4f7e-b1a2-0c4d5e6f7a81', '[
  {"regla":"PERMISO_VIGENTE","nivel":"CONFORME","mensaje":"Permiso vigente hasta 31/12/2027"},
  {"regla":"ESPECIE_ARTE","nivel":"CONFORME","mensaje":"Especie y arte autorizados"},
  {"regla":"VEDA","nivel":"CONFORME","mensaje":"Sin veda vigente"},
  {"regla":"TALLA_MINIMA","nivel":"OBSERVADO","mensaje":"14 % bajo talla; tolerancia 10 %","norma":"R.M. 209-2001-PE"},
  {"regla":"ZONA_ARTE","nivel":"CONFORME","mensaje":"Combinación permitida"}]');
SELECT estado_validacion FROM desembarque WHERE id_desembarque = '9b2e6a51-8c3d-4f7e-b1a2-0c4d5e6f7a81';
SELECT tipo, prioridad, estado FROM alerta WHERE id_desembarque = '9b2e6a51-8c3d-4f7e-b1a2-0c4d5e6f7a81';

\echo '--- P3. Constancia y lotes con control de saldo'
SELECT fn_emitir_constancia('9b2e6a51-8c3d-4f7e-b1a2-0c4d5e6f7a81', 'https://sirdepa.pe') AS constancia;
SELECT id_detalle AS det FROM detalle_desembarque
 WHERE id_desembarque = '9b2e6a51-8c3d-4f7e-b1a2-0c4d5e6f7a81' AND id_especie = 5 \gset
CALL sp_asignar_lote(:det, 25, 300, 'ABC-123', '45678912');   -- 300 de 320,5 kg: se acepta
CALL sp_asignar_lote(:det, 26, 50, 'ABC-124', '45678913');    -- 50 kg más: se rechaza

\echo '--- P4. Verificación pública: hash correcto y hash alterado'
SELECT fn_verificar(l.codigo_lote, l.hash_qr)->>'validez' AS hash_correcto,
       fn_verificar(l.codigo_lote, repeat('0', 64))->>'validez' AS hash_alterado,
       fn_verificar(l.codigo_lote, l.hash_qr) ? 'dni' AS expone_dni
  FROM lote_destino l JOIN detalle_desembarque dd USING (id_detalle)
 WHERE dd.id_desembarque = '9b2e6a51-8c3d-4f7e-b1a2-0c4d5e6f7a81';

\echo '--- P5. Anulación: la constancia y el lote pasan a NO VÁLIDA'
UPDATE desembarque SET estado_registro = 'ANULADO', motivo_anulacion = 'Error de digitación de especie'
 WHERE id_desembarque = '9b2e6a51-8c3d-4f7e-b1a2-0c4d5e6f7a81';
SELECT c.estado AS constancia, l.estado AS lote, fn_verificar(l.codigo_lote, l.hash_qr)->>'validez' AS verificacion
  FROM constancia c JOIN detalle_desembarque dd USING (id_desembarque) JOIN lote_destino l USING (id_detalle)
 WHERE c.id_desembarque = '9b2e6a51-8c3d-4f7e-b1a2-0c4d5e6f7a81';

\echo '--- P6. Auditoría: eventos registrados e intento de borrado'
SELECT tabla, operacion, count(*) FROM auditoria
 WHERE id_usuario = (SELECT id_usuario FROM usuario WHERE dni = '40000017') GROUP BY 1, 2 ORDER BY 1, 2;
DELETE FROM auditoria WHERE id_auditoria = 1;

\echo '--- P7. Restricciones de dominio'
INSERT INTO embarcacion (matricula, nombre, eslora_m, bodega_m3, categoria, id_armador)
VALUES ('PT-99999-BM', 'Prueba', 12, 40, 'ARTESANAL', 1);
INSERT INTO talla_minima (id_especie, talla_min_cm, tolerancia_pct, norma, vigente_desde)
VALUES (5, 22, 10, 'R.M. prueba', DATE '2026-01-01');

\echo '--- P8. Seguridad: rol de la API con RLS y rol de verificación'
\i 04_seguridad.sql
SET ROLE sirdepa_app;
SET sirdepa.rol = 'REGISTRADOR'; SET sirdepa.id_lugar = '17';
SELECT count(DISTINCT id_lugar) AS lugares_visibles, count(*) AS desembarques_visibles FROM desembarque;
RESET ROLE;
SET ROLE sirdepa_verificacion;
SELECT count(*) FROM desembarque;
SELECT fn_verificar('SIR-000010', 'x')->>'validez' AS verificacion_publica;
RESET ROLE;
ROLLBACK;
