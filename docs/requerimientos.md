# Requerimientos - SIRDEPA

**Sistema de Registro de Desembarque Pesquero Artesanal**
ODS 14: Vida submarina · Análisis y Diseño de Software · 2026

Este documento reúne los requerimientos del Capítulo 2 del informe. Cada requerimiento conserva su identificador, que se usa en los modelos, en la base de datos y en el backlog.

---

## 1. Problema

En los desembarcaderos y caletas del litoral peruano, el registro del desembarque de la pesca artesanal (qué especie se descargó, cuántos kilos, de qué embarcación, en qué zona, con qué arte y a quién se vendió) es **manual, fragmentado y tardío**. Por eso la información no es confiable, llega tarde a quienes toman decisiones y no permite trazar el origen del producto.

Deficiencias del proceso actual (AS-IS):

1. **Captura extemporánea y duplicada:** comerciantes, observadores y fiscalizadores anotan por separado la misma descarga, en papel.
2. **Cobertura de monitoreo limitada:** observadores presenciales solo en 63 puntos del litoral.
3. **Falta de validación inmediata:** no hay controles automáticos de permisos, vedas o tallas al desembarcar.
4. **Sin trazabilidad comercial:** los documentos físicos no se vinculan de forma verificable con el lote vendido.
5. **Barrera tecnológica:** los sistemas actuales exigen correo y PC, ajenos al perfil artesanal.

**Beneficiario principal:** FONDEPES y la administración de los DPA. Piloto propuesto en un DPA de Piura.

**Alcance:** embarcaciones artesanales y de menor escala (hasta 32,6 m³ de bodega), validación normativa, constancia con QR hasta el primer comprador y exportación a IMARPE y PRODUCE.
**Fuera del alcance:** monitoreo satelital (SISESAT), facturación electrónica y reemplazo del SITRAPESCA.

## 2. Interesados

| Interesado | Tipo | Interés principal | Influencia |
|---|---|---|---|
| Registrador del DPA | Usuario directo | Registrar rápido, sin errores ni papeles | Alta |
| Administrador del DPA / FONDEPES | Usuario directo y patrocinador | Estadística del muelle y control de la infraestructura | Alta |
| Patrón / armador | Usuario directo | Constancia rápida y confidencialidad del caladero | Alta |
| Comerciante / planta | Usuario directo | Comprar con prueba de origen legal | Media |
| Fiscalizador (PRODUCE / DIREPRO) | Usuario directo | Verificar el origen y priorizar inspecciones | Alta |
| Analista (IMARPE / PRODUCE) | Usuario indirecto | Datos oportunos, completos y comparables | Media |
| Equipo de desarrollo | Proveedor | Requerimientos claros y priorizados | Media |

## 3. Necesidades de los usuarios

| ID | Usuario | Necesidad |
|---|---|---|
| N01 | Registrador | Registrar un desembarque en pocos minutos, incluso sin señal |
| N02 | Registrador | No volver a digitar embarcaciones, compradores ni vehículos frecuentes |
| N03 | Patrón / armador | Obtener prueba del origen legal de su pesca sin trámites ni correo electrónico |
| N04 | Patrón / armador | Proteger la ubicación de sus caladeros |
| N05 | Patrón / armador | Contar con un historial de su esfuerzo pesquero |
| N06 | Administrador del DPA | Saber cada día cuánto, qué y quién desembarca |
| N07 | Fiscalizador | Verificar el origen en segundos y priorizar inspecciones |
| N08 | Comerciante / planta | Demostrar que compró pesca de origen legal |
| N09 | Analista IMARPE | Recibir datos de captura y esfuerzo estructurados y oportunos |
| N10 | PRODUCE | Integrar la información con el SITRAPESCA sin doble digitación |
| N11 | Todos | Usar una interfaz con el lenguaje propio del sector |

## 4. Requerimientos funcionales (RF)

Prioridad MoSCoW: **M** indispensable, **S** deseable, **C** opcional.

