# SIRDEPA 🌊

**Sistema de Registro de Desembarque Pesquero Artesanal**

ODS 14: Vida submarina 
· Tema 1: Registro de desembarque pesquero artesanal

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
│   └── prototipos/              # Enlace al prototipo en Figma y lista de pantallas
├── diagramas/
│   ├── fuentes/                 # Código de los diagramas (.puml, .dot)
│   └── png/                     # Figuras exportadas
├── base-de-datos/
│   ├── sirdepa_schema.sql       # Script completo (capítulo 7 y Anexo B del informe)
│   ├── scripts/                 # El mismo script dividido en seis partes
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
psql -d sirdepa -v ON_ERROR_STOP=1 -f base-de-datos/sirdepa_schema.sql
```

El script crea el esquema `sirdepa` en PostgreSQL 16 con PostGIS y se puede ejecutar más de una vez. Incluye:

- **30 tablas** en 3FN/4FN, con 15 enumeraciones y 130 restricciones con nombre (PK, FK, UNIQUE, CHECK y exclusión).
- **13 funciones y procedimientos**: `fn_registrar_desembarque` (registro idempotente desde el celular), `sp_guardar_validacion` (resultado de las cinco reglas), `fn_emitir_constancia` (código, QR y hash SHA-256), `sp_asignar_lote`, `sp_cerrar_dia` y `fn_verificar` (verificación pública por QR).
- **16 triggers** para la auditoría inmutable, las alertas al fiscalizador, el límite de tres fotos y el control de saldo de los lotes.
- **3 vistas y 1 vista materializada**: verificación pública, avance de cuotas, exportación al SITRAPESCA y tablero diario.
- **72 índices**: `CLUSTER` en `desembarque` y `detalle_desembarque`, y non-clustered B-tree, parciales, de cobertura, BRIN y GiST.
- **Seguridad**: cinco roles con privilegio mínimo y seguridad por filas (RLS) en `desembarque`.
- **Datos de prueba y pruebas** que comprueban el registro, la validación, la constancia y la verificación.

| Archivo en `scripts/` | Contenido |
|---|---|
| `01_esquema.sql` | Tipos, tablas y restricciones |
| `02_programacion.sql` | Funciones, procedimientos, triggers y vistas |
| `03_indices.sql` | Índices clustered y non-clustered |
| `04_seguridad.sql` | Roles, permisos y RLS |
| `05_datos_prueba.sql` | Catálogos y datos de ejemplo |
| `06_pruebas.sql` | Pruebas del flujo completo |

- El **desembarque** es la entidad central; su UUID lo genera el celular y sirve de clave de idempotencia para sincronizar sin duplicados.
- Las **tallas mínimas tienen vigencia**, así que un cambio normativo solo afecta a los desembarques posteriores.
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

Jira Software · GitHub · Figma · PlantUML · Graphviz · dbdiagram.io · Draw.io · PostgreSQL + PostGIS
