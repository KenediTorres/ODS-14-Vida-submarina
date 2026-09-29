# Product Backlog - SIRDEPA

Backlog del producto según el informe del proyecto (Capítulo 5). Se gestiona en Jira Software con Scrum y Sprints de dos semanas.

> **Objetivo del Producto:** que todo desembarque del DPA piloto quede registrado, validado y con constancia verificable el mismo día en que ocurre.

- **Épicas:** 6 · **Historias de usuario:** 24 · **Puntos totales:** 124
- **Priorización:** MoSCoW — M (indispensable), S (deseable), C (opcional)
- **Estimación:** puntos de historia en escala de Fibonacci
- **Capacidad del equipo:** cerca de 40 puntos por Sprint

## Épicas

| ID | Épica | Objetivo | Historias | Requerimientos | Puntos |
|---|---|---|---|---|---|
| E1 | Acceso y maestros | Controlar el acceso y registrar embarcaciones, permisos y catálogos. | HU01, HU02, HU03, HU04, HU05 | RF01–RF04 | 21 |
| E2 | Registro en el muelle | Registrar el desembarque en minutos, incluso sin señal. | HU06, HU07, HU08, HU20, HU22, HU23 | RF05–RF08, RF11, RF12 | 32 |
| E3 | Validación normativa | Clasificar cada desembarque según las normas vigentes. | HU09, HU10 | RF09, RF10 | 13 |
| E4 | Constancia y trazabilidad | Emitir constancias verificables y trazar los lotes vendidos. | HU11, HU12, HU13, HU14 | RF13–RF16 | 21 |
| E5 | Fiscalización y control | Alertar, registrar observaciones y auditar cambios. | HU15, HU21 | RF17, RF22, RF23 | 8 |
| E6 | Información y reportes | Tablero, reportes, exportación e historial del armador. | HU16, HU17, HU18, HU19, HU24 | RF18–RF21, RF24 | 29 |

## Plan de entregas

| Entrega | Objetivo | Historias | Puntos |
|---|---|---|---|
| Sprint 1 | Registrar desde el celular un desembarque completo de una embarcación con permiso vigente. | HU01, HU02, HU03, HU04, HU05, HU06, HU07 | 34 |
| Sprint 2 | Validar automáticamente, emitir la constancia con QR verificable y operar sin conexión. | HU08, HU09, HU10, HU11, HU12, HU13 | 39 |
| Release 2 | Recepción de lotes, fiscalización, tablero, reportes, SITRAPESCA, historial, aviso de arribo, anulación, balanza, fotos y cierre diario. Se reparte en los Sprints 3 y 4 según la velocidad medida. | HU14, HU15, HU16, HU17, HU18, HU19, HU20, HU21, HU22, HU23, HU24 | 51 |

Los Sprints 1 y 2 forman el producto mínimo viable (MVP).

## Historias de usuario

