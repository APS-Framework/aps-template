---
name: aps-deploy-template
description: Plantillas de callers para los workflows reutilizables de APS-Framework/.github. Genera ficheros minimos en .github/workflows/ que invocan los workflows centralizados de CI, deploy de Functions y deploy de Container Apps. Carga cuando el agente aps-scaffolder va a crear o actualizar workflows de CI/CD.
license: MIT
compatibility: opencode
metadata:
  audience: aps-scaffolder
  workflow: ci-cd-scaffolding
---

# Plantilla: Callers para workflows reutilizables de APS-Framework

Los workflows de CI/CD **no se crean desde cero** en cada repo. La
organización `APS-Framework` mantiene workflows reutilizables en el repo
[`APS-Framework/.github`](https://github.com/APS-Framework/.github). Cada
repo consumidor solo necesita un **caller** mínimo (~15 líneas) que invoca
el workflow centralizado con `uses:` y `secrets: inherit`.

## Workflows reutilizables disponibles

| Workflow | Ubicación | Qué hace |
|---|---|---|
| `nuget-ci-publish.yml` | `APS-Framework/.github/.github/workflows/` | CI (restore+build+test) en push/PR; publicación NuGet manual vía `workflow_dispatch` |
| `azure-functions-deploy.yml` | `APS-Framework/.github/.github/workflows/` | Build + deploy de Azure Functions (Isolated Worker v4) vía OIDC |
| `container-app-deploy.yml` | `APS-Framework/.github/.github/workflows/` | Build .NET + docker build/push a ACR + deploy a Azure Container Apps |

> **Referencia completa**: ver
> [`README-nuget.md`](https://github.com/APS-Framework/.github/blob/main/README-nuget.md)
> para el flujo de versiones, secrets y configuración de NuGet.

---

## Cuándo generar cada caller

| Tipo de repo | Callers a generar | Motivo |
|---|---|---|
| **SDK / NuGet library / SG** | `publish.yml` | Publica paquetes NuGet |
| **Azure Functions** | `publish.yml` + `deploy.yml` | CI + deploy a Function App |
| **Container App** | `publish.yml` + `deploy.yml` | CI + deploy a Container App |
| **Web App (App Service)** | `publish.yml` | Solo CI; deploy no cubierto por workflow reutilizable |

> Si el repo publica paquetes Y despliega una app, **ambos** callers
> coexisten en `.github/workflows/`.

---

## Caller: CI + Publish NuGet

### `.github/workflows/publish.yml` (un solo paquete)

```yaml
name: CI & Publish

on:
  push:
    branches: [main]
  pull_request:
    branches: [main]
  workflow_dispatch:
    inputs:
      release_type:
        description: 'Tipo de release (rc | stable | vacío = solo CI)'
        required: false
        type: choice
        default: ''
        options: ['', rc, stable]

permissions:
  contents: write
  packages: write

jobs:
  ci-publish:
    uses: APS-Framework/.github/.github/workflows/nuget-ci-publish.yml@main
    with:
      release_type: ${{ inputs.release_type || '' }}
    secrets: inherit
```

### `.github/workflows/publish.yml` (múltiples paquetes)

```yaml
name: CI & Publish

on:
  push:
    branches: [main]
  pull_request:
    branches: [main]
  workflow_dispatch:
    inputs:
      release_type:
        description: 'Tipo de release (rc | stable | vacío = solo CI)'
        required: false
        type: choice
        default: ''
        options: ['', rc, stable]
      packages:
        description: 'Uno o varios paquetes separados por comas'
        required: false
        type: string
        default: ''

permissions:
  contents: write
  packages: write

jobs:
  ci-publish:
    uses: APS-Framework/.github/.github/workflows/nuget-ci-publish.yml@main
    with:
      release_type: ${{ inputs.release_type || '' }}
      packages: ${{ inputs.packages || '' }}
    secrets: inherit
```

> En push/PR solo ejecuta build+test. Para publicar: `gh workflow run
> publish.yml -f release_type=stable` o `-f release_type=rc`.

---

## Caller: Deploy Azure Functions

### `.github/workflows/deploy.yml`

```yaml
name: Deploy

on:
  workflow_dispatch:
    inputs:
      environment:
        required: true
        type: choice
        options: [dev, int, pro]

jobs:
  deploy:
    uses: APS-Framework/.github/.github/workflows/azure-functions-deploy.yml@main
    with:
      environment: ${{ inputs.environment }}
      function_app_name: ${{ vars.FUNCTION_APP_NAME }}
      project_path: src/{NombreProyecto}
    secrets: inherit
```

> `FUNCTION_APP_NAME` se configura como **variable** de GitHub (repo o
> entorno), no como secret. El `project_path` apunta al directorio del
> csproj de la Function App.

---

## Caller: Deploy Container App

### `.github/workflows/deploy.yml`

```yaml
name: Container App CI/CD

on:
  workflow_dispatch:
    inputs:
      environment:
        required: true
        type: choice
        options: [dev, int, pro]

jobs:
  deploy:
    uses: APS-Framework/.github/.github/workflows/container-app-deploy.yml@main
    with:
      environment: ${{ inputs.environment }}
      acr_name: ${{ vars.ACR_NAME }}
      container_app_name: ${{ vars.CONTAINER_APP_NAME }}
      resource_group: ${{ vars.RESOURCE_GROUP }}
      container_repository: ${{ vars.CONTAINER_REPOSITORY }}
    secrets: inherit
```

> Las variables `ACR_NAME`, `CONTAINER_APP_NAME`, `RESOURCE_GROUP`,
> `CONTAINER_REPOSITORY` se configuran como **variables** de GitHub por
> entorno.

---

## Secrets y variables requeridos

### Secrets (nivel organización, propagados con `secrets: inherit`)

| Secret | Scope | Tipo | Uso |
|---|---|---|---|
| `APS_NUGET_TOKEN` | Org | Classic PAT `read:packages` | Restore de feeds corporativos en CI y deploy |
| `NUGET_PUBLISH_TOKEN` | Org | PAT `write:packages` | `dotnet nuget push` en publicación |
| `AZURE_CLIENT_ID` | Repo/Env | App OIDC | Login Azure vía Workload Identity |
| `AZURE_TENANT_ID` | Repo/Env | Tenant OIDC | Login Azure |
| `AZURE_SUBSCRIPTION_ID` | Repo/Env | Sub OIDC | Login Azure |
| `NUGET_EXTERNAL_TOKEN` | Repo (opcional) | PAT externo | Solo si el `nuget.config` referencia feeds externos |

> `APS_NUGET_TOKEN` y `NUGET_PUBLISH_TOKEN` los configura el admin de la
> organización una sola vez. Los secrets de Azure los configura el admin
> del repo o del entorno.

### Variables (nivel repo o entorno)

| Variable | Usada por | Ejemplo |
|---|---|---|
| `FUNCTION_APP_NAME` | `deploy.yml` (Functions) | `func-myapp-pro` |
| `ACR_NAME` | `deploy.yml` (Container App) | `acrcorpdev` |
| `CONTAINER_APP_NAME` | `deploy.yml` (Container App) | `ca-myapp-dev` |
| `RESOURCE_GROUP` | `deploy.yml` (Container App) | `RG-MYAPP-DEV` |
| `CONTAINER_REPOSITORY` | `deploy.yml` (Container App) | `myapp` |

---

## Verificacion

Despues de crear los callers, verificar:

1. El workflow aparece en la pestana Actions del repo en GitHub
2. Si hay un PR abierto, el CI se dispara automaticamente (push/PR)
3. El deploy requiere configurar secrets y variables en GitHub:
   - Functions: `AZURE_CLIENT_ID`, `AZURE_TENANT_ID`,
     `AZURE_SUBSCRIPTION_ID` + variable `FUNCTION_APP_NAME`
   - Container App: secrets Azure + variables `ACR_NAME`,
     `CONTAINER_APP_NAME`, `RESOURCE_GROUP`, `CONTAINER_REPOSITORY`
   - NuGet: `APS_NUGET_TOKEN` + `NUGET_PUBLISH_TOKEN` (org-level)

> **Regla dura**: el scaffolder **no** configura secrets ni variables de
> Azure ni hace login con `az`. El usuario (o el admin de la org) debe
> configurarlos manualmente en GitHub Settings > Secrets and variables >
> Actions.

## Limitaciones

- **Web App (App Service)**: no hay workflow reutilizable para deploy
  directo. El caller `publish.yml` cubre CI. Para deploy, el usuario debe
  crear un workflow propio o usar Azure CLI manualmente.
