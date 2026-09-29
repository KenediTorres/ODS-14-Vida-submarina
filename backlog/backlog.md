# Product Backlog - SIRDEPA

Backlog del producto del proyecto **Vida Submarina (ODS 14)**, organizado en épicas, historias de usuario (HU) y tareas técnicas. Cada HU sigue el formato *Como… quiero… para…* e incluye criterios de aceptación y los requerimientos del informe que cubre (RF, RNF, RD).

- **Metodología:** Scrum, sprints de 2 semanas
- **Herramienta:** Jira (importar `jira_import.csv`)
- **Estimación:** puntos de historia en escala Fibonacci (1, 2, 3, 5, 8, 13)

## Resumen de sprints

| Sprint | Objetivo | Historias | Tareas técnicas | Puntos |
|---|---|---|---|---|
| Sprint 1 | Implementar la gestión de flota pesquera y actividades pesqueras | HU01 – HU06 | T01, T02, T03, T04, T05, T07, T08 | 63 |
| Sprint 2 | Desarrollar la gestión normativa, inteligencia pesquera y medioambiental | HU07 – HU15 | T06, T09, T10 | 61 |

## Épicas

| ID | Épica | Descripción | Historias / tareas |
|---|---|---|---|
| EP01 | Gestión de flota pesquera | Registro de embarcaciones y pescadores, y monitoreo satelital de su posición. | HU01, HU02, HU03 |
| EP02 | Actividades pesqueras | Bitácora digital de capturas, evidencia fotográfica y trazabilidad por lote/QR. | HU04, HU05, HU06 |
| EP03 | Gestión normativa | Zonas, vedas, tallas mínimas, cuotas y permisos, con alertas automáticas de incumplimiento. | HU07, HU08, HU09, HU10 |
| EP04 | Inteligencia pesquera | Reportes, dashboards y verificación pública de trazabilidad para la toma de decisiones. | HU11, HU12, HU13 |
| EP05 | Gestión medioambiental | Datos oceanográficos/meteorológicos e indicadores de sostenibilidad del recurso. | HU14, HU15 |
| EP06 | Plataforma y seguridad | Base de datos, aplicaciones, autenticación, roles, auditoría y cifrado (habilitadores técnicos). | T01, T02, T03, T04, T05, T06, T07, T08, T09, T10 |

## Sprint 1 - Gestión de flota y actividades pesqueras

### HU01 - Registrar mi embarcación con matrícula, tipo, eslora y capacidad de bodega

**Épica:** EP01 Gestión de flota pesquera · **Prioridad:** Muy alta · **Puntos:** 5 · **Requerimientos:** RF01.3, RD01

> Como **armador**, quiero **registrar mi embarcación con matrícula, tipo, eslora y capacidad de bodega**, para **que quede habilitada para operar y ser monitoreada**.

**Criterios de aceptación**

- [ ] La matrícula es única y obligatoria
- [ ] Se asocia a un pescador propietario existente
- [ ] Queda en estado ACTIVA y se registra en auditoría

### HU02 - Registrar pescadores con su DNI, comunidad y contacto

**Épica:** EP01 Gestión de flota pesquera · **Prioridad:** Alta · **Puntos:** 3 · **Requerimientos:** RD01

> Como **administrador**, quiero **registrar pescadores con su DNI, comunidad y contacto**, para **vincularlos como propietarios o tripulantes de embarcaciones**.

**Criterios de aceptación**

- [ ] El documento es único
- [ ] Se puede vincular a un usuario del sistema
- [ ] Se valida el formato del DNI (8 dígitos)

### HU03 - Recibir la posición GPS de cada embarcación cada 15 minutos

**Épica:** EP01 Gestión de flota pesquera · **Prioridad:** Muy alta · **Puntos:** 8 · **Requerimientos:** RF01.1, RNF 01.1

> Como **fiscalizador de PRODUCE**, quiero **recibir la posición GPS de cada embarcación cada 15 minutos**, para **conocer en todo momento dónde se está pescando**.

**Criterios de aceptación**

- [ ] Se almacena fecha, latitud, longitud, velocidad y rumbo
- [ ] Se aceptan envíos en lote cuando no hay señal (sync batch)
- [ ] No se duplican posiciones para la misma embarcación y hora
- [ ] La última posición se consulta en menos de 3 s

### HU04 - Registrar mi captura en una bitácora digital indicando especie, kg y talla promedio

**Épica:** EP02 Actividades pesqueras · **Prioridad:** Muy alta · **Puntos:** 8 · **Requerimientos:** RF01.3, RD09

> Como **pescador artesanal**, quiero **registrar mi captura en una bitácora digital indicando especie, kg y talla promedio**, para **cumplir con la declaración sin trámites en papel**.

**Criterios de aceptación**

