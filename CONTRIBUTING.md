# Cómo colaborar en el repositorio

Cada integrante sigue el mismo flujo: **issue → rama → commits → pull request → merge**. Todo se hace desde la página de GitHub, sin instalar nada.

## Tareas y ramas de cada integrante

| Integrante | Rama | Tarea (título del issue) | Qué subir |
|---|---|---|---|
| Ortega Matos, Andy | `feature/informe-general` | Subir el informe y sus versiones a /Documentacion y /VersionesFinales | El informe actual en Word y PDF a `Documentacion/`, y `Informe_SIRDEPA_v2.0.pdf` a `VersionesFinales/`. Al cerrar el informe, `Informe_SIRDEPA_vFinal.pdf`. |
| Torres Flores, Kenyi | `feature/repositorio-backlog` | Reorganizar el repositorio en las seis carpetas, actualizar el README y subir la matriz de trazabilidad | Hecho: issue #1 y su pull request. |
| Lozano De La Cruz, Edgard | `feature/diagramas-uml` | Subir los diagramas UML y de arquitectura a /Modelos | Los diagramas de los capítulos 6 a 8 (arquitectura, componentes, despliegue, modelo lógico y físico, clases y secuencia) a `Modelos/`, con su archivo fuente si lo hay. |
| Palomino Huamán, Damián | `feature/prototipos-presentacion` | Subir el enlace y las capturas del prototipo de Figma a /Prototipo | Las capturas de baja y alta fidelidad y los mapas de navegación del capítulo 9 a `Prototipo/`. |

## Pasos

1. **Crea tu issue.** Pestaña **Issues → New issue**. En el título escribe tu tarea (columna «Tarea» de la tabla). En **Assignees** elige tu usuario y pulsa **Submit new issue**. Anota su número (por ejemplo, #3).
2. **Crea tu rama.** En la pestaña **Code**, abre el menú de ramas (dice `main`), escribe el nombre de tu rama (por ejemplo, `feature/diagramas-uml`) y pulsa **Create branch … from main**.
3. **Sube tus archivos a tu rama.** Con tu rama seleccionada, entra a tu carpeta y usa **Add file → Upload files**. En **Commit changes** escribe un mensaje que diga qué subiste (por ejemplo, «Agrega los diagramas de componentes y despliegue»), deja marcado **Commit directly to the `feature/…` branch** y confirma. Haz un commit por cada grupo de archivos, no todo en uno.
4. **Abre el pull request.** Pestaña **Pull requests → New pull request**, con `base: main` y `compare:` tu rama. En la descripción escribe `Closes #` y el número de tu issue (por ejemplo, `Closes #3`), y pulsa **Create pull request**.
5. **Pide la revisión.** En **Reviewers** elige a otro integrante. Cuando lo revise, pulsa **Merge pull request → Confirm merge**. El issue se cierra solo gracias a `Closes #…`.
6. **No borres tu rama después del merge.** La necesitas para la captura del informe.

## Capturas para el informe (capítulo 11.2)

Cada integrante toma sus cuatro capturas y las pega en su subsección del informe:

| Captura | Dónde tomarla | Qué debe verse |
|---|---|---|
| Commits | **Commits** (enlace del reloj en la pestaña Code) → filtro por tu usuario | Tu usuario, la fecha y el mensaje de cada commit |
| Rama | **Branches** | Tu rama, su último commit y la fecha |
| Pull request | Tu pull request | Estado **Merged**, tu rama hacia `main` y quién hizo el merge |
| Issue | Tu issue | Estado **Closed** y el enlace al pull request que lo cerró |

Las capturas del equipo (todas las ramas, los issues cerrados, **Insights → Contributors** y las etiquetas de versión) las toma Torres Flores, Kenyi.

## Mensajes de commit

- En español y en presente: «Agrega…», «Actualiza…», «Corrige…».
- Una idea por commit: qué cambió y, si no es obvio, por qué.

## Acceso al repositorio

Para crear ramas en este repositorio hay que ser colaborador. Si aún no lo eres, pásale tu usuario de GitHub a Kenyi para que te agregue en **Settings → Collaborators**.
