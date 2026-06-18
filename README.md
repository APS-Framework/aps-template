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
- **GitHub Actions / workflows**: el agente los crea bajo demanda
  cuando el usuario lo necesita (p.ej. `aps-deployer` o equivalente).
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

### 2. (Opcional) Configurar credenciales NuGet

Solo si el proyecto va a consumir paquetes APS de un feed privado.
Este paso **es manual y explicito** — el template no lo hace por ti.

```bash
# Pre-requisitos: gh CLI autenticado, dotnet SDK 8.x/10.x
pwsh ./scripts/setup-nuget.ps1
# Abre una nueva terminal para que las variables de entorno esten disponibles
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
| `/aps-onboard` | Onboarding del entorno local: detecta repo/org, valida feed NuGet, configura `APS_NUGET_TOKEN`, detecta suscripcion Azure |
| `/aps-new-function [nombre] [desc...]` | Crea una nueva Azure Function con APS |
| `/aps-new-webapp [nombre] [desc...]` | Crea una nueva ASP.NET Core Web App con APS |
| `/aps-add-package <paquete>` | Anade un paquete APS a un proyecto existente |

## Agents opencode disponibles

| Agent | Modo | Proposito |
| --- | --- | --- |
| `aps-scaffolder` | subagent | Crea Functions y WebApps a partir de una descripcion. Usado por `/aps-new-function`, `/aps-new-webapp` y `/aps-add-package` |

## Skills opencode disponibles (cargadas bajo demanda)

| Skill | Cuando se carga |
| --- | --- |
| `aps-packages` | Catalogo de paquetes APS con keywords para deteccion de intencion |
| `aps-conventions` | Convenciones de organizacion, naming y archivos obligatorios |
| `aps-function-template` | Plantilla literal de archivos para Function App |
| `aps-webapp-template` | Plantilla literal de archivos para Web App |

## Estructura del repositorio

```
.
+-- .opencode/
|   +-- agents/
|   |   +-- aps-scaffolder.md
|   +-- skills/
|   |   +-- aps-packages/SKILL.md
|   |   +-- aps-conventions/SKILL.md
|   |   +-- aps-function-template/SKILL.md
|   |   +-- aps-webapp-template/SKILL.md
|   +-- commands/
|       +-- aps-onboard.md
|       +-- aps-new-function.md
|       +-- aps-new-webapp.md
|       +-- aps-add-package.md
+-- scripts/
|   +-- setup-nuget.ps1
+-- docs/
|   +-- PLAN.md                 # catalogo de demos de referencia
+-- opencode.json               # config MCP (sdk-mcp-server)
+-- README.md
+-- LICENSE
```

## Pre-requisitos para usar el template

- **.NET SDK 8.x o 10.x** — para build/run de los proyectos
- **PowerShell 7+** — para el script de setup (multiplataforma)
- **gh CLI** — para autenticacion con GitHub Packages
- **Azure Functions Core Tools** — solo si vas a crear Function Apps
  (`winget install Microsoft.AzureFunctionsCoreTools`, `brew install
  azure-functions-core-tools@4`, etc.)

## Despues de crear el repo

- [ ] (Opcional) Ejecutar `pwsh ./scripts/setup-nuget.ps1` para
      conectar con tu org de GitHub
- [ ] Abrir el repo en VS Code o Visual Studio con la extension MCP
      para usar los agents y commands
- [ ] Crear el primer proyecto con `/aps-new-function` o
      `/aps-new-webapp`
- [ ] Cuando estes listo para CI/CD, pedir al agente que cree los
      GitHub Actions (workflows de build, test, deploy)

## Configuracion MCP

Este template se beneficia del **sdk-mcp-server** de APS-Framework, que
expone las herramientas de los repos de la organizacion como tools de
IA. El `opencode.json` ya incluye el discovery por defecto.

Para que el servidor MCP funcione, seguir las instrucciones de
instalacion de [sdk-mcp-server](https://github.com/APS-Framework/sdk-mcp-server)
(una sola vez por maquina).

## Licencia

MIT