| ID | Requerimiento | Descripción | Prior. | Nec. |
|---|---|---|---|---|
| RF01 | Autenticación y roles | Ingreso con DNI, PIN y código de un solo uso por SMS; siete roles con permisos diferenciados; bloqueo tras intentos fallidos | M | N03, N11 |
| RF02 | Gestión de embarcaciones | Registrar matrícula, nombre, tipo, eslora, capacidad de bodega, armador y categoría (artesanal o menor escala) | M | N06 |
| RF03 | Gestión de permisos | Registrar permisos de pesca con resolución, entidad emisora, vigencia, especies y artes autorizados | M | N06, N07 |
| RF04 | Catálogo normativo | Mantener especies (código FAO, talla mínima, tolerancia), artes, cuadrículas de pesca y vedas, con la norma que las sustenta | M | N11 |
| RF05 | Aviso de arribo | Permitir al patrón informar hora estimada de llegada y captura aproximada | S | N01 |
| RF06 | Registro de desembarque | Registrar embarcación, lugar, fechas de zarpe y arribo, zona de pesca, arte y número de tripulantes | M | N01 |
| RF07 | Detalle por especie | Registrar por especie el peso en kg (o unidades), la presentación y el precio en playa | M | N01, N09 |
| RF08 | Lectura de balanza | Capturar el peso desde una balanza digital por Bluetooth o USB | C | N01 |
| RF09 | Muestreo de tallas | Registrar tallas de una muestra y calcular el % de ejemplares bajo la talla mínima | S | N09 |
| RF10 | Validación normativa | Evaluar permiso vigente, especie y arte autorizados, veda, talla mínima, zona–arte y capacidad de bodega; clasificar como Conforme, Observado o No conforme sin bloquear el registro | M | N07 |
| RF11 | Evidencia fotográfica | Adjuntar hasta tres fotografías comprimidas por desembarque | S | N07 |
| RF12 | Trabajo sin conexión | Guardar el registro en el celular con identificador único (UUID) y sincronizarlo sin duplicados al recuperar la señal | M | N01 |
| RF13 | Constancia digital con QR | Emitir constancia PDF con código único, QR y hash SHA-256, y enviar el enlace por SMS al armador | M | N03, N08 |
| RF14 | Destino y lotes | Asignar kilos por especie a uno o más compradores, con vehículo, conductor y destino; mostrar el saldo pendiente | M | N02, N08 |
| RF15 | Recepción del lote | Permitir que el comprador confirme la recepción escaneando el QR | S | N08 |
| RF16 | Verificación pública | Mostrar, al escanear el QR, si la constancia es válida y un resumen sin datos personales sensibles | M | N07, N08 |
| RF17 | Observaciones de fiscalización | Registrar observaciones o actas vinculadas al desembarque | S | N07 |
| RF18 | Tablero de indicadores | Mostrar kilos por día, especie, embarcación y arte, porcentaje de conformidad y alertas | M | N06 |
| RF19 | Reportes y exportación | Generar reportes en Excel, CSV y PDF, incluido el reporte mensual de captura y esfuerzo para el IMARPE | M | N09 |
| RF20 | Interoperabilidad SITRAPESCA | Exportar los datos en la estructura del módulo de descarga del SITRAPESCA y ofrecer una API documentada | S | N10 |
| RF21 | Historial del armador | Consultar desembarques propios y descargar constancias | S | N05 |
| RF22 | Notificaciones | Alertar al fiscalizador ante un desembarque No conforme y avisar al armador 30 días antes del vencimiento de su permiso | S | N07 |
| RF23 | Anulación y auditoría | Anular un desembarque solo con motivo y rol autorizado; registrar toda creación, edición o anulación | M | N07 |
| RF24 | Cierre diario | Consolidar el día y cuadrar kilos registrados frente a kilos despachados | C | N06 |

## 5. Requerimientos no funcionales (RNF)

Estructurados según el modelo de calidad ISO/IEC 25010:2023.

| ID | Característica | Requerimiento | Criterio de aceptación |
|---|---|---|---|
| RNF01 | Capacidad de interacción | Registro rápido por un registrador capacitado | Desembarque con hasta tres especies en ≤ 3 minutos y ≤ 5 pantallas |
| RNF02 | Capacidad de interacción | Interfaz legible a pleno sol y operable con manos húmedas | Botones de al menos 48 × 48 dp; contraste ≥ 4,5:1 (WCAG 2.1 AA) |
| RNF03 | Capacidad de interacción | Lenguaje del sector, sin siglas técnicas | Etiquetas validadas con usuarios; capacitación del registrador en ≤ 2 horas |
| RNF04 | Eficiencia de desempeño | Tiempo de respuesta de los servicios | Percentil 95 ≤ 2 s con 200 usuarios concurrentes; tablero ≤ 5 s |
| RNF05 | Eficiencia de desempeño | Aplicación liviana para celulares de gama baja | ≤ 40 MB instalada; Android 8.0+ con 2 GB de RAM; ≤ 200 KB por desembarque sin fotos; fotos ≤ 300 KB |
| RNF06 | Fiabilidad | Disponibilidad del servicio central | ≥ 99,5 % mensual; registro en el celular disponible aun sin conexión |
| RNF07 | Fiabilidad | Ningún registro se pierde ni se duplica | Persistencia local antes de confirmar; sincronización idempotente por UUID; 0 duplicados en pruebas de corte de red |
| RNF08 | Seguridad | Acceso seguro sin correo electrónico | DNI + PIN + código por SMS; PIN con Argon2 o bcrypt; bloqueo tras 5 intentos |
| RNF09 | Seguridad | Protección de datos personales y de caladeros | Ley 29733 y su reglamento; TLS 1.2+; zona visible solo para roles autorizados; datos anonimizados en exportaciones abiertas |
| RNF10 | Seguridad | Integridad y no repudio | Constancia con hash SHA-256 verificado en el servidor; bitácora inmutable de cambios |
| RNF11 | Compatibilidad | Intercambio de datos estándar | API REST con OpenAPI 3; CSV/JSON; fechas ISO 8601; especies con código 3-alfa ASFIS de la FAO |
| RNF12 | Mantenibilidad | Reglas y código fáciles de modificar | Tallas y vedas parametrizables sin programar; cobertura de pruebas ≥ 70 % en el motor de reglas |
| RNF13 | Flexibilidad | Escalar del piloto a todo el litoral | ≥ 60 lugares de desembarque y ≥ 25 000 embarcaciones sin rediseño |
| RNF14 | Flexibilidad | Portabilidad de la aplicación web | Chrome, Edge y Firefox (dos últimas versiones) y diseño adaptable a celular |

