# Especificación de Requerimientos - SIRDEPA

**Proyecto:** Vida Submarina (ODS 14)
**Sistema:** SIRDEPA - Sistema de Registro de Desembarque Pesquero Artesanal
**Curso:** Análisis y Diseño de Software - NRC 62152 - 2025

---

## 1. Descripción del problema

En el Perú, la actividad pesquera enfrenta sobreexplotación de especies, pesca no regulada e ilegal y la ausencia de un monitoreo inmediato de las capturas y las áreas de faena. Esto pone en riesgo la biodiversidad marina, limita la sostenibilidad del recurso y perjudica a las comunidades costeras que dependen de la pesca.

El sector presenta una crisis multidimensional:

| Dimensión | Problema |
|---|---|
| Ambiental | Sobreexplotación de recursos y pérdida de biodiversidad marina |
| Legal | Pesca ilegal, no declarada y no reglamentada |
| Institucional | Deficiencia en el monitoreo y la fiscalización en tiempo real |
| Socioeconómica | Vulnerabilidad de las comunidades pesqueras artesanales |

## 2. Solución propuesta

Un sistema de monitoreo pesquero que combina tecnología, gestión gubernamental y participación local:

- Las embarcaciones cuentan con **GPS y bitácora digital**; sus datos llegan a una plataforma central administrada por **IMARPE y PRODUCE**.
- Se integran **sensores marinos e imágenes satelitales** para controlar especies y áreas de captura.
- Cada lote capturado recibe un **código QR** que certifica su procedencia legal (trazabilidad).
- Las reglas de zonas, tallas, vedas y permisos se **validan automáticamente** y generan alertas.

## 3. Actores y necesidades

### 3.1 Usuarios gubernamentales (IMARPE, PRODUCE)
- Datos confiables y en tiempo real sobre la actividad pesquera.
- Herramientas para fiscalización eficiente y toma de decisiones.
- Sistemas de alerta temprana ante actividades ilegales.
- Reportes automáticos para políticas públicas.

### 3.2 Armadores y empresas pesqueras
- Documentación simplificada que no afecte su operatividad.
- Certificación de legalidad para acceder a mercados.
- Menores tiempos administrativos.
- Protección frente a la competencia desleal de la pesca ilegal.

### 3.3 Pescadores artesanales y comunidades costeras
- Garantía de sostenibilidad del recurso a futuro.
- Tecnología asequible y fácil de usar.
- Valor agregado de sus productos mediante certificación.
- Participación en la gestión de sus recursos.

### 3.4 Organizaciones ambientales y de investigación
- Transparencia en la información pesquera.
- Indicadores de sostenibilidad y salud de los ecosistemas.

## 4. Requerimientos funcionales (RF)

| ID | Requerimiento | Prioridad | Historias |
|---|---|---|---|
| RF01.1 | Registro automático de la posición GPS cada 15 minutos | Muy alta | HU03 |
| RF01.2 | Alertas automáticas por ingreso a zonas restringidas | Muy alta | HU07, HU10 |
| RF01.3 | Digitalización de las bitácoras de pesca | Muy alta | HU01, HU04 |
| RF01.4 | Fotos digitales de las capturas como evidencia | Media | HU05 |
| RF01.5 | Códigos QR únicos por lote de captura | Alta | HU06, HU13 |
| RF01.6 | Monitoreo de condiciones meteorológicas | Media | HU14 |
| RF01.7 | Notificaciones automáticas de irregularidades | Muy alta | HU10 |

## 5. Requerimientos no funcionales (RNF)

| ID | Requerimiento | Categoría | Cómo se atiende en el diseño |
|---|---|---|---|
| RNF 01.1 | Tiempo de respuesta menor a 3 segundos para consultas | Rendimiento | Índices B-tree y GIST en PostgreSQL; vistas para reportes |
| RNF 01.2 | Autenticación de dos factores para usuarios críticos | Seguridad | Restricción `ck_usuario_2fa_criticos` en la tabla `usuario` |
| RNF 01.3 | Disponibilidad del 99.5 % en horario laboral | Disponibilidad | Arquitectura cliente-servidor con API REST desacoplada |
| RNF 01.4 | Capacidad de crecimiento hasta 10 000 embarcaciones | Escalabilidad | Claves `BIGSERIAL` en tablas de alto volumen e índices por embarcación y fecha |

## 6. Requerimientos de dominio (RD)

| ID | Requerimiento | Cómo se atiende |
|---|---|---|
| RD01 | Cumplimiento del D.S. 012-2001-PE (Reglamento de la Ley General de Pesca) y modificatorias | Tablas `permiso`, `veda`, `zona` y `especie` con validación automática |
| RD09 | Procesos simplificados que no retrasen las operaciones pesqueras | App móvil con modo offline y sincronización por lotes |
| RD17 | Monitoreo de indicadores de sostenibilidad pesquera | Vistas `v_avance_cuota` y `v_desembarque_por_especie` |

## 7. Reglas de negocio validadas automáticamente

| Regla | Disparador | Alerta generada |
|---|---|---|
| Una embarcación no debe estar dentro de una zona restringida vigente | Nueva posición GPS | `ZONA_RESTRINGIDA` (Alta) |
| La talla promedio debe ser mayor o igual a la talla mínima de la especie | Nuevo detalle de captura | `TALLA_MINIMA` (Media) |
| No se captura una especie durante su periodo de veda | Nuevo detalle de captura | `VEDA` (Alta) |
| Toda captura requiere un permiso vigente de la embarcación | Nueva captura | `PERMISO_VENCIDO` (Crítica) |

La implementación está en `base-de-datos/sirdepa_schema.sql` (sección 13).

## 8. Matriz de trazabilidad

| Requerimiento | Caso de uso | Tablas principales |
|---|---|---|
| RF01.1 | Enviar posición GPS | `posicion_gps` |
| RF01.2 | Generar alertas | `zona`, `alerta` |
| RF01.3 | Registrar captura en bitácora | `captura`, `detalle_captura` |
| RF01.4 | Adjuntar fotos de evidencia | `evidencia_foto` |
| RF01.5 | Generar lote y código QR / Verificar trazabilidad | `lote`, `v_trazabilidad_lote` |
| RF01.6 | Monitoreo meteorológico | `sensor_registro` |
| RF01.7 | Generar alertas / Auditoría | `alerta`, `auditoria` |
| RD01 | Gestionar zonas, vedas y cuotas | `permiso`, `veda`, `especie` |

## 9. Documentos relacionados

- Diagramas: [`../diagramas`](../diagramas)
- Modelo de datos: [`../base-de-datos`](../base-de-datos)
- Backlog del producto: [`../backlog/backlog.md`](../backlog/backlog.md)
- Prototipos: [`./prototipos`](./prototipos)
