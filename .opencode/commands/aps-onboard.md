---
description: Onboarding del entorno local para un proyecto APS Framework. Verifica acceso a gh CLI, detecta el repo y la org via 'gh repo view', configura APS_NUGET_TOKEN y GITHUB_TOKEN como variables de usuario, genera/actualiza NuGet.config, ajusta opencode.json (MCP discovery: conserva APS-Framework:aps-framework y anade la org del repo si es diferente), instala el paquete sdk-mcp-server si no esta presente y pregunta al usuario antes de arrancarlo. Accion EXPLICITA del usuario.
agent: aps-onboarder
# El modelo se hereda del agent (aps-onboarder usa MiniMax-M2.7-highspeed
# por coste/velocidad). No se especifica aqui para evitar duplicacion.
---

# /aps-onboard

Onboarding del entorno local del desarrollador para trabajar con un
proyecto APS Framework. Conecta el repo con la organizacion de GitHub
y prepara el MCP server para usar las tools de APS Framework.

**Alcance limitado**: este comando verifica acceso a `gh` CLI,
configura `NuGet.config` + `opencode.json` en base a la org del repo,
e instala el paquete `sdk-mcp-server` (si no esta presente y el
usuario lo consiente). NO verifica `dotnet`, `func` ni `az` — eso lo
hacen los agentes encargados de crear proyectos (`aps-scaffolder`) o
el workflow de despliegue de GitHub Actions, bajo demanda.

**Pregunta al usuario** antes de arrancar el MCP server. Si el
usuario consiente, el script lo arranca en background; si no, el
usuario puede arrancarlo despues con `sdk-mcp-server` o `pm2 start`.

Tampoco **autentica contra Azure**: el acceso a Azure desde local
nunca debe ser necesario. Las credenciales y la suscripcion las
gestiona el workflow de deploy (ver `/aps-new-workflow`, que genera
callers a los workflows reutilizables de `APS-Framework/.github`).

## Cuando usarlo

- Primera vez que se clona un repo desde el template APS
- Al cambiar de maquina o de organizacion de GitHub
- Despues de renovar la sesion de `gh auth` y perder scopes
- Cuando `dotnet restore` falla con 401/403 contra feeds privados
- Cuando el agente `aps-scaffolder` reporta que el entorno no esta listo

**Importante**: este comando es SIEMPRE invocado explicitamente por el
usuario. Ningun agente opencode debe auto-ejecutarlo. Conectar el repo
con una organizacion es una decision del desarrollador.

## Procedimiento

Delega en el subagent `aps-onboarder`, que:

1. Hace pre-checks de `gh` (CLI instalada y autenticada)
2. Pregunta solo si hay ambiguedad (multi-org, saltar MCP, etc.)
3. Ejecuta el script `scripts/setup-nuget.ps1` con los flags apropiados
4. Interpreta la salida (prefijos [OK]/[WARN]/[ERROR]/[SKIP]/[INFO])
5. Reporta estado final con problemas pendientes y siguientes pasos

## Argumentos opcionales

Para re-ejecutar el script con flags especificos, el usuario puede
llamar directamente:

```powershell
pwsh ./scripts/setup-nuget.ps1                     # default (instala MCP si falta, no lo arranca)
pwsh ./scripts/setup-nuget.ps1 -Org MiOrg          # forzar org
pwsh ./scripts/setup-nuget.ps1 -Topic MiTopic      # topic del MCP para la org del repo (si != APS-Framework)
pwsh ./scripts/setup-nuget.ps1 -SkipMcp            # no ajustar opencode.json
pwsh ./scripts/setup-nuget.ps1 -SkipMcpServer      # no instalar el paquete del MCP server
pwsh ./scripts/setup-nuget.ps1 -StartMcpServer     # ademas de instalar, arrancar sdk-mcp-server en background
pwsh ./scripts/setup-nuget.ps1 -SkipNuGetConfig    # no tocar NuGet.config
pwsh ./scripts/setup-nuget.ps1 -SkipEnvVars        # no setear variables de usuario
pwsh ./scripts/setup-nuget.ps1 -SkipFeedValidation # no validar acceso al feed
```

