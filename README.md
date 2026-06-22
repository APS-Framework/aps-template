# APS Framework Project Template

Plantilla de proyecto .NET (Azure Functions y ASP.NET Core Web Apps) que
utiliza las librerias del ecosistema **APS Framework**.

Incluye tooling de opencode (agents, skills, commands) que permite
scaffolding y despliegue de proyectos a partir de descripciones en
lenguaje natural, con input minimo del usuario.

## Que incluye este template

- **`.opencode/`** — agents, skills y commands portables a cualquier
  proyecto. Permiten crear Functions y WebApps con paquetes APS
  escribiendo `/aps-new-function MiFunction "descripcion..."`.
- **`scripts/setup-nuget.ps1`** — script de onboarding local para
  configurar credenciales de GitHub Packages. Solo se ejecuta cuando el
  usuario lo invoca explicitamente.
- **`docs/`** — catalogo de demos de referencia que se pueden
  construir con este template (no incluye codigo concreto).

## Que NO incluye este template

- **Demos / proyectos de ejemplo**: viven en repos separados. Este
  template es tooling puro, no incluye proyectos `src/` ni `tests/`
  pre-creados.
- **GitHub Actions / workflows**: el agente `aps-scaffolder` genera
  callers minimos que invocan los workflows reutilizables de
  [`APS-Framework/.github`](https://github.com/APS-Framework/.github)
  cuando el usuario ejecuta `/aps-new-workflow`.
- **Conexion automatica a ninguna organizacion**: el template es
  agnóstico del entorno. Conectar el repo con una org de GitHub es
  una decision explicita del usuario.

## Como usar este template

### 1. Crear un repo desde la plantilla

En GitHub: **"Use this template"** → crear nuevo repositorio.

Clonar el nuevo repo:

```bash
git clone https://github.com/{org}/{nuevo-repo}.git
cd {nuevo-repo}
```

### 2. (Opcional) Configurar credenciales NuGet y MCP server

Solo si el proyecto va a consumir paquetes APS de un feed privado y/o
necesitas el MCP server local. Este paso **es manual y explicito** — el
template no lo hace por ti.

Recomendado: invocar el command `/aps-onboard` desde opencode, que
mediar con el usuario y aplicar el script con los flags adecuados.

Alternativa directa en terminal:

```bash
# Pre-requisitos: gh CLI autenticado, Node.js >= 18 (para el MCP server)
# (dotnet, func y az los valida el scaffolder bajo demanda, no este script)
pwsh ./scripts/setup-nuget.ps1
# Abre una nueva terminal para que las variables de entorno esten disponibles
# Si el script instalo sdk-mcp-server, reinicia la terminal para que este en PATH
# Si ajusto opencode.json (MCP discovery), reinicia opencode
```

El script **no autentica contra Azure** ni valida `dotnet`/`func`/`az`:
esos quedan fuera de alcance del onboarding local. El acceso a Azure
lo gestiona el workflow de deploy de GitHub Actions.

Tampoco **arranca automaticamente** el MCP server. El command
`/aps-onboard` (que es la via recomendada) pregunta al usuario antes
de arrancarlo. Si ejecutas el script directamente y quieres arrancarlo:

```bash
# Solo esta sesion (dejar terminal abierta)
sdk-mcp-server

# O automatico con PM2 (recomendado)
pm2 start "sdk-mcp-server" --name aps-mcp
pm2 save
```

### 3. Crear tu primer proyecto

```
/aps-new-function MiFunction "function que procesa pedidos y los guarda en Cosmos"
/aps-new-webapp MiApi "web api con login con Google"
/aps-add-package APS.Messaging.EventGrid
```

## Comandos opencode disponibles

| Comando | Que hace |
| --- | --- |
| `/aps-onboard` | Onboarding del entorno local: detecta repo/org via `gh`, configura `APS_NUGET_TOKEN` y `GITHUB_TOKEN`, genera/actualiza `NuGet.config`, ajusta `opencode.json` (MCP discovery: conserva `APS-Framework:aps-framework` y anade la org del repo si es diferente) e instala el MCP server (`@APS-Framework/sdk-mcp-server`) si no esta presente. **Pregunta al usuario** si quiere arrancar el MCP server; avisa si hay que reiniciar opencode. No valida `dotnet`/`func`/`az` ni Azure (lo gestiona el workflow de deploy) |
| `/aps-new-function [nombre] [desc...]` | Crea una nueva Azure Function con APS |
| `/aps-new-webapp [nombre] [desc...]` | Crea una nueva ASP.NET Core Web App con APS |
| `/aps-new-gateway [nombre] [desc...]` | Crea un Service Gateway (class library Refit con `APS.ServiceGateway`) |
| `/aps-add-package <paquete>` | Anade un paquete APS a un proyecto existente |
| `/aps-new-workflow [ci\|deploy\|all]` | Genera callers para los workflows reutilizables de APS-Framework/.github (CI+publish NuGet, deploy Functions, deploy Container Apps) |
| `/add-feature [desc...]` | Crea una funcionalidad nueva (endpoint, servicio, job, handler, opcion de config) |
| `/investigate-bug [desc...]` | Investiga y corrige un bug con reproduccion automatizada |
| `/hotfix [desc...]` | Fix rapido para bugs en produccion (sin ciclo de hipotesis) |
| `/refactor-plan [desc...]` | Analiza impacto de un refactor propuesto (read-only) |
| `/refactor-start [desc...]` | Ejecuta un refactor con workers por capa |
| `/refactor-verify` | Retoma un refactor interrumpido: verifica build+tests y propone commit |

## Agents opencode disponibles

| Agent | Modo | Proposito | Como se invoca |
| --- | --- | --- | --- |
| `aps-onboarder` | subagent | Onboarding local: configura `gh` CLI, `NuGet.config` y `opencode.json` con la org detectada, e instala el MCP server (`@APS-Framework/sdk-mcp-server`). **Pregunta al usuario** antes de arrancar el server. **No debe invocarse directamente** | Solo via `/aps-onboard` |
| `aps-scaffolder` | subagent | Crea Functions, WebApps, Service Gateways y workflows de CI/CD a partir de una descripcion. Usado por `/aps-new-function`, `/aps-new-webapp`, `/aps-new-gateway`, `/aps-add-package` y `/aps-new-workflow` | Via los commands de creacion |
| `refactor-orchestrator` | primary | Orquesta refactors, creacion de features, investigacion de bugs y hotfixes. Delega en workers por capa y carga skills como fuente de verdad | Via `/refactor-start`, `/add-feature`, `/investigate-bug`, `/hotfix`, `/refactor-verify` |
| `refactor-analyzer` | subagent | Analisis de impacto read-only de un refactor propuesto. Mapea archivos afectados, evalua riesgo, recomienda estrategia | Via `/refactor-plan` |
| `refactor-verifier` | subagent | Ejecuta `dotnet build` y `dotnet test` sobre la solucion completa. Propone commit si pasa, reporta errores si falla | Invocado por el orchestrator |
| `refactor-worker-*` | subagent | Aplican cambios de refactor por capa: contracts, crosscutting, impl, presentation, tests. Permisos de edicion acotados a su capa | Invocados por el orchestrator |

## Skills opencode disponibles (cargadas bajo demanda)

| Skill | Cuando se carga |
| --- | --- |
| `aps-packages` | Catalogo de paquetes APS con keywords para deteccion de intencion |
| `aps-conventions` | Convenciones de organizacion, naming, archivos obligatorios y stack de tests |
| `aps-function-template` | Plantilla literal de archivos para Function App |
| `aps-webapp-template` | Plantilla literal de archivos para Web App |
| `aps-sg-template` | Plantilla literal de archivos para Service Gateway (Refit + IoCExtensions) |
| `aps-deploy-template` | Plantillas de workflows GitHub Actions (CI, deploy, publish NuGet) |
| `project-structure` | Detecta tipo de solucion y valida estructura antes de refactor/scaffold |
| `add-feature` | Protocolo de creacion de features (endpoints, servicios, jobs, config) |
| `refactor-protocol` | Protocolo de refactors multi-capa con playbooks por tipo |
| `refactor-session` | Persistencia de sesion de refactor en `.opencode/plans/<slug>/state.md` |
| `multi-phase-refactor` | Protocolo para refactors de alto riesgo con tests de caracterizacion |
| `bug-investigation` | Protocolo de investigacion de bugs con reproduccion automatizada |

## Estructura del repositorio

```
.
+-- .opencode/
|   +-- agents/
|   |   +-- aps-onboarder.md
|   |   +-- aps-scaffolder.md
|   |   +-- refactor-orchestrator.md
|   |   +-- refactor-analyzer.md
|   |   +-- refactor-verifier.md
|   |   +-- refactor-worker-contracts.md
|   |   +-- refactor-worker-crosscutting.md
|   |   +-- refactor-worker-impl.md
|   |   +-- refactor-worker-presentation.md
|   |   +-- refactor-worker-tests.md
|   +-- skills/
|   |   +-- aps-packages/SKILL.md
|   |   +-- aps-conventions/SKILL.md
|   |   +-- aps-function-template/SKILL.md
|   |   +-- aps-webapp-template/SKILL.md
|   |   +-- aps-sg-template/SKILL.md
|   |   +-- aps-deploy-template/SKILL.md
|   |   +-- project-structure/SKILL.md
|   |   +-- add-feature/SKILL.md
|   |   +-- refactor-protocol/SKILL.md
|   |   +-- refactor-session/SKILL.md
|   |   +-- multi-phase-refactor/SKILL.md
|   |   +-- bug-investigation/SKILL.md
|   +-- commands/
|       +-- aps-onboard.md
|       +-- aps-new-function.md
|       +-- aps-new-webapp.md
|       +-- aps-new-gateway.md
|       +-- aps-add-package.md
|       +-- aps-new-workflow.md
|       +-- add-feature.md
|       +-- investigate-bug.md
|       +-- hotfix.md
|       +-- refactor-plan.md
|       +-- refactor-start.md
|       +-- refactor-verify.md
|   +-- docs/
|   |   +-- refactor-system.md
|   +-- plans/                # estado de refactors en curso (transitorio)
|   |   +-- .gitkeep
|   +-- plugins/
|   |   +-- pending-plans.ts
+-- scripts/
|   +-- setup-nuget.ps1
+-- AGENTS.md               # Layer Map contractual del proyecto
+-- opencode.json           # config MCP (sdk-mcp-server)
+-- README.md
+-- LICENSE
```

## Pre-requisitos para usar el template

- **gh CLI** — para autenticacion con GitHub Packages y deteccion del repo/org
- **PowerShell 7+** — para el script de setup (multiplataforma)
- **Node.js >= 18** — para el MCP server (`@APS-Framework/sdk-mcp-server`).
  Si no esta instalado, `/aps-onboard` lo avisara y no podra instalar
  el paquete (instalalo desde https://nodejs.org y vuelve a correrlo)
- **.NET SDK 8.x o 10.x** — para build/run de los proyectos
  (lo valida `aps-scaffolder` cuando lo necesita, no el onboarding)
- **Azure Functions Core Tools** — solo si vas a crear Function Apps
  (`winget install Microsoft.AzureFunctionsCoreTools`, `brew install
  azure-functions-core-tools@4`, etc.). Tambien lo verifica
  `aps-scaffolder` bajo demanda
- **Azure CLI / suscripcion** — **NO es necesario en local**. El acceso
  a Azure lo gestiona el workflow de deploy de GitHub Actions. No
  instales ni configures `az` para el flujo de onboarding

## Despues de crear el repo

- [ ] (Opcional) Ejecutar `/aps-onboard` en opencode (o
      `pwsh ./scripts/setup-nuget.ps1` en terminal) para conectar
      con tu org de GitHub e instalar el MCP server
- [ ] Si el script instalo `sdk-mcp-server`, **reiniciar la terminal**
      para que el binario este en PATH
- [ ] Si consintiste arrancar el MCP server, ya esta corriendo; si
      no, **arrancarlo** con `sdk-mcp-server` (o `pm2 start`) cuando
      lo necesites
- [ ] **Reiniciar opencode** (Ctrl+C y reabrir) si el script avisa de
      cambios en `opencode.json` o del arranque del MCP server
- [ ] Abrir el repo en VS Code o Visual Studio con la extension MCP
      para usar los agents y commands
- [ ] Crear el primer proyecto con `/aps-new-function` o
      `/aps-new-webapp`
- [ ] Cuando estes listo para CI/CD, ejecutar `/aps-new-workflow` para
      que el agente genere los callers a los workflows reutilizables de
      APS-Framework/.github. El acceso a Azure se configura con secrets
      OIDC en GitHub, no en local

## Configuracion MCP

Este template se beneficia del **sdk-mcp-server** de APS-Framework, que
expone las herramientas de los repos de la organizacion como tools de
IA. El `opencode.json` ya incluye el discovery por defecto.

El script `setup-nuget.ps1` (invocado por `/aps-onboard`) instala el
paquete `@APS-Framework/sdk-mcp-server` desde GitHub Packages si no
esta presente. **El arranque NO es automatico**: el agente
`aps-onboarder` pregunta al usuario antes de arrancarlo, y solo lo
hace si consiente (flag `-StartMcpServer`).

Si el usuario decidio no arrancar el server, puede hacerlo despues
manualmente:

```bash
sdk-mcp-server   # solo esta sesion
# o, recomendado:
pm2 start "sdk-mcp-server" --name aps-mcp && pm2 save
```

Tras cualquier cambio en `opencode.json` o tras arrancar el server
por primera vez, **reinicia opencode** (Ctrl+C y reabrir) para que
aplique el nuevo MCP discovery y se conecte al server.

Para mas detalles, ver la guia de instalacion de
[sdk-mcp-server](https://github.com/APS-Framework/sdk-mcp-server).

## Licencia

MIT