| ID | Épica | Historia de usuario | Criterios de aceptación | Pri. | SP | Entrega |
|---|---|---|---|---|---|---|
| HU01 | E1 | Como administrador del sistema, quiero registrar usuarios con su rol y DPA asignado, para controlar quién accede a cada función. | Dado un DNI no registrado, cuando creo el usuario, entonces recibe por SMS un PIN temporal.<br>No se permiten DNI duplicados. | M | 3 | Sprint 1 |
| HU02 | E1 | Como usuario, quiero ingresar con mi DNI, mi PIN y un código por SMS, para acceder sin necesitar correo electrónico. | Dado un DNI y PIN correctos, cuando ingreso el código recibido, entonces accedo según mi rol.<br>Tras 5 intentos fallidos la cuenta se bloquea 15 minutos. | M | 5 | Sprint 1 |
| HU03 | E1 | Como administrador del DPA, quiero registrar embarcaciones con matrícula, eslora y capacidad de bodega, para que se clasifiquen como artesanales o de menor escala. | Dada una bodega mayor a 32,6 m³, cuando guardo, entonces el sistema rechaza la categoría artesanal.<br>La matrícula es única. | M | 3 | Sprint 1 |
| HU04 | E1 | Como administrador del DPA, quiero registrar permisos con su vigencia, especies y artes autorizados, para que cada desembarque se valide automáticamente. | Dado un permiso vencido, cuando consulto la embarcación, entonces aparece «sin permiso vigente». | M | 5 | Sprint 1 |
| HU05 | E1 | Como administrador, quiero mantener especies, tallas mínimas, tolerancias, artes, zonas y vedas con su norma, para actualizar las reglas sin programar. | Dado un cambio de talla mínima, cuando lo registro con su resolución, entonces se aplica a los desembarques posteriores y no a los anteriores. | M | 5 | Sprint 1 |
| HU06 | E2 | Como registrador del DPA, quiero registrar un desembarque buscando la embarcación por matrícula o nombre, para documentar cada arribo en menos de 3 minutos. | Dada una embarcación registrada, cuando escribo tres caracteres de su matrícula, entonces aparece en la lista.<br>El registro exige zarpe, arribo, zona y arte. | M | 8 | Sprint 1 |
| HU07 | E2 | Como registrador, quiero agregar varias especies con su peso, presentación y precio en playa, para reflejar la composición real de la descarga. | Dado un peso menor o igual a cero, cuando intento guardar, entonces el sistema lo impide.<br>El total se calcula automáticamente. | M | 5 | Sprint 1 |
| HU08 | E2 | Como registrador, quiero registrar sin conexión y que el sistema sincronice después, para no detener el trabajo cuando falla la señal. | Dado el modo avión, cuando registro 3 desembarques y luego recupero la señal, entonces llegan los 3 al servidor sin duplicados. | M | 8 | Sprint 2 |
| HU09 | E3 | Como registrador, quiero que al confirmar se validen permiso, especie, arte y veda, para saber de inmediato si el desembarque es conforme. | Dada una especie en veda, cuando confirmo, entonces el resultado es No conforme e indica el motivo y la norma. | M | 8 | Sprint 2 |
| HU10 | E3 | Como registrador, quiero registrar un muestreo de tallas, para que el sistema calcule el porcentaje bajo la talla mínima. | Dada una muestra con 14 % bajo la talla y una tolerancia de 10 %, cuando confirmo, entonces el resultado es Observado. | S | 5 | Sprint 2 |
| HU11 | E4 | Como registrador, quiero emitir una constancia con QR y enviarla por SMS al armador, para que tenga prueba del origen legal de su pesca. | Dado un desembarque validado, cuando emito, entonces se genera un PDF con código único y QR, y el armador recibe el SMS. | M | 8 | Sprint 2 |
| HU12 | E4 | Como registrador, quiero asignar los kilos de cada especie a uno o más compradores y vehículos, para trazar el destino de la pesca. | La suma asignada no puede superar lo desembarcado.<br>Se muestra el saldo pendiente. | M | 5 | Sprint 2 |
| HU13 | E4 | Como fiscalizador o comerciante, quiero escanear el QR y ver si la constancia es válida, para verificar la procedencia en segundos. | Dada una constancia anulada o alterada, cuando la escaneo, entonces se muestra «NO VÁLIDA».<br>Respuesta en 2 s o menos. | M | 5 | Sprint 2 |
| HU14 | E4 | Como comerciante, quiero confirmar la recepción de mi lote, para cerrar la cadena de custodia. | Dado un lote despachado a mi RUC, cuando confirmo, entonces pasa a «Recibido» con fecha y hora. | S | 3 | Release 2 |
| HU15 | E5 | Como fiscalizador, quiero recibir alertas de desembarques no conformes y registrar observaciones, para priorizar mis inspecciones. | Dado un desembarque No conforme, cuando se emite, entonces aparece en mi bandeja en menos de un minuto. | S | 5 | Release 2 |
| HU16 | E6 | Como administrador del DPA, quiero un tablero con kilos por día, especie, embarcación y arte, para gestionar el desembarcadero con datos. | Los filtros por fecha y especie actualizan los indicadores en 5 s o menos. | S | 8 | Release 2 |
| HU17 | E6 | Como analista del IMARPE, quiero exportar los desembarques del mes con captura y esfuerzo, para incorporarlos a mis análisis. | El archivo CSV o Excel incluye embarcación, arte, zona, días de pesca, especie y kilos. | S | 5 | Release 2 |
| HU18 | E6 | Como analista de PRODUCE, quiero exportar los datos con la estructura del módulo de descarga del SITRAPESCA, para evitar la doble digitación. | El archivo contiene todos los campos exigidos en el RD05. | S | 8 | Release 2 |
| HU19 | E6 | Como armador, quiero consultar mi historial y descargar mis constancias, para demostrar mi esfuerzo pesquero. | Solo veo los desembarques de mis embarcaciones. | S | 5 | Release 2 |
| HU20 | E2 | Como patrón, quiero enviar un aviso de arribo desde mi celular, para agilizar la atención en el muelle. | El aviso aparece en la lista del registrador del DPA indicado. | S | 3 | Release 2 |
| HU21 | E5 | Como administrador del DPA, quiero anular un desembarque indicando el motivo, para corregir errores sin perder la trazabilidad. | La anulación exige motivo, queda en la auditoría y el QR responde «NO VÁLIDA». | S | 3 | Release 2 |
| HU22 | E2 | Como registrador, quiero leer el peso desde una balanza digital, para evitar errores de digitación. | Dada una balanza emparejada, cuando pulso «Leer balanza», entonces el peso se completa solo. | C | 5 | Release 2 |
| HU23 | E2 | Como registrador, quiero adjuntar fotos de la descarga, para contar con evidencia. | Máximo 3 fotos de hasta 300 KB cada una, guardadas con su hash. | S | 3 | Release 2 |
| HU24 | E6 | Como administrador del DPA, quiero realizar el cierre diario, para cuadrar los kilos registrados y despachados. | El cierre muestra las diferencias por especie y bloquea la edición de los registros del día. | C | 3 | Release 2 |