## 6. Requerimientos de dominio (RD)

| ID | Requerimiento | Fuente |
|---|---|---|
| RD01 | Solo son artesanales las embarcaciones de hasta 32,6 m³ de bodega y 15 m de eslora con predominio del trabajo manual; las de igual tamaño con sistemas mecanizados son de menor escala | D.S. N.° 002-2025-PRODUCE |
| RD02 | Los titulares de embarcaciones deben informar sus capturas por especie y zona de pesca | Art. 66 del D.L. N.° 25977, Ley General de Pesca |
| RD03 | Cada especie tiene talla mínima de captura y tolerancia de juveniles, que se actualizan cuando una resolución las modifica | R.M. N.° 209-2001-PE y modificatorias |
| RD04 | Las vedas, temporadas y zonas de pesca las fija la autoridad sobre la base de evidencia científica; se registran con su norma y vigencia | Ley General de Pesca, art. 9 |
| RD05 | La descarga debe registrar punto de desembarque, embarcación, código de faena, fecha y hora, tipo de transporte, DNI del conductor, placa y destino, como en el módulo de descarga del SITRAPESCA | D.S. N.° 024-2021-PRODUCE |
| RD06 | Las embarcaciones de hasta 32,6 m³ deben comunicar la información de sus faenas y calas | R.M. N.° 207-2025-PRODUCE |
| RD07 | Toda descarga debe contar con documentación física o electrónica que acredite su origen legal y trazabilidad | D.S. N.° 006-2025-PRODUCE |
| RD08 | La franja de 0 a 5 millas está reservada a la pesca artesanal y de menor escala, y en las 3 primeras millas no se permite el cerco mecanizado; una combinación zona–arte incompatible se marca como observada | D.S. N.° 002-2025-PRODUCE |
| RD09 | El registro de pescadores no embarcados es voluntario, pues la obligación de informar recae en embarcaciones y plantas | Oceana Perú (2025) |
| RD10 | Los datos personales se tratan con consentimiento, finalidad determinada y medidas de seguridad | Ley N.° 29733 y D.S. N.° 016-2024-JUS |

## 7. Casos de uso generales

| ID | Caso de uso | Actor principal | RF |
|---|---|---|---|
| CU01 | Iniciar sesión (DNI + PIN + OTP) | Todos | RF01 |
| CU02 | Gestionar embarcaciones y permisos | Administrador del DPA | RF02, RF03 |
| CU03 | Gestionar catálogos normativos | Administrador del DPA | RF04 |
| CU04 | Registrar aviso de arribo | Patrón / armador | RF05 |
| CU05 | Registrar desembarque (extensiones: muestreo de tallas, evidencia fotográfica) | Registrador del DPA | RF06–RF09, RF11 |
| CU06 | Validar cumplimiento normativo (incluido en CU05) | Sistema | RF10, RF22 |
| CU07 | Emitir constancia digital con QR (incluido en CU05) | Sistema | RF13 |
| CU08 | Registrar destino y lotes | Registrador del DPA | RF14 |
| CU09 | Confirmar recepción de lote (incluye CU10) | Comerciante | RF15 |
| CU10 | Verificar constancia por QR | Comerciante, fiscalizador | RF16 |
| CU11 | Registrar observación de fiscalización (extiende CU10) | Fiscalizador | RF17 |
| CU12 | Consultar historial y constancias | Patrón / armador | RF21 |
| CU13 | Consultar tablero de indicadores | Administrador del DPA, analista | RF18, RF24 |
| CU14 | Generar y exportar reportes | Analista; SITRAPESCA | RF19, RF20 |
| CU15 | Sincronizar registros fuera de línea | Registrador del DPA | RF12 |
| CU16 | Anular desembarque | Administrador del DPA | RF23 |

