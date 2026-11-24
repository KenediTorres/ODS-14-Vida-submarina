# Matriz de trazabilidad - SIRDEPA

Relaciona cada requerimiento funcional con la necesidad que lo origina, el caso de uso que lo realiza, la historia de usuario que lo implementa, su épica y el Sprint en que se planificó. Es la Tabla 13 del informe (capítulo 2) y se mantiene igual en el informe, en Jira y en este repositorio.

## Necesidad – requerimiento – caso de uso – historia de usuario – Sprint

| RF | Necesidad | Caso de uso | Historia de usuario | Épica | Sprint |
|---|---|---|---|---|---|
| RF01 | N03, N11 | CU01, CU19 | HU01, HU02 | E1 | 1 |
| RF02 | N02, N06 | CU02 | HU03 | E1 | 1 |
| RF03 | N06, N07 | CU02 | HU04 | E1 | 1 |
| RF04 | N11 | CU03 | HU05 | E1 | 1 |
| RF05 | N01 | CU04 | HU20 | E2 | 1 |
| RF06 | N01, N04 | CU05 | HU06 | E2 | 1 |
| RF07 | N01, N09 | CU05 | HU07 | E2 | 1 |
| RF08 | N01 | CU05 | HU22 | E2 | 3* |
| RF09 | N09 | CU05 (ext. muestreo) | HU10 | E3 | 2 |
| RF10 | N07 | CU06 | HU09 | E3 | 2 |
| RF11 | N07 | CU05 (ext. fotos) | HU23 | E2 | 1 |
| RF12 | N01 | CU15 | HU08 | E2 | 2 |
| RF13 | N03, N08 | CU07 | HU11 | E4 | 2 |
| RF14 | N02, N08 | CU08 | HU12 | E4 | 2 |
| RF15 | N08 | CU09 | HU14 | E4 | 3 |
| RF16 | N07, N08 | CU10 | HU13 | E4 | 2 |
| RF17 | N07 | CU11 | HU15 | E5 | 3 |
| RF18 | N06 | CU13 | HU16 | E6 | 3 |
| RF19 | N09 | CU14 | HU17 | E6 | 3 |
| RF20 | N10 | CU17 | HU18 | E6 | 3 |
| RF21 | N05 | CU12 | HU19 | E6 | 3 |
| RF22 | N07 | CU11 y aviso automático diario | HU15, HU04 | E5, E1 | 3, 1 |
| RF23 | N07 | CU16 | HU21 | E5 | 2 |
| RF24 | N06 | CU18 | HU24 | E6 | 3 |
| RF25 | N09 | CU03, CU14 | HU25 | E6 | 3 |

(\*) HU22 es «C» en MoSCoW: entra al Sprint 3 solo si la velocidad del equipo lo permite.

**Resultado de la verificación.** Los 25 RF tienen al menos una necesidad, un caso de uso y una historia de usuario; los 19 casos de uso realizan al menos un RF, y las 25 historias están planificadas en un Sprint. Ninguna historia del backlog queda sin RF: las historias que figuraban en Jira sin requerimiento (posición GPS y mapa de embarcaciones en faena) se retiraron del proyecto, y el panel de cuotas se formalizó como RF25.

## Pantallas del prototipo – requerimientos

Cada pantalla del prototipo de Figma (capítulo 9, Tabla 53 del informe) y los requerimientos que demuestra.

| Pantalla | Usuario | Requerimientos | Evidencia en la pantalla |
|---|---|---|---|
| A01 · Ingreso | Registrador | RF01, RNF08 | DNI y PIN con código SMS; aviso de ingreso con PIN sin señal. |
| A02 · Inicio | Registrador | RF05, RF12, RF22 | Avisos de arribo del día; barra de pendientes sin conexión; chip «Sin permiso». |
| A03 · Paso 1 | Registrador | RF02, RF03, RF06 | Búsqueda por matrícula; permiso vigente y especies autorizadas; aviso vinculado. |
| A04 · Paso 2 | Registrador | RF06, RNF09, RD08 | Zarpe y arribo; cuadrícula C-0412 sin coordenadas; «Dentro de 5 millas»; arte de pesca. |
| A05 · Paso 3 | Registrador | RF07, RF08, RF09 | Kilos por especie, botón de balanza Bluetooth, chip de 30 tallas y total automático. |
| A06 · Paso 4 | Registrador | RF06, RF10, RF11 | Resumen para revisar, hasta tres fotos y validación preliminar. |
| A07 · Resultado | Registrador | RF10, RF13, RF22 | Resultado por regla con norma; constancia SIR-000123 con QR; SMS al armador. |
| A08 · Guardado sin conexión | Registrador | RF12, RNF07 | Código interno UUID; constancia pendiente hasta sincronizar. |
| A09 · Asignar lotes | Registrador | RF14 | Saldo por especie; lote con comprador, placa y conductor; error al superar el saldo. |
| A10 · Sincronización | Registrador | RF04, RF12, RNF07 | Progreso de envío, registro que requiere corrección y catálogo actualizado. |
| W01 · Tablero del DPA | Administrador del DPA | RF18, RF22, RF24, RF03 | Indicadores, kilos por especie, resultados, cierre del día y permisos por vencer. |
| W02 · Bandeja de alertas | Fiscalizador | RF16, RF17, RF22 | Alertas por prioridad, verificación rápida de QR y registro de actuación. |
| W03 · Reportes y cuotas | Analista | RF19, RF20, RF25 | Avance frente al límite con alerta al 80 %; reporte IMARPE y archivo SITRAPESCA. |
| W04 · Ingreso web | Armador, comprador | RF01, RNF08 | DNI y código SMS de 6 dígitos, sin correo. |
| W05 · Aviso de arribo | Armador | RF05 | Lugar, hora estimada y captura aproximada. |
| W06 · Historial | Armador | RF21, RF13 | Desembarques con su resultado y descarga de constancias. |
| W07 · Verificación válida | Cualquier persona | RF16, RNF09, RNF10 | VÁLIDA, datos del lote sin datos personales y huella (hash). |
| W08 · Confirmar recepción | Comprador | RF15 | Lote asignado a su RUC y confirmación explícita. |
| W09 · Verificación no válida | Cualquier persona | RF16, RF23 | NO VÁLIDA por anulación, con motivo y fecha. |

Los requerimientos completos (RF, RNF y RD) están en [Documentacion/requerimientos.md](../Documentacion/requerimientos.md), y el backlog en [backlog.md](backlog.md).
