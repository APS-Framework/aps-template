---
description: Genera callers minimos para los workflows reutilizables de APS-Framework/.github (CI+publish NuGet, deploy Functions, deploy Container Apps). Detecta el tipo de host y genera los callers correspondientes. Uso: /aps-new-workflow [ci|deploy|all].
agent: aps-scaffolder
subtask: false
---

Carga el skill `aps-deploy-template` y genera los callers a los workflows
reutilizables de `APS-Framework/.github`:

$ARGUMENTS

## Comportamiento esperado

El scaffolder detecta el tipo de host del proyecto (leyendo `AGENTS.md`
seccion "Tipo de host" o inspeccionando los csproj) y genera **callers
minimos** que invocan los workflows centralizados con `uses:` y
`secrets: inherit`. **No genera workflows completos desde cero.**

| Tipo de host | `ci` | `deploy` | `all` |
|---|---|---|---|
| FUNCTIONS | `publish.yml` | `deploy.yml` (azure-functions-deploy) | ambos |
| WEBAPP | `publish.yml` | — (no hay workflow reutilizable) | solo ci |
| NUGET_LIBRARY / SG | `publish.yml` | — | solo ci |
| Container App | `publish.yml` | `deploy.yml` (container-app-deploy) | ambos |

Si no se especifica argumento, por defecto `all`.

## Pasos

1. Carga skills: `aps-deploy-template`, `aps-conventions`
2. Detecta tipo de host (`AGENTS.md` o csproj inspection)
3. Detecta nombre del proyecto y si publica NuGet (uno o varios paquetes)
4. Lee el template correspondiente de `aps-deploy-template`
5. Reemplaza placeholders (`{NombreProyecto}`)
6. Crea archivos en `.github/workflows/`:
   - `publish.yml` — caller de `nuget-ci-publish.yml` (CI + publish)
   - `deploy.yml` — caller de `azure-functions-deploy.yml` o
     `container-app-deploy.yml` (si aplica)
7. Si ya existe un caller, avisa antes de sobreescribir
8. Resumen al usuario con:
   - Archivos creados
   - Secrets de organización requeridos (`APS_NUGET_TOKEN`,
     `NUGET_PUBLISH_TOKEN`)
   - Secrets de Azure requeridos (`AZURE_CLIENT_ID`, `AZURE_TENANT_ID`,
     `AZURE_SUBSCRIPTION_ID`)
   - Variables de GitHub requeridas (`FUNCTION_APP_NAME` o
     `ACR_NAME` + `CONTAINER_APP_NAME` + `RESOURCE_GROUP` +
     `CONTAINER_REPOSITORY`)
   - Como disparar el primer deploy (`gh workflow run deploy.yml -f
     environment=dev`)

## Restricciones

- **No** genera workflows completos desde cero. Solo callers que invocan
  los workflows reutilizables de `APS-Framework/.github`.
- **No** configura secrets ni variables. El usuario (o admin de la org)
  debe configurarlos manualmente en GitHub.
- **No** hace login con `az` ni crea recursos en Azure.
- **No** sobreescribe callers existentes sin confirmacion.
- **No** hace commit ni push.
- Si el proyecto es Web App (App Service), avisar que no hay workflow
  reutilizable para deploy directo — solo se genera el caller de CI.

## Secrets y variables (resumen para el usuario)

| Tipo | Secret/Variable | Nivel | Como configurarlo |
|---|---|---|---|
| NuGet CI | `APS_NUGET_TOKEN` | Org | Admin de la org: `gh secret set APS_NUGET_TOKEN --org {org} --visibility all` |
| NuGet Publish | `NUGET_PUBLISH_TOKEN` | Org | Admin de la org: `gh secret set NUGET_PUBLISH_TOKEN --org {org} --visibility all` |
| Functions deploy | `AZURE_CLIENT_ID`, `AZURE_TENANT_ID`, `AZURE_SUBSCRIPTION_ID` | Repo/Env | GitHub Settings > Secrets and variables > Actions |
| Functions deploy | `FUNCTION_APP_NAME` (variable) | Repo/Env | GitHub Settings > Secrets and variables > Variables |
| Container App | `AZURE_*` + variables ACR/CA/RG | Repo/Env | GitHub Settings > Secrets and variables > Actions/Variables |

## Ejemplos de uso

```
/aps-new-workflow
/aps-new-workflow ci
/aps-new-workflow deploy
```
