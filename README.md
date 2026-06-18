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
| `/aps-onboard` | Onboarding del entorno local: detecta repo/org via `gh`, configura `APS_NUGET_TOKEN` y `GITHUB_TOKEN`, genera/actualiza `NuGet.config`, ajusta `opencode.json` (MCP discovery: conserva `APS-Framework:aps-framework` y anade la org del repo si es diferente) e instala el paquete `sdk-mcp-server` desde GitHub Packages si no esta presente. **Pregunta al usuario** si quiere arrancar el MCP server; avisa si hay que reiniciar opencode. No valida `dotnet`/`func`/`az` ni Azure (lo gestiona el workflow de deploy) |
| `/aps-new-function [nombre] [desc...]` | Crea una nueva Azure Function con APS |
| `/aps-new-webapp [nombre] [desc...]` | Crea una nueva ASP.NET Core Web App con APS |
| `/aps-add-package <paquete>` | Anade un paquete APS a un proyecto existente |

## Agents opencode disponibles

| Agent | Modo | Proposito | Como se invoca |
| --- | --- | --- | --- |
| `aps-onboarder` | subagent | Onboarding local: configura `gh` CLI, `NuGet.config` y `opencode.json` con la org detectada, e instala el MCP server (`@APS-Framework/sdk-mcp-server`). **Pregunta al usuario** antes de arrancar el server. **No debe invocarse directamente** | Solo via `/aps-onboard` |
| `aps-scaffolder` | subagent | Crea Functions y WebApps a partir de una descripcion. Usado por `/aps-new-function`, `/aps-new-webapp` y `/aps-add-package` | Via los commands de creacion |

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
|   |   +-- aps-onboarder.md
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
- [ ] Cuando estes listo para CI/CD, pedir al agente que cree los
      GitHub Actions (workflows de build, test, deploy). El acceso
      a Azure se configura ahi, no en local

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
