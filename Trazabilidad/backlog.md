# Product Backlog - SIRDEPA

Backlog del producto según el informe del proyecto (capítulo 5, Tablas 20 a 24). Se gestiona en Jira Software (proyecto ODS14) con Scrum y Sprints de dos semanas. Este archivo, Jira y el informe deben decir lo mismo: cualquier cambio empieza en los requerimientos, pasa por la [matriz de trazabilidad](matriz_trazabilidad.md) y recién después se refleja aquí y en Jira.

> **Objetivo del Producto:** que todo desembarque del DPA piloto quede registrado, validado y con constancia verificable el mismo día en que ocurre.

- **Épicas:** 6 · **Historias de usuario:** 25 · **Puntos totales:** 128
- **Priorización:** MoSCoW: M (indispensable), S (deseable), C (opcional)
- **Estimación:** puntos de historia en escala de Fibonacci
- **Capacidad del equipo:** cerca de 40 puntos por Sprint

## Épicas

| ID | Épica | Objetivo | Historias | RF | Pts |
|---|---|---|---|---|---|
| E1 | Acceso y maestros | Controlar el acceso por rol y registrar embarcaciones, permisos y el catálogo normativo. | HU01–HU05 | RF01–RF04, RF22 | 21 |
| E2 | Registro en el muelle y trabajo sin conexión | Registrar el desembarque en minutos, incluso sin señal. | HU06–HU08, HU20, HU22, HU23 | RF05–RF08, RF11, RF12 | 32 |
| E3 | Validación normativa | Clasificar cada desembarque como Conforme, Observado o No conforme. | HU09, HU10 | RF09, RF10 | 13 |
| E4 | Constancia y trazabilidad por lotes | Emitir constancias y QR por lote verificables hasta el primer comprador. | HU11–HU14 | RF13–RF16 | 21 |
| E5 | Fiscalización y control | Alertar, inspeccionar, anular o revalidar con auditoría. | HU15, HU21 | RF17, RF22, RF23 | 8 |
| E6 | Información, reportes y cuotas | Tablero, cierre diario, reportes, avance de cuotas, archivo para el SITRAPESCA e historial. | HU16–HU19, HU24, HU25 | RF18–RF21, RF24, RF25 | 33 |

## Planificación de los Sprints

| Sprint | Fechas | Objetivo del Sprint | Historias | Pts | Incremento planificado | Estado al 06/10/2026 |
|---|---|---|---|---|---|---|
| Sprint 1 – Acceso y registro | 25 sep – 09 oct | Registrar desde el celular un desembarque completo de una embarcación con permiso vigente. | HU01–HU07, HU20, HU23 | 40 | Acceso por rol, maestros, catálogo, registro con detalle por especie, aviso de arribo y fotos. | En curso: análisis y diseño terminados; programación no iniciada. |
| Sprint 2 – Validación y QR | 09 oct – 23 oct | Validar automáticamente, emitir constancias, asignar lotes y operar sin conexión. | HU08–HU13, HU21 | 42 | Validación con tres resultados, constancia y QR por lote, verificación pública, modo sin conexión, anulación y revalidación. | Planificado. |
| Sprint 3 – Trazabilidad | 23 oct – 06 nov | Cerrar la trazabilidad e informar a las autoridades. | HU14–HU19, HU24, HU25 (+HU22) | 41 (+5) | Recepción de lotes, alertas al fiscalizador, tablero, reportes, archivo para el SITRAPESCA, historial, cierre diario y avance de cuotas. | Planificado. |

## Historias de usuario

