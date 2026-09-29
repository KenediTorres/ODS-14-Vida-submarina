# SIRDEPA 🌊

**Sistema de Registro de Desembarque Pesquero Artesanal**
ODS 14: Vida submarina · Tema 1: Registro de desembarque pesquero artesanal

> *Del muelle al dato, en minutos.*

SIRDEPA es un ecosistema digital (aplicación móvil offline-first, portal web de gestión y servicios en la nube) que registra el desembarque de la pesca artesanal en el muelle en menos de tres minutos, lo valida automáticamente contra la normativa vigente y emite una constancia digital con código QR que acredita el origen legal de la pesca.

Proyecto del curso **Análisis y Diseño de Software** · NRC 30228 · Huancayo, 2026
Docente: Osorio Contreras, Rosario Delia

## Integrantes

- Ortega Matos, Andy Jeampier
- Torres Flores, Kenyi Kenedi
- Lozano de la Cruz, Edgard Alejandro
- Palomino Huamán, Damián Samir

## Problema

En los desembarcaderos y caletas del litoral peruano, el registro del desembarque de la pesca artesanal es **manual, fragmentado y tardío**. La información no es confiable, llega tarde a quienes toman decisiones y no permite trazar el origen del producto.

## Cómo funciona

1. **Aviso de arribo (opcional):** el patrón informa desde su celular su hora estimada de llegada.
2. **Registro en el muelle:** el registrador del DPA busca la embarcación y registra faena, zona, arte y kilos por especie, incluso sin señal.
3. **Validación automática:** el motor normativo revisa permiso, especie, arte, veda y tallas, y clasifica el desembarque como Conforme, Observado o No conforme.
4. **Constancia con QR:** se emite con código único y hash SHA-256, se envía por SMS al armador y se asignan los kilos a cada comprador.
5. **Verificación e información:** comprador y fiscalizador escanean el QR; los datos alimentan el tablero del DPA y los reportes para IMARPE y PRODUCE.

## Módulos

| Módulo | Qué hace |
|---|---|
| M1 Acceso y seguridad | Ingreso con DNI, PIN y código por SMS; roles; auditoría |
| M2 Maestros | Embarcaciones, armadores, permisos, compradores y lugares de desembarque |
| M3 Catálogo normativo | Especies, tallas mínimas, artes, cuadrículas y vedas con su norma |
| M4 Registro de desembarque | Aviso de arribo, faena, especies y kilos, muestreo, fotos, balanza, modo sin conexión |
| M5 Validación normativa | Motor de reglas que clasifica cada desembarque y genera alertas |
| M6 Constancia y trazabilidad | Constancia con QR y hash, lotes por comprador, verificación pública |
| M7 Fiscalización | Bandeja de alertas, verificación por QR, observaciones y actas |
| M8 Información | Tablero, reportes, exportación Excel/CSV y al SITRAPESCA |

## Estructura del repositorio

```
.
├── README.md
├── docs/
│   ├── requerimientos.md        # RF, RNF, RD, casos de uso y matriz de trazabilidad
│   └── prototipos/              # Prototipos navegables (app.html, web.html) y capturas
├── diagramas/
│   ├── fuentes/                 # Código de los diagramas (.puml, .dot)
│   └── png/                     # Figuras exportadas
├── base-de-datos/
│   ├── sirdepa_schema.sql       # PostgreSQL 16 + PostGIS
│   ├── sirdepa.dbml             # Modelo para dbdiagram.io
│   └── diccionario_datos.json   # Diccionario de datos
├── backlog/
│   ├── backlog.md               # Épicas, historias de usuario y Sprints
│   └── jira_import.csv          # Backlog para importar en Jira
└── .gitignore
```

## Base de datos

```bash
createdb sirdepa
psql -d sirdepa -f base-de-datos/sirdepa_schema.sql
```

El script crea el esquema `sirdepa` en PostgreSQL 16 con PostGIS: 27 tablas, el motor de validación normativa (`validar_desembarque`), la emisión de constancias con hash SHA-256 (`emitir_constancia`), la anulación auditada, una bitácora inmutable y vistas para el tablero, el reporte del IMARPE y la exportación al SITRAPESCA.

- El **desembarque** es la entidad central; su UUID lo genera el celular y sirve de clave de idempotencia para sincronizar sin duplicados.
- Las **tallas mínimas tienen vigencia**, así que un cambio normativo (como los de 2025 para lorna y cabrilla) solo afecta a los desembarques posteriores.
- Se guarda el **resultado de cada regla**, no solo el estado final, para que el fiscalizador vea el motivo exacto.

Para ver el modelo, pegar `sirdepa.dbml` en [dbdiagram.io](https://dbdiagram.io). El DBML y el diccionario de datos se generan desde el script SQL, que es la fuente única.

## Metodología

**Scrum** con Sprints de dos semanas, gestionado en Jira. El backlog tiene 6 épicas y 24 historias de usuario (124 puntos).

| Entrega | Objetivo | Historias | Puntos |
|---|---|---|---|
| Sprint 1 | Registrar desde el celular un desembarque completo de una embarcación con permiso vigente | HU01 – HU07 | 34 |
| Sprint 2 | Validar automáticamente, emitir la constancia con QR verificable y operar sin conexión | HU08 – HU13 | 39 |
| Release 2 | Fiscalización, reportes, SITRAPESCA, historial, balanza, fotos y cierre diario | HU14 – HU24 | 51 |

Detalle en [backlog/backlog.md](backlog/backlog.md).

## Herramientas

Jira Software · GitHub · PlantUML · Graphviz · dbdiagram.io · Draw.io · PostgreSQL + PostGIS