- [ ] Una captura puede tener varias especies
- [ ] El total en kg se calcula automáticamente
- [ ] Funciona desde el celular y guarda offline hasta tener señal
- [ ] El registro toma menos de 2 minutos

### HU05 - Adjuntar fotos de mi captura

**Épica:** EP02 Actividades pesqueras · **Prioridad:** Media · **Puntos:** 3 · **Requerimientos:** RF01.4

> Como **pescador artesanal**, quiero **adjuntar fotos de mi captura**, para **tener evidencia que respalde lo declarado**.

**Criterios de aceptación**

- [ ] Se aceptan fotos JPG/PNG de hasta 5 MB
- [ ] Se guarda el hash SHA-256 para garantizar integridad
- [ ] Se puede adjuntar más de una foto por captura

### HU06 - Que se genere un código QR único por lote de captura

**Épica:** EP02 Actividades pesqueras · **Prioridad:** Alta · **Puntos:** 5 · **Requerimientos:** RF01.5

> Como **armador**, quiero **que se genere un código QR único por lote de captura**, para **certificar el origen legal del producto ante compradores**.

**Criterios de aceptación**

- [ ] El QR contiene un UUID único
- [ ] Solo se genera si la captura pasó la validación
- [ ] El QR se puede descargar e imprimir

## Sprint 2 - Gestión normativa, inteligencia pesquera y medioambiental

### HU07 - Definir zonas restringidas y reservas marinas como polígonos en el mapa

**Épica:** EP03 Gestión normativa · **Prioridad:** Muy alta · **Puntos:** 5 · **Requerimientos:** RF01.2, RD01

> Como **analista de PRODUCE**, quiero **definir zonas restringidas y reservas marinas como polígonos en el mapa**, para **que el sistema detecte ingresos no autorizados**.

**Criterios de aceptación**

- [ ] Las zonas tienen tipo, norma legal y vigencia
- [ ] Se pueden cargar polígonos en formato GeoJSON
- [ ] Una zona vencida deja de generar alertas

### HU08 - Registrar vedas, tallas mínimas y cuotas por especie

**Épica:** EP03 Gestión normativa · **Prioridad:** Alta · **Puntos:** 5 · **Requerimientos:** RD01, RD17

> Como **investigador de IMARPE**, quiero **registrar vedas, tallas mínimas y cuotas por especie**, para **que las capturas se validen contra la normativa vigente**.

**Criterios de aceptación**

- [ ] Una veda tiene especie, fechas y opcionalmente zona
- [ ] Cada especie tiene talla mínima y cuota anual
- [ ] Los cambios quedan en auditoría

### HU09 - Gestionar los permisos de pesca de cada embarcación y las especies autorizadas

**Épica:** EP03 Gestión normativa · **Prioridad:** Alta · **Puntos:** 5 · **Requerimientos:** RD01

> Como **fiscalizador de PRODUCE**, quiero **gestionar los permisos de pesca de cada embarcación y las especies autorizadas**, para **saber quién puede pescar qué y hasta cuándo**.

**Criterios de aceptación**

- [ ] El número de resolución es único
- [ ] El permiso indica especies autorizadas
- [ ] Una captura sin permiso vigente genera alerta CRÍTICA

### HU10 - Recibir alertas automáticas de ingreso a zona restringida, talla menor, veda o permiso vencido

**Épica:** EP03 Gestión normativa · **Prioridad:** Muy alta · **Puntos:** 8 · **Requerimientos:** RF01.2, RF01.7

> Como **inspector**, quiero **recibir alertas automáticas de ingreso a zona restringida, talla menor, veda o permiso vencido**, para **actuar rápido ante pesca ilegal**.

**Criterios de aceptación**

- [ ] Cada alerta tiene tipo, gravedad y estado de atención
- [ ] Se notifica a IMARPE, PRODUCE y al usuario involucrado
- [ ] El inspector puede marcarla como atendida o descartada

### HU11 - Ver un dashboard con desembarques por período, especie y zona

**Épica:** EP04 Inteligencia pesquera · **Prioridad:** Alta · **Puntos:** 8 · **Requerimientos:** RD17

> Como **analista de IMARPE**, quiero **ver un dashboard con desembarques por período, especie y zona**, para **tomar decisiones sobre vedas y cuotas con datos en tiempo real**.

**Criterios de aceptación**

- [ ] Filtros por rango de fechas, especie y zona
- [ ] Muestra avance de cuota por especie
- [ ] Muestra alertas pendientes por gravedad

### HU12 - Exportar los reportes a Excel y PDF

**Épica:** EP04 Inteligencia pesquera · **Prioridad:** Media · **Puntos:** 3 · **Requerimientos:** RD17

> Como **analista de IMARPE**, quiero **exportar los reportes a Excel y PDF**, para **compartirlos en informes oficiales**.

**Criterios de aceptación**

- [ ] El Excel conserva los filtros aplicados
- [ ] El PDF incluye fecha de generación y usuario