| ID | Épica | Historia de usuario | Criterios de aceptación | Prioridad | Pts | Sprint |
|---|---|---|---|---|---|---|
| HU01 | E1 | Como administrador, quiero registrar usuarios con su rol y DPA, para controlar quién accede a cada función. | Dado un DNI no registrado, cuando creo el usuario, entonces recibe por SMS su acceso inicial. No se permiten DNI duplicados. El administrador del DPA solo crea registradores, armadores y compradores de su DPA. | M | 3 | 1 |
| HU02 | E1 | Como usuario, quiero ingresar con mi DNI, un código SMS y, si mi rol lo exige, mi PIN, para acceder sin correo electrónico. | Dado un DNI y PIN correctos, cuando ingreso el código recibido, entonces accedo según mi rol. Tras 5 intentos fallidos la cuenta se bloquea 15 minutos. Puedo cambiar mi PIN. | M | 5 | 1 |
| HU03 | E1 | Como administrador del DPA, quiero registrar, editar y dar de baja embarcaciones, para que se clasifiquen como artesanales o de menor escala. | Dada una bodega mayor a 32,6 m³, cuando guardo, entonces el sistema rechaza la categoría artesanal. La matrícula es única. Puedo buscar por matrícula o nombre. | M | 3 | 1 |
| HU04 | E1 | Como administrador del DPA, quiero registrar permisos con su vigencia, especies y artes, para que cada desembarque se valide. | Dado un permiso vencido, cuando consulto la embarcación, entonces aparece «sin permiso vigente». Dado un permiso que vence en 30 días, el armador recibe un SMS de aviso. | M | 5 | 1 |
| HU05 | E1 | Como administrador del sistema, quiero mantener especies, tallas, artes, zonas, vedas y límites de captura con su norma, para actualizar las reglas sin programar. | Dado un cambio de talla mínima, cuando lo registro con su resolución, entonces se aplica a los desembarques posteriores y no a los anteriores. | M | 5 | 1 |
| HU06 | E2 | Como registrador, quiero registrar un desembarque buscando la embarcación, para documentar cada arribo en menos de 3 minutos. | Dada una embarcación registrada, cuando escribo tres caracteres de su matrícula, entonces aparece en la lista. El registro exige zarpe, arribo, zona por cuadrícula y arte. | M | 8 | 1 |
| HU07 | E2 | Como registrador, quiero agregar varias especies con su peso, presentación y precio, para reflejar la descarga real. | Dado un peso menor o igual a cero, cuando intento guardar, entonces el sistema lo impide. El total se calcula automáticamente. | M | 5 | 1 |
| HU08 | E2 | Como registrador, quiero registrar sin conexión y que el sistema sincronice después, para no detener el trabajo cuando falla la señal. | Dado el modo avión, cuando registro 3 desembarques y recupero la señal, entonces llegan los 3 al servidor sin duplicados y se emiten las constancias que correspondan. | M | 8 | 2 |
| HU09 | E3 | Como registrador, quiero que al sincronizar se validen permiso, especie, arte y veda, para saber si el desembarque es conforme. | Dada una especie en veda, cuando se valida, entonces el resultado es No conforme, se indica la norma, no se emite constancia y se alerta al fiscalizador. | M | 8 | 2 |
| HU10 | E3 | Como registrador, quiero registrar un muestreo de tallas, para que el sistema calcule el porcentaje bajo la talla mínima. | Dada una muestra con 14 % bajo la talla y una tolerancia de 10 %, cuando se valida, entonces el resultado es Observado. | S | 5 | 2 |
| HU11 | E4 | Como registrador, quiero emitir la constancia con QR y enviarla por SMS al armador, para que tenga prueba del origen legal. | Dado un desembarque Conforme u Observado, cuando se emite, entonces se genera un PDF con código, QR y estado, y el armador recibe el SMS. Dado uno No conforme, no se emite. | M | 8 | 2 |
| HU12 | E4 | Como registrador, quiero asignar los kilos de cada especie a compradores, para trazar el destino de la pesca. | La suma asignada no puede superar lo desembarcado. Cada lote recibe código y QR propios. No se asignan lotes a un desembarque No conforme. | M | 5 | 2 |
| HU13 | E4 | Como cualquier persona, quiero escanear un QR y ver si la constancia o el lote son válidos, para verificar la procedencia en segundos. | Dada una constancia anulada o alterada, cuando la escaneo, entonces se muestra «NO VÁLIDA». Respuesta en 2 s o menos, sin iniciar sesión. | M | 5 | 2 |
| HU14 | E4 | Como comprador, quiero confirmar la recepción de mi lote, para cerrar la cadena de custodia. | Dado un lote asignado a mi DNI o RUC, cuando confirmo, entonces pasa a «Recibido». Dado un lote de otro comprador, la confirmación se rechaza. | S | 3 | 3 |
| HU15 | E5 | Como fiscalizador, quiero recibir alertas de desembarques No conformes y Observados y registrar observaciones, para priorizar mis inspecciones. | Dado un desembarque No conforme, cuando se valida, entonces aparece en mi bandeja con prioridad alta en menos de un minuto; uno Observado, con prioridad media. | S | 5 | 3 |
| HU16 | E6 | Como administrador del DPA, quiero un tablero con kilos por día, especie, embarcación y arte, para gestionar el desembarcadero con datos. | Los filtros por fecha y especie actualizan los indicadores en 5 s o menos. | S | 8 | 3 |
| HU17 | E6 | Como analista del IMARPE, quiero exportar los desembarques del mes con captura y esfuerzo, para incorporarlos a mis análisis. | El archivo CSV o Excel incluye embarcación, arte, zona, días de pesca, especie y kilos. | S | 5 | 3 |
| HU18 | E6 | Como analista de PRODUCE, quiero generar el archivo con la estructura del módulo de descarga del SITRAPESCA, para evitar la doble digitación. | El archivo contiene todos los campos exigidos en el RD05 y solo desembarques sincronizados. | S | 8 | 3 |
| HU19 | E6 | Como armador, quiero consultar mi historial y descargar mis constancias, para demostrar mi esfuerzo pesquero. | Dado mi DNI y el código SMS, cuando ingreso, entonces solo veo los desembarques de mis embarcaciones. | S | 5 | 3 |
| HU20 | E2 | Como patrón, quiero enviar un aviso de arribo desde el navegador de mi celular, para agilizar la atención en el muelle. | Dado mi DNI y el código SMS, cuando envío el aviso, entonces aparece en la lista del registrador del DPA indicado. | S | 3 | 1 |
| HU21 | E5 | Como administrador del DPA, quiero anular o revalidar un desembarque indicando el motivo, para corregir errores sin perder la trazabilidad. | La anulación o revalidación exige motivo y queda en la auditoría; tras anular, el QR responde «NO VÁLIDA». | S | 3 | 2 |
| HU22 | E2 | Como registrador, quiero leer el peso desde una balanza digital, para evitar errores de digitación. | Dada una balanza emparejada, cuando pulso «Leer balanza», entonces el peso se completa solo. | C | 5 | 3* |
| HU23 | E2 | Como registrador, quiero adjuntar fotos de la descarga, para contar con evidencia. | Máximo 3 fotos de hasta 300 KB cada una, guardadas con su hash. | S | 3 | 1 |
| HU24 | E6 | Como administrador del DPA, quiero realizar el cierre diario, para cuadrar los kilos registrados y asignados. | El cierre muestra las diferencias por especie y no se completa mientras haya saldo sin justificar (consumo, merma o almacenamiento). | S | 3 | 3 |
| HU25 | E6 | Como analista, quiero ver el avance de capturas por especie frente al límite de captura vigente, para anticipar el cierre de una pesquería. | Dado un límite registrado, cuando el acumulado llega al 80 % y al 100 %, entonces se muestra una alerta. SIRDEPA no asigna cuotas individuales. | S | 4 | 3 |