Actores externos que son sistemas: **SITRAPESCA** (PRODUCE) y **Pasarela SMS**.

## 8. Matriz de trazabilidad

Relaciona cada requerimiento funcional con su necesidad, caso de uso, historia de usuario, entrega y el objeto de la base de datos que lo soporta (`base-de-datos/sirdepa_schema.sql`).

| RF | Necesidad | Caso de uso | Historia | Entrega | Base de datos |
|---|---|---|---|---|---|
| RF01 | N03, N11 | CU01 | HU01, HU02 | Sprint 1 | `usuario`, `rol` |
| RF02 | N06 | CU02 | HU03 | Sprint 1 | `embarcacion`, `armador` |
| RF03 | N06, N07 | CU02 | HU04 | Sprint 1 | `permiso_pesca`, `permiso_especie`, `permiso_arte` |
| RF04 | N11 | CU03 | HU05 | Sprint 1 | `especie`, `talla_minima`, `arte_pesca`, `zona_pesca`, `veda` |
| RF05 | N01 | CU04 | HU20 | Release 2 | `aviso_arribo` |
| RF06 | N01 | CU05 | HU06 | Sprint 1 | `desembarque` |
| RF07 | N01, N09 | CU05 | HU07 | Sprint 1 | `detalle_desembarque` |
| RF08 | N01 | CU05 | HU22 | Release 2 | (aplicación móvil) |
| RF09 | N09 | CU05 (extensión) | HU10 | Sprint 2 | `muestreo_talla` |
| RF10 | N07 | CU06 | HU09 | Sprint 2 | `validar_desembarque()`, `resultado_validacion` |
| RF11 | N07 | CU05 (extensión) | HU23 | Release 2 | `evidencia_foto` |
| RF12 | N01 | CU15 | HU08 | Sprint 2 | `desembarque.id_desembarque` (UUID) |
| RF13 | N03, N08 | CU07 | HU11 | Sprint 2 | `emitir_constancia()`, `constancia` |
| RF14 | N02, N08 | CU08 | HU12 | Sprint 2 | `lote_destino`, `v_saldo_detalle` |
| RF15 | N08 | CU09 | HU14 | Release 2 | `lote_destino.estado` |
| RF16 | N07, N08 | CU10 | HU13 | Sprint 2 | `v_verificacion_publica` |
| RF17 | N07 | CU11 | HU15 | Release 2 | `inspeccion` |
| RF18 | N06 | CU13 | HU16 | Release 2 | `v_tablero_diario` |
| RF19 | N09 | CU14 | HU17 | Release 2 | `v_reporte_imarpe` |
| RF20 | N10 | CU14 | HU18 | Release 2 | `v_export_sitrapesca` |
| RF21 | N05 | CU12 | HU19 | Release 2 | `desembarque`, `constancia` |
| RF22 | N07 | CU06 | HU15 | Release 2 | `alerta`, `v_permisos_por_vencer` |
| RF23 | N07 | CU16 | HU21 | Release 2 | `anular_desembarque()`, `auditoria` |
| RF24 | N06 | CU13 | HU24 | Release 2 | `cierre_diario` |

## 9. Reglas del motor de validación

La validación no bloquea el registro: guarda el resultado de cada regla y clasifica el desembarque con el peor nivel encontrado.

| Regla | Qué verifica | Nivel si falla | Sustento |
|---|---|---|---|
| PERMISO_VIGENTE | La embarcación tiene permiso vigente en la fecha del arribo | No conforme | Ley General de Pesca |
| ESPECIE_AUTORIZADA | El permiso autoriza cada especie desembarcada | No conforme | Permiso de pesca |
| ARTE_AUTORIZADO | El permiso autoriza el arte empleado | No conforme | Permiso de pesca |
| VEDA | Ninguna especie está en veda en esa fecha y zona | No conforme | RD04 |
| TALLA_MINIMA | El % de la muestra bajo la talla mínima vigente no supera la tolerancia | Observado | RD03 |
| ZONA_ARTE | No hay cerco mecanizado dentro de las 3 millas | Observado | RD08 |
| CAPACIDAD_BODEGA | Los kilos no superan lo que admite la bodega declarada | Observado | RD01 |