El comando opencode no expone estos flags; el script es la API completa.

## Lo que configura el onboarding

| Recurso | Que hace | Si falta |
|---------|----------|----------|
| `gh` CLI (sesion activa) | Verifica `gh auth status` | Aborta: pedir `gh auth login` |
| `gh` scope `read:packages` | `gh auth refresh --scopes` | Avisa, continua |
| Repo y org | `gh repo view --json ...` | Aborta: pedir org con `-Org` |
| Acceso al feed de la org | `gh api /orgs/{org}/packages` | Avisa, continua |
| `APS_NUGET_TOKEN` (user env) | `SetEnvironmentVariable` | Bloqueante: no se puede restaurar |
| `GITHUB_TOKEN` (user env) | `SetEnvironmentVariable` | Bloqueante |
| `NuGet.config` (raiz del repo) | Sobrescribe con la org detectada | Lo crea si no existe |
| `opencode.json` (MCP discovery) | Conserva `APS-Framework:aps-framework` y, si la org del repo es diferente, anade `discovery={Org}:{topic}` (topic por defecto = nombre del repo) | Avisa si no existe |
| MCP server (`@APS-Framework/sdk-mcp-server`) | Instala el paquete npm global si no esta presente (requiere Node.js >= 18). Si el usuario consiente con `-StartMcpServer`, tambien lo arranca en background | Avisa, no aborta; el usuario puede arrancarlo luego con `sdk-mcp-server` o PM2 |

## Lo que NO hace el onboarding (es trabajo de otros agentes)

| Recurso | Quien lo verifica | Cuando |
|---------|-------------------|--------|
| `dotnet` SDK 8.x / 10.x | `aps-scaffolder` | Al crear proyecto |
| `func` (Azure Functions Core Tools) | `aps-scaffolder` | Solo para Function Apps |
| `az` CLI y suscripcion | workflow de deploy (GitHub Actions, ver `/aps-new-workflow`) | Al desplegar a Azure |
| `dotnet restore` de prueba | `aps-scaffolder` | Al crear proyecto |

## Verificacion manual

Tras ejecutar, el usuario puede verificar:

```powershell
# Variables de entorno
[System.Environment]::GetEnvironmentVariable("APS_NUGET_TOKEN", "User")

# Fuentes NuGet
dotnet nuget list source

# MCP discovery
Get-Content opencode.json | Select-String "discovery="

# MCP server instalado
Get-Command sdk-mcp-server

# MCP server corriendo (puerto 7512 en uso)
Get-NetTCPConnection -LocalPort 7512 -State Listen
```

Para validar que el restore funciona (despues de tener dotnet
instalado):

```powershell
# Crear un proyecto de prueba y restaurar
/aps-new-function SmokeTest "function smoke que solo hace log"
```

Para arrancar el MCP server manualmente (si no se uso `-StartMcpServer`):

```powershell
# Opcion A: solo esta sesion (dejar terminal abierta)
sdk-mcp-server

# Opcion B: automatico con PM2 (recomendado)
pm2 start "sdk-mcp-server" --name aps-mcp
pm2 save
```

## Aviso importante: reinicio de opencode

Si el script avisa al final de que hay que **reiniciar opencode**, es
porque:

- Se actualizo `opencode.json` (discovery MCP nuevo) y/o
- Se instalo el MCP server y/o
- Se arranco el MCP server

Hasta que reinicies opencode (Ctrl+C y reabrir), el MCP discovery
nuevo no se aplica y opencode no se conectara al server (si lo
arrancaste). Reiniciar es **manual** y el agente opencode **no lo
hara por ti**.

## Relacion con otros comandos

- **Prerrequisito** de `/aps-new-function` y `/aps-new-webapp` (la
  primera vez en una maquina nueva): `aps-scaffolder` necesita
  `APS_NUGET_TOKEN` y un `NuGet.config` correcto para poder restaurar
  paquetes APS.
- `aps-scaffolder` **sugiere** ejecutar `/aps-onboard` al final del
  resumen si detecta que falta `APS_NUGET_TOKEN` o el restore falla
  por credenciales, pero **no** lo invoca automaticamente.