(\*) HU22 es «C» en MoSCoW: entra al Sprint 3 solo si la velocidad del equipo lo permite.

## Responsables por historia

| ID | Historia de usuario | Sprint | Responsable | Pts |
|---|---|---|---|---|
| HU01 | Registrar usuarios con rol y DPA | 1 | Lozano De La Cruz, Edgard | 3 |
| HU02 | Acceso con DNI, código SMS y PIN | 1 | Lozano De La Cruz, Edgard | 5 |
| HU03 | Embarcaciones | 1 | Ortega Matos, Andy | 3 |
| HU04 | Permisos de pesca y avisos de vencimiento | 1 | Ortega Matos, Andy | 5 |
| HU05 | Catálogo normativo y límites de captura | 1 | Palomino Huamán, Damián | 5 |
| HU06 | Registrar desembarque | 1 | Torres Flores, Kenyi | 8 |
| HU07 | Detalle por especie | 1 | Torres Flores, Kenyi | 5 |
| HU20 | Aviso de arribo | 1 | Ortega Matos, Andy | 3 |
| HU23 | Evidencia fotográfica | 1 | Palomino Huamán, Damián | 3 |
| HU08 | Trabajo sin conexión y sincronización | 2 | Torres Flores, Kenyi | 8 |
| HU09 | Validación normativa | 2 | Palomino Huamán, Damián | 8 |
| HU10 | Muestreo de tallas | 2 | Palomino Huamán, Damián | 5 |
| HU11 | Constancia con QR y SMS | 2 | Lozano De La Cruz, Edgard | 8 |
| HU12 | Lotes con QR propio | 2 | Ortega Matos, Andy | 5 |
| HU13 | Verificación pública por QR | 2 | Ortega Matos, Andy | 5 |
| HU21 | Anulación y revalidación | 2 | Lozano De La Cruz, Edgard | 3 |
| HU14 | Recepción del lote | 3 | Ortega Matos, Andy | 3 |
| HU15 | Alertas y observaciones del fiscalizador | 3 | Palomino Huamán, Damián | 5 |
| HU16 | Tablero de indicadores | 3 | Lozano De La Cruz, Edgard | 8 |
| HU17 | Reporte para el IMARPE | 3 | Torres Flores, Kenyi | 5 |
| HU18 | Archivo para el SITRAPESCA | 3 | Torres Flores, Kenyi | 8 |
| HU19 | Historial del armador | 3 | Ortega Matos, Andy | 5 |
| HU24 | Cierre diario | 3 | Lozano De La Cruz, Edgard | 3 |
| HU25 | Avance de cuotas de captura | 3 | Palomino Huamán, Damián | 4 |
| HU22 | Lectura de balanza (condicional) | 3* | Ortega Matos, Andy | 5 |