### HU13 - Escanear el QR de un lote y ver su origen

**Épica:** EP04 Inteligencia pesquera · **Prioridad:** Media · **Puntos:** 3 · **Requerimientos:** RF01.5

> Como **consumidor o comprador**, quiero **escanear el QR de un lote y ver su origen**, para **comprobar que el producto proviene de pesca legal**.

**Criterios de aceptación**

- [ ] La consulta no requiere iniciar sesión
- [ ] Muestra embarcación, fecha, lugar, especie y si cumple talla
- [ ] No expone datos personales del pescador

### HU14 - Registrar lecturas de sensores (temperatura del agua, oleaje, viento)

**Épica:** EP05 Gestión medioambiental · **Prioridad:** Media · **Puntos:** 5 · **Requerimientos:** RF01.6

> Como **investigador de IMARPE**, quiero **registrar lecturas de sensores (temperatura del agua, oleaje, viento)**, para **relacionar las capturas con las condiciones del mar**.

**Criterios de aceptación**

- [ ] Cada lectura tiene tipo, valor, unidad y hora
- [ ] Se generan alertas meteorológicas por umbral

### HU15 - Consultar indicadores de sostenibilidad (porcentaje de juveniles, avance de cuota)

**Épica:** EP05 Gestión medioambiental · **Prioridad:** Media · **Puntos:** 5 · **Requerimientos:** RD17

> Como **organización ambiental**, quiero **consultar indicadores de sostenibilidad (porcentaje de juveniles, avance de cuota)**, para **evaluar la salud del recurso**.

**Criterios de aceptación**

- [ ] Se muestra el porcentaje de capturas bajo talla mínima por especie
- [ ] Se muestra el avance de cuota anual
- [ ] Los datos son agregados y anónimos

## Tareas técnicas (EP06 - Plataforma y seguridad)

| ID | Tarea | Descripción | Prioridad | Sprint | Puntos |
|---|---|---|---|---|---|
| T01 | Diseñar esquema de base de datos PostgreSQL | Crear el esquema principal con PostgreSQL 16 y PostGIS (base-de-datos/sirdepa_schema.sql) | Alta | 1 | 5 |
| T02 | Implementar geolocalización con PostGIS | Integrar PostGIS para capturar y consultar ubicaciones y zonas | Alta | 1 | 3 |
| T03 | Crear diccionario de datos | Documentar todas las tablas y campos (base-de-datos/diccionario_datos.json) | Media | 1 | 2 |
| T04 | Diseñar prototipos de UI/UX | Crear diseños visuales para la aplicación web y móvil (docs/prototipos) | Alta | 1 | 5 |
| T05 | Crear aplicación web | Desarrollar la interfaz web responsiva del sistema SIRDEPA | Alta | 1 | 8 |
| T06 | Crear aplicación móvil | Desarrollar la aplicación móvil para registro en campo con modo offline | Media | 2 | 8 |
| T07 | Implementar autenticación de usuarios | Login, sesiones y autenticación de dos factores para usuarios críticos (RNF 01.2) | Alta | 1 | 5 |
| T08 | Gestión de roles y permisos | Control de acceso por rol: ADMIN, IMARPE, PRODUCE, INSPECTOR, ARMADOR, PESCADOR | Alta | 1 | 3 |
| T09 | Auditoría de cambios | Registro de todas las modificaciones en tablas críticas | Media | 2 | 3 |
| T10 | Encriptación de datos | Cifrado en tránsito (HTTPS) y de información sensible en reposo | Alta | 2 | 3 |

## Definición de terminado (DoD)

- El código está en GitHub, revisado por al menos un integrante (pull request).
- Cumple todos los criterios de aceptación de la historia.
- Las validaciones de negocio (zona, talla, veda, permiso) tienen pruebas.
- La documentación y el diccionario de datos están actualizados.
- La historia se movió a **Done** en Jira y se mostró en la Sprint Review.

## Cómo importar a Jira

1. En Jira: **Configuración del sistema → Sistema externo → Importar desde CSV** (o *Filters → Import issues from CSV* en proyectos de equipo).
2. Seleccionar `backlog/jira_import.csv` con codificación **UTF-8** y separador **coma**.
3. Mapear columnas:
   - `Issue ID` → *Issue Id* y `Parent ID` → *Parent Id* (vincula historias y tareas a su épica)
   - `Issue Type`, `Summary`, `Description`, `Priority`, `Status` → campos del mismo nombre
   - las columnas `Labels` (repetidas, una etiqueta por columna) → *Labels*
   - `Epic Name` → *Epic Name* (solo proyectos gestionados por la empresa)
   - `Sprint` → *Sprint* y `Story Points` → *Story point estimate*
4. Crear antes los sprints "SIRDEPA Sprint 1" y "SIRDEPA Sprint 2" en el tablero Scrum para que las historias se asignen automáticamente.
