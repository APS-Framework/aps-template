---
description: Onboarding del entorno local para un proyecto APS Framework. Detecta repo y org via gh, valida acceso al feed NuGet, configura APS_NUGET_TOKEN, detecta suscripcion de Azure si esta disponible. Accion EXPLICITA del usuario.
agent: aps-onboarder
model: minimax/MiniMax-M2.7-highspeed
---

# /aps-onboard

Onboarding del entorno local del desarrollador para trabajar con un
proyecto APS Framework. Conecta el repo con la organizacion de GitHub,
configura el feed NuGet y (opcionalmente) detecta la suscripcion de
Azure donde se desplegara.

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

1. Hace pre-checks (gh, dotnet, func, az)
2. Pregunta solo si hay ambiguedad (multi-org, suscripcion Azure, etc.)
3. Ejecuta el script `scripts/setup-nuget.ps1` con los flags apropiados
4. Interpreta la salida (prefijos [OK]/[WARN]/[ERROR]/[SKIP]/[INFO])
5. Reporta estado final con problemas pendientes y siguientes pasos

## Argumentos opcionales

Para re-ejecutar el script con flags especificos, el usuario puede
llamar directamente:

```powershell
pwsh ./scripts/setup-nuget.ps1                 # default
pwsh ./scripts/setup-nuget.ps1 -SkipAzure      # no detectar Azure
pwsh ./scripts/setup-nuget.ps1 -SkipRestore    # no ejecutar dotnet restore
pwsh ./scripts/setup-nuget.ps1 -Org MiOrg      # forzar org
pwsh ./scripts/setup-nuget.ps1 -SkipNuGetConfig # no tocar NuGet.config
```

El comando opencode no expone estos flags; el script es la API completa.

## Lo que detecta automaticamente

| Dato | Fuente | Si falta |
|------|--------|----------|
| Repo (owner, name, visibility) | `gh repo view --json ...` | El script sigue, pero no crea NuGet.config |
| Organizacion del feed | owner del repo (si es org) o parametro | Pide al usuario `-Org` |
| Acceso al feed de la org | `gh api /orgs/{org}/packages` | Avisa, continua |
| Token GitHub | `gh auth token` | Pide `gh auth login` |
| Suscripcion Azure | `az account show` (si `az` esta instalado) | Avisa, continua |
| dotnet SDK | `dotnet --version` | Avisa si no es 8.x/10.x |
| Azure Functions Core Tools | `func --version` | Avisa (solo necesario para Function Apps) |

## Verificacion manual

Tras ejecutar, el usuario puede verificar:

```powershell
# Variables de entorno
[System.Environment]::GetEnvironmentVariable("APS_NUGET_TOKEN", "User")

# Fuentes NuGet
dotnet nuget list source

# Restore de prueba
dotnet restore

# Suscripcion Azure (si aplica)
az account show
```

## Relacion con otros comandos

- **Prerrequisito** de `/aps-new-function` y `/aps-new-webapp` (la
  primera vez en una maquina nueva).
- `aps-scaffolder` lo **sugiere** al final del resumen si detecta
  que falta `APS_NUGET_TOKEN` o el restore falla por credenciales,
  pero **no** lo invoca automaticamente.
