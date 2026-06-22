---
description: Genera callers para los workflows reutilizables de APS-Framework/.github (CI+publish NuGet, deploy Functions, deploy Container Apps) invocando las tools del MCP. Detecta el tipo de host y genera los callers correspondientes. Uso: /aps-new-workflow [ci|deploy|all].
agent: aps-scaffolder
subtask: false
---

Carga el skill `aps-deploy-template` y genera los callers a los workflows
reutilizables de `APS-Framework/.github`:

$ARGUMENTS

## Comportamiento esperado

El scaffolder detecta el tipo de host del proyecto y **invoca las tools del
MCP** para obtener los templates de caller correctos. No reproduce YAMLs
desde el skill: las tools del MCP son la fuente de verdad.

| Tipo de host | `ci` | `deploy` | `all` |
|---|---|---|---|
| FUNCTIONS | `publish.yml` | `deploy.yml` | ambos |
| WEBAPP | `publish.yml` | — (no hay workflow reutilizable) | solo ci |
| NUGET_LIBRARY / SG | `publish.yml` | — | solo ci |
| Container App | `publish.yml` | `deploy.yml` | ambos |

Si no se especifica argumento, por defecto `all`.

## Pasos

1. Carga skills: `aps-deploy-template`, `aps-conventions`
2. Detecta tipo de host (`AGENTS.md` o csproj inspection)
3. **Invoca las tools del MCP** según la tabla del skill `aps-deploy-template`:
   - `github__publish` → obtiene template del caller `publish.yml`
   - `github__deploy_functions` → obtiene template del caller `deploy.yml` (Functions)
   - `github__deploy_container_app` → obtiene template del caller `deploy.yml` (Container App)
4. Reemplaza placeholders en los templates devueltos por las tools
5. Crea archivos en `.github/workflows/`
6. Si ya existe un caller, avisa antes de sobreescribir
7. Resumen al usuario con:
   - Archivos creados
   - Secrets y variables requeridos (según lo que devuelvan las tools)
   - Como disparar el primer deploy o publicación

## Restricciones

- **No** reproduce workflows desde el skill. Invoca las tools del MCP para
  obtener los templates correctos.
- **No** configura secrets ni variables. El usuario (o admin de la org)
  debe configurarlos manualmente en GitHub.
- **No** hace login con `az` ni crea recursos en Azure.
- **No** sobreescribe callers existentes sin confirmacion.
- **No** hace commit ni push.
- Si el MCP no está disponible, avisar al usuario que no se pueden generar
  los callers correctamente.
- Si el proyecto es Web App (App Service), avisar que no hay workflow
  reutilizable para deploy directo — solo se genera el caller de CI.

## Ejemplos de uso

```
/aps-new-workflow
/aps-new-workflow ci
/aps-new-workflow deploy
```