## Sprint Backlog del Sprint 1

- **Duración:** 2 semanas ([dd/mm] – [dd/mm/2026])
- **Incremento esperado:** Acceso con DNI + PIN + OTP; embarcaciones, permisos y catálogos cargados; pantalla de registro con detalle por especie.
- **Demostración (Sprint Review):** Registro de un desembarque de prueba de principio a fin.

| Tarea | HU | Responsable | Horas |
|---|---|---|---|
| Configurar el repositorio, ramas (main, develop, feature) y la integración continua básica | HU01 | [Integrante] | 4 |
| Crear las tablas de usuarios, roles, embarcaciones y permisos (script SQL) | HU03 | [Integrante] | 6 |
| Servicio de autenticación con DNI, PIN y OTP (SMS simulado) | HU02 | [Integrante] | 10 |
| Pantallas de administración de usuarios y embarcaciones | HU01 | [Integrante] | 8 |
| Registro de permisos con especies y artes autorizados | HU04 | [Integrante] | 8 |
| Carga inicial del catálogo normativo (especies, artes, cuadrículas, vedas) | HU05 | [Integrante] | 6 |
| Pantalla móvil «Nuevo desembarque» con búsqueda de embarcación | HU06 | [Integrante] | 12 |
| Detalle por especie con cálculo del total | HU07 | [Integrante] | 8 |
| Pruebas de aceptación y preparación de la demostración | HU07 | [Integrante] | 6 |
| **Total** | | | **68** |

## Sprint Backlog del Sprint 2

- **Duración:** 2 semanas ([dd/mm] – [dd/mm/2026])
- **Incremento esperado:** Validación normativa con resultados explicados; constancia PDF con QR enviada por SMS; lotes por comprador; verificación pública; modo sin conexión.
- **Demostración (Sprint Review):** Registro en modo avión, sincronización y verificación del QR desde otro celular.

| Tarea | HU | Responsable | Horas |
|---|---|---|---|
| Base de datos local SQLite y cola de sincronización con UUID | HU08 | [Integrante] | 12 |
| Servicio idempotente POST /desembarques | HU08 | [Integrante] | 6 |
| Motor de validación (Strategy) con reglas de permiso, especie, arte y veda | HU09 | [Integrante] | 12 |
| Regla de talla mínima y pantalla de muestreo | HU10 | [Integrante] | 8 |
| Constancia PDF con QR y hash; envío por SMS | HU11 | [Integrante] | 10 |
| Asignación de lotes con control de saldo | HU12 | [Integrante] | 6 |
| Página pública de verificación por QR | HU13 | [Integrante] | 6 |
| Pruebas de corte de red y pruebas unitarias del motor de reglas | HU09 | [Integrante] | 6 |
| Sprint Review con personal del DPA piloto y retrospectiva | HU13 | [Integrante] | 4 |
| **Total** | | | **70** |

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

## Importar a Jira

1. Crear en Jira un proyecto de tipo **Scrum** llamado «SIRDEPA».
2. Crear los Sprints «SIRDEPA Sprint 1» y «SIRDEPA Sprint 2» en el tablero.
3. Importar `jira_import.csv` desde **Configuración → Sistema → Importación externa → CSV** (UTF-8, separador coma) y mapear:
   - `Issue ID` → *Issue Id* y `Parent ID` → *Parent Id* (enlaza historias con épicas y subtareas con historias)
   - `Issue Type`, `Summary`, `Description`, `Priority` → campos del mismo nombre
   - `Epic Name` → *Epic Name* (solo en proyectos gestionados por la empresa)
   - `Sprint` → *Sprint* y `Story Points` → *Story point estimate*
   - cada columna `Labels` → *Labels*
4. Las historias del Release 2 quedan en el backlog, sin Sprint, con la etiqueta `release-2`.
5. Prioridades: M → High, S → Medium, C → Low (la etiqueta `moscow-M/S/C` conserva la clasificación original).