## Definición de Listo (DoR)

Una historia entra a un Sprint solo si:

- está redactada como «Como… quiero… para…»;
- tiene criterios de aceptación verificables;
- está estimada en puntos;
- sus dependencias están identificadas;
- cabe en un Sprint.

## Definición de Terminado (DoD)

Una historia está terminada cuando:

- el código está en GitHub y fue revisado por otro integrante mediante pull request;
- las pruebas unitarias pasan (≥ 70 % de cobertura en el motor de reglas);
- el Product Owner verificó los criterios de aceptación;
- los diagramas y el README se actualizaron;
- la funcionalidad corre en el entorno de pruebas sin errores críticos.

## Importación inicial a Jira

`jira_import.csv` es el archivo con el que se creó el proyecto en Jira al inicio. El backlog vigente es el de este archivo y el del tablero de Jira.

1. Crear en Jira un proyecto de tipo **Scrum**.
2. Importar `jira_import.csv` desde **Configuración → Sistema → Importación externa → CSV** (UTF-8, separador coma) y mapear `Issue ID` → *Issue Id*, `Parent ID` → *Parent Id*, `Issue Type`, `Summary`, `Description`, `Priority`, `Sprint` y `Story Points` → *Story point estimate*.
3. Prioridades: M → High, S → Medium, C → Low.
