#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Onboarding del entorno local para un proyecto APS Framework.

.DESCRIPTION
    Conecta el entorno del desarrollador con la organizacion de GitHub
    a la que pertenece el repo. Su alcance es deliberadamente MINIMO:

      1. Verifica que `gh` CLI esta instalado y autenticado
      2. Detecta el repo (owner/name) y la org con `gh repo view`
      3. Anade el scope `read:packages` a la sesion gh
      4. Valida el acceso al feed de GitHub Packages de la org
      5. Configura APS_NUGET_TOKEN y GITHUB_TOKEN como variables de usuario
      6. Genera/actualiza NuGet.config con la org detectada
      7. Ajusta opencode.json para que el MCP discovery apunte a la org
      8. Instala el MCP server (paquete `@APS-Framework/sdk-mcp-server`)
         si no esta ya presente en la maquina

    NO verifica dotnet SDK, Azure Functions Core Tools, Azure CLI ni
    ejecuta `dotnet restore`. Esas validaciones corresponden a los
    agentes de creacion de proyectos (aps-scaffolder) o al flujo de
    despliegue (GitHub Actions), y se hacen bajo demanda cuando hacen
    falta.

    El acceso a Azure (CLI, suscripcion, login) **no debe necesitarse
    nunca desde el entorno local**: el workflow de deploy de GitHub
    Actions es quien gestiona las credenciales y la suscripcion de
    Azure. Si necesitas desplegar desde local, replantear el flujo.

    Pensado para ser invocado por el subagent opencode 'aps-onboarder',
    que aporta contexto, preguntas al usuario e interpretacion de
    errores. Tambien se puede ejecutar directamente en una terminal.

    Output estructurado con prefijos [OK], [WARN], [ERROR], [SKIP], [INFO]
    para que el subagent opencode pueda parsearlo facilmente.

.PARAMETER Org
    Nombre de la organizacion en GitHub. Si se omite, se detecta del repo.

.PARAMETER SkipEnvVars
    No configura las variables de entorno de usuario.

.PARAMETER SkipNuGetConfig
    No crea ni modifica NuGet.config.

.PARAMETER SkipMcp
    No ajusta opencode.json (MCP discovery).

.PARAMETER SkipFeedValidation
    No intenta validar el acceso al feed de la organizacion.

.PARAMETER Topic
    Topic del MCP discovery para la org del repo. Por defecto se usa el
    nombre del repo. Aplica solo si la org del repo es diferente de
    `APS-Framework` (en ese caso, el discovery `APS-Framework:aps-framework`
    siempre se conserva y se anade el de la org del repo).

.PARAMETER SkipMcpServer
    No instala ni actualiza el paquete npm `@APS-Framework/sdk-mcp-server`.
    Por defecto se instala si no esta presente.

.PARAMETER StartMcpServer
    Ademas de instalar el paquete (si no esta), arranca `sdk-mcp-server`
    en segundo plano tras la instalacion. Pensado para cuando el usuario
    ha consentido explicitamente arrancarlo desde el agente.
    Implica instalar (no usar junto con `-SkipMcpServer`).

.PARAMETER RepoRoot
    Ruta al repo. Si se omite, se usa el directorio actual.

.EXAMPLE
    pwsh ./scripts/setup-nuget.ps1

.EXAMPLE
    pwsh ./scripts/setup-nuget.ps1 -Org MiOrg

.EXAMPLE
    pwsh ./scripts/setup-nuget.ps1 -SkipMcp -SkipFeedValidation

.NOTES
    Requiere PowerShell 7+. Funciona en Windows, Linux y macOS.
#>
[CmdletBinding()]
param(
    [string]$Org = "",
    [switch]$SkipEnvVars,
    [switch]$SkipNuGetConfig,
    [switch]$SkipMcp,
    [switch]$SkipFeedValidation,
    [string]$Topic = "",
    [switch]$SkipMcpServer,
    [switch]$StartMcpServer,
    [string]$RepoRoot = (Get-Location).Path
)

$ErrorActionPreference = "Stop"

function Write-Step {
    param([string]$Message)
    Write-Host ""
    Write-Host "== $Message ==" -ForegroundColor Cyan
}

function Write-Ok    { param([string]$Message) Write-Host "[OK] $Message" -ForegroundColor Green }
function Write-Skip  { param([string]$Message) Write-Host "[SKIP] $Message" -ForegroundColor DarkGray }
function Write-Warn2 { param([string]$Message) Write-Host "[WARN] $Message" -ForegroundColor Yellow }
function Write-Err   { param([string]$Message) Write-Host "[ERROR] $Message" -ForegroundColor Red }
function Write-Info  { param([string]$Message) Write-Host "[INFO] $Message" -ForegroundColor Gray }

# ===========================================================================
# 1. gh CLI (unico prerequisito del onboarding general)
# ===========================================================================
Write-Step "gh CLI"

try {
    $ghVersion = (gh --version 2>&1 | Select-Object -First 1) -replace 'gh version ', ''
    Write-Ok "gh CLI $ghVersion"
} catch {
    Write-Err "gh CLI no esta instalado. Instalar desde https://cli.github.com"
    exit 1
}

$ghStatus = gh auth status 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-Err "No hay sesion activa de gh. Ejecuta: gh auth login"
    exit 1
}
Write-Ok "Sesion gh activa"

$ghUser = (gh api user --jq '.login' 2>&1) -replace "`r`n", ''
if ($LASTEXITCODE -eq 0 -and -not [string]::IsNullOrWhiteSpace($ghUser)) {
    Write-Info "Usuario GitHub: $ghUser"
} else {
    Write-Warn2 "No se pudo obtener el usuario de GitHub"
}

# ===========================================================================
# 2. Contexto de GitHub (repo, org)
# ===========================================================================
Write-Step "Contexto de GitHub"

$repoJson = gh repo view --json owner,name,isInOrganization,visibility,defaultBranchRef,url 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-Err "No se detecta un repo de GitHub en el directorio actual."
    Write-Info "  El onboarding solo funciona dentro de un repo clonado con gh."
    exit 1
}

try {
    $repo = $repoJson | ConvertFrom-Json
    $repoOwner = $repo.owner.login
    $repoName = $repo.name
    $isOrg = $repo.isInOrganization
    $visibility = $repo.visibility
    $url = $repo.url

    Write-Ok "Repo: $repoOwner/$repoName ($visibility)"
    Write-Info "  $url"

    # Determinar la org: si es repo de organizacion, es esa; si es personal, es el owner
    if (-not [string]::IsNullOrWhiteSpace($Org)) {
        Write-Info "Org proporcionada por parametro: $Org (override)"
    } elseif ($isOrg) {
        $Org = $repoOwner
        Write-Ok "Organizacion (repo pertenece a org): $Org"
    } else {
        $Org = $repoOwner
        Write-Info "Repo personal. Owner usado como org: $Org"
    }
} catch {
    Write-Err "No se pudo parsear la salida de 'gh repo view': $_"
    exit 1
}

if ([string]::IsNullOrWhiteSpace($Org)) {
    Write-Err "No se detecto organizacion. Usar -Org <nombre>."
    exit 1
}

# ===========================================================================
# 3. Scope read:packages
# ===========================================================================
Write-Step "Scope read:packages"

$refreshOutput = gh auth refresh --scopes "read:packages" 2>&1 | Out-String
if ($LASTEXITCODE -ne 0) {
    Write-Warn2 "No se pudo refrescar el scope. Si ya esta incluido, ignorar."
} else {
    Write-Ok "scope read:packages confirmado"
}

# ===========================================================================
# 4. Validacion de acceso al feed de la organizacion
# ===========================================================================
if ($SkipFeedValidation) {
    Write-Skip "Validacion de feed omitida (-SkipFeedValidation)"
} else {
    Write-Step "Validando acceso al feed de $Org"

    $headersJson = gh api /user/packages --include 2>&1 | Out-String
    if ($LASTEXITCODE -eq 0) {
        $orgPackages = gh api "/orgs/$Org/packages?package_type=nuget" 2>&1 | Out-String
        if ($LASTEXITCODE -eq 0) {
            Write-Ok "Acceso verificado al feed NuGet de $Org"
        } elseif ($orgPackages -match '404') {
            Write-Info "La org $Org no expone un feed NuGet accesible (404). Continuo igualmente."
        } elseif ($orgPackages -match '403') {
            Write-Warn2 "403 al acceder a /orgs/$Org/packages. Token sin permisos sobre esta org."
            Write-Info "  Verifica que tu cuenta pertenece a $Org con acceso a Packages."
        } else {
            Write-Warn2 "No se pudo validar el feed: $orgPackages"
        }
    } else {
        Write-Warn2 "No se pudo consultar /user/packages. Token posiblemente invalido."
    }
}

# ===========================================================================
# 5. Variables de entorno
# ===========================================================================
if (-not $SkipEnvVars) {
    Write-Step "Variables de entorno de usuario"

    $token = gh auth token
    if ([string]::IsNullOrWhiteSpace($token)) {
        Write-Err "No se pudo obtener el token de gh"
        exit 1
    }

    [System.Environment]::SetEnvironmentVariable("APS_NUGET_TOKEN", $token, "User")
    Write-Ok "APS_NUGET_TOKEN actualizado en variables de usuario"

    [System.Environment]::SetEnvironmentVariable("GITHUB_TOKEN", $token, "User")
    Write-Ok "GITHUB_TOKEN actualizado en variables de usuario"

    Write-Info "Abre una nueva terminal para que las variables esten disponibles en la sesion actual."

    # Hacer visibles para procesos hijos (e.g. el restore lo hara el scaffolder)
    $env:APS_NUGET_TOKEN = $token
    $env:GITHUB_TOKEN = $token
} else {
    Write-Skip "Configuracion de variables omitida (-SkipEnvVars)"
}

# ===========================================================================
# 6. NuGet.config
# ===========================================================================
if (-not $SkipNuGetConfig) {
    Write-Step "NuGet.config"

    $nugetConfigPath = Join-Path $RepoRoot "NuGet.config"

    $feedUrl = "https://nuget.pkg.github.com/$Org/index.json"
    $content = @"
<?xml version="1.0" encoding="utf-8"?>
<configuration>
  <packageSources>
    <clear />
    <add key="nuget.org" value="https://api.nuget.org/v3/index.json" protocolVersion="3" />
    <add key="$Org" value="$feedUrl" />
  </packageSources>
  <packageSourceCredentials>
    <$Org>
      <add key="Username" value="x" />
      <add key="ClearTextPassword" value="%APS_NUGET_TOKEN%" />
    </$Org>
  </packageSourceCredentials>
</configuration>
"@

    if (Test-Path $nugetConfigPath) {
        $existing = Get-Content $nugetConfigPath -Raw
        if ($existing -eq $content) {
            Write-Skip "NuGet.config ya coincide con la org $Org (sin cambios)"
        } else {
            $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
            [System.IO.File]::WriteAllText($nugetConfigPath, $content, $utf8NoBom)
            Write-Ok "NuGet.config sobrescrito en $nugetConfigPath"
        }
    } else {
        $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
        [System.IO.File]::WriteAllText($nugetConfigPath, $content, $utf8NoBom)
        Write-Ok "NuGet.config creado en $nugetConfigPath"
    }
    Write-Info "  Feed privado: $feedUrl"
} else {
    Write-Skip "Creacion/actualizacion de NuGet.config omitida (-SkipNuGetConfig)"
}

# ===========================================================================
# 7. opencode.json (MCP discovery)
# ===========================================================================
if ($SkipMcp) {
    Write-Skip "Ajuste de opencode.json omitido (-SkipMcp)"
} else {
    Write-Step "opencode.json (MCP)"

    $opencodePath = Join-Path $RepoRoot "opencode.json"
    if (-not (Test-Path $opencodePath)) {
        Write-Warn2 "opencode.json no existe en $RepoRoot. Saltando ajuste de MCP."
    } else {
        try {
            $opencode = Get-Content $opencodePath -Raw | ConvertFrom-Json
            $mcp = $opencode.mcp
            if (-not $mcp) {
                Write-Skip "opencode.json no tiene bloque 'mcp'. Sin cambios."
            } else {
                $changed = $false
                foreach ($mcpName in @($mcp.PSObject.Properties.Name)) {
                    $entry = $mcp.$mcpName
                    if ($entry.type -ne 'remote' -or [string]::IsNullOrWhiteSpace($entry.url)) { continue }

                    $uri = [Uri]$entry.url
                    $query = [System.Web.HttpUtility]::ParseQueryString($uri.Query)

                    # Preservar parametros que no son discovery (e.g. exclude, ...).
                    $preserved = @{}
                    foreach ($k in @($query.Keys)) {
                        if ($k -ne 'discovery') {
                            $preserved[$k] = @($query[$k])
                        }
                    }

                    # Conservar `APS-Framework:aps-framework` si ya estaba presente.
                    # Es el namespace canonico del framework APS y debe estar siempre disponible.
                    $apsFrameworkDiscovery = $null
                    foreach ($d in @($query.GetValues('discovery'))) {
                        if ($d -eq 'APS-Framework:aps-framework') {
                            $apsFrameworkDiscovery = $d
                            break
                        }
                    }

                    # Construir la lista final de discovery:
                    #  1) `APS-Framework:aps-framework` si estaba en el URL original.
                    #  2) La org del repo, solo si es diferente de `APS-Framework`.
                    $newDiscoveries = @()
                    if ($apsFrameworkDiscovery) {
                        $newDiscoveries += $apsFrameworkDiscovery
                    }
                    if ($Org -ne 'APS-Framework') {
                        $effectiveTopic = if (-not [string]::IsNullOrWhiteSpace($Topic)) { $Topic } else { $repoName }
                        $newDiscoveries += "$Org`:$effectiveTopic"
                    }

                    # Quitar TODOS los discovery= previos y re-anadir solo los finales.
                    $query.Remove('discovery')
                    foreach ($d in $newDiscoveries) {
                        $query.Add('discovery', $d)
                    }

                    # Reconstruir query string preservando orden: discovery primero, luego el resto.
                    # Sin UrlEncode para no escapar ':' y '/', como en el URL original.
                    $pairs = @()
                    foreach ($d in $newDiscoveries) {
                        $pairs += "discovery=$d"
                    }
                    foreach ($k in $preserved.Keys) {
                        foreach ($v in $preserved[$k]) {
                            $pairs += "$k=$v"
                        }
                    }
                    $newQuery = ($pairs -join '&')
                    $newUrl = "{0}://{1}{2}{3}" -f $uri.Scheme, $uri.Authority, $uri.AbsolutePath, ($(if ($newQuery) { "?" + $newQuery } else { '' }))

                    if ($newUrl -ne $entry.url) {
                        $entry.url = $newUrl
                        $changed = $true
                        $discList = ($newDiscoveries -join ', ')
                        Write-Ok "MCP '$mcpName': discovery ajustado a: $discList"
                    } else {
                        Write-Skip "MCP '$mcpName': discovery ya correcto"
                    }
                }

                                if ($changed) {
                                    $json = $opencode | ConvertTo-Json -Depth 10
                                    $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
                                    [System.IO.File]::WriteAllText($opencodePath, $json, $utf8NoBom)
                                    Write-Ok "opencode.json actualizado en $opencodePath"
                                    Write-Warn2 "ATENCION: si tienes opencode en otra terminal, REINICIALO para que el nuevo MCP discovery tenga efecto."
                                }
            }
        } catch {
            Write-Warn2 "No se pudo ajustar opencode.json: $_"
        }
    }
}

# ===========================================================================
# 8. MCP server (paquete @APS-Framework/sdk-mcp-server)
# ===========================================================================
# El binario `sdk-mcp-server` viene del feed npm de APS-Framework en
# GitHub Packages. Sin el, el MCP discovery configurado arriba no
# tiene efecto. Lo instalamos globalmente si no esta presente.
if ($SkipMcpServer) {
    Write-Skip "Instalacion del MCP server omitida (-SkipMcpServer)"
} else {
    Write-Step "MCP server (sdk-mcp-server)"

    $mcpCmd = Get-Command sdk-mcp-server -ErrorAction SilentlyContinue
    $installSucceeded = $false

    if ($mcpCmd) {
        Write-Ok "sdk-mcp-server ya instalado en $($mcpCmd.Source)"
        $installSucceeded = $true
    } else {
        # Comprobar Node.js (prerequisite del paquete)
        $nodeCmd = Get-Command node -ErrorAction SilentlyContinue
        $npmCmd  = Get-Command npm  -ErrorAction SilentlyContinue
        if (-not $nodeCmd) {
            Write-Warn2 "Node.js no esta instalado. No se puede instalar sdk-mcp-server."
            Write-Info "  Instala Node.js >= 18 desde https://nodejs.org y vuelve a correr este script."
        } elseif (-not $npmCmd) {
            Write-Warn2 "npm no esta disponible. No se puede instalar sdk-mcp-server."
        } else {
            $nodeVersion = (node --version 2>&1) -replace '^v', ''
            $nodeMajor = 0
            if ($nodeVersion -match '^(\d+)\.') { $nodeMajor = [int]$Matches[1] }
            if ($nodeMajor -lt 18) {
                Write-Warn2 "Node.js $nodeVersion detectado, se requiere >= 18 para sdk-mcp-server."
                Write-Info "  Actualiza Node.js desde https://nodejs.org y vuelve a correr este script."
            } else {
                Write-Info "Node.js $nodeVersion, npm disponible"
                Write-Info "Instalando paquete @APS-Framework/sdk-mcp-server desde GitHub Packages..."

                $token = gh auth token 2>&1
                if ([string]::IsNullOrWhiteSpace($token)) {
                    Write-Warn2 "No se pudo obtener el token de gh. No se puede instalar sdk-mcp-server."
                } else {
                    # .npmrc temporal para autenticar contra GitHub Packages sin
                    # tocar la configuracion global del usuario.
                    $rc = Join-Path $env:TEMP "npmrc-aps-bootstrap.txt"
                    $npmrcContent = @"
@aps-framework:registry=https://npm.pkg.github.com
//npm.pkg.github.com/:_authToken=$token
always-auth=true
"@
                    try {
                        Set-Content -Path $rc -Value $npmrcContent -NoNewline
                        $env:NPM_CONFIG_USERCONFIG = $rc
                        $output = npm install -g @APS-Framework/sdk-mcp-server 2>&1
                        if ($LASTEXITCODE -eq 0) {
                            $installed = Get-Command sdk-mcp-server -ErrorAction SilentlyContinue
                            if ($installed) {
                                Write-Ok "sdk-mcp-server instalado en $($installed.Source)"
                                $installSucceeded = $true
                            } else {
                                Write-Warn2 "npm finalizo OK pero sdk-mcp-server no esta en PATH."
                                Write-Info "  Reinicia esta terminal para que se propague el PATH antes de continuar."
                            }
                        } else {
                            Write-Warn2 "La instalacion de sdk-mcp-server fallo. Salida de npm:"
                            $output | ForEach-Object { Write-Host "    $_" -ForegroundColor DarkYellow }
                        }
                    } finally {
                        Remove-Item -Path $rc -Force -ErrorAction SilentlyContinue
                    }
                }
            }
        }
    }

    # Si el usuario consintio arrancar (flag -StartMcpServer), hacerlo ahora.
    if ($StartMcpServer) {
        if (-not $installSucceeded) {
            Write-Warn2 "No se puede arrancar sdk-mcp-server: la instalacion fallo o no se realizo."
        } else {
            # Refrescar el lookup por si PATH se actualizo en esta misma sesion.
            $mcpCmd = Get-Command sdk-mcp-server -ErrorAction SilentlyContinue
            if (-not $mcpCmd) {
                Write-Warn2 "sdk-mcp-server esta instalado pero no se encuentra en el PATH actual."
                Write-Info "  Cierra y abre una nueva terminal, luego ejecuta: sdk-mcp-server"
            } else {
                Write-Info "Arrancando sdk-mcp-server en segundo plano..."
                try {
                    $outLog = Join-Path $env:TEMP "sdk-mcp-server.out.log"
                    $errLog = Join-Path $env:TEMP "sdk-mcp-server.err.log"
                    if (-not (Test-Path $outLog)) { New-Item -ItemType File -Path $outLog -Force | Out-Null }
                    if (-not (Test-Path $errLog)) { New-Item -ItemType File -Path $errLog -Force | Out-Null }
                    $proc = Start-Process -FilePath "sdk-mcp-server" -PassThru -RedirectStandardOutput $outLog -RedirectStandardError $errLog
                    if ($proc -and $proc.Id) {
                        Write-Ok "sdk-mcp-server arrancado en segundo plano (PID $($proc.Id))"
                        Write-Info "  Logs: $outLog / $errLog"
                        Write-Warn2 "ATENCION: si tienes opencode en otra terminal, REINICIALO para que se conecte al server."
                    } else {
                        Write-Warn2 "No se pudo arrancar sdk-mcp-server (no se obtuvo PID)."
                    }
                } catch {
                    Write-Warn2 "Error arrancando sdk-mcp-server: $_"
                }
            }
        }
    }

    # Informar de la config de usuario (Paso 2 de la guia MCP)
    $userMcpConfig = Join-Path $env:USERPROFILE ".mcp.json"
    if (Test-Path $userMcpConfig) {
        Write-Info "Config MCP de usuario existente: $userMcpConfig (no se modifica)"
    } else {
        Write-Info "No existe $userMcpConfig. Creala manualmente si quieres una config MCP de usuario."
        Write-Info "  Plantilla:"
        Write-Info '  { "servers": { "aps": { "type": "http", "url": "http://127.0.0.1:7512/mcp?discovery=APS-Framework:aps-framework" } } }'
    }
}

# ===========================================================================
# Resumen final (output compacto para que el agent lo procese)
# ===========================================================================
Write-Step "Onboarding completado"
Write-Host ""
Write-Host "Resumen:" -ForegroundColor Green
Write-Host "  Repo:              $repoOwner/$repoName ($visibility)"
Write-Host "  Org detectada:     $Org"
Write-Host "  Feed NuGet:        https://nuget.pkg.github.com/$Org/index.json"
Write-Host "  Token GitHub:      $(if (gh auth token 2>$null) { 'configurado (APS_NUGET_TOKEN)' } else { 'NO configurado' })"
Write-Host "  NuGet.config:      $(if (Test-Path (Join-Path $RepoRoot 'NuGet.config')) { 'generado' } else { 'no generado' })"
Write-Host "  opencode.json:     $(if ($SkipMcp) { 'no modificado' } else { 'ajustado' })"
$mcpStatus = if ($SkipMcpServer) { 'no verificado' } elseif (Get-Command sdk-mcp-server -ErrorAction SilentlyContinue) { 'instalado' } else { 'NO instalado' }
Write-Host "  MCP server:        $mcpStatus"
Write-Host "  MCP server run:    $(if ($StartMcpServer) { 'intentado en background' } else { 'no solicitado' })"

# Avisos prominentes al final (que el agente pueda parsear facilmente)
Write-Host ""
Write-Host "Avisos de reinicio:" -ForegroundColor Yellow
$needsTerminalRestart = $false
$needsOpencodeRestart = $false
# Si se instalo el MCP server en esta misma sesion, el binario estara
# en PATH para este proceso pero otras terminales no lo veran hasta
# que abran una nueva (o recarguen el perfil).
if ($installSucceeded -and -not $mcpCmd) {
    $needsTerminalRestart = $true
}
if (-not $SkipMcp) {
    # opencode.json fue ajustado en este run, hace falta reiniciar opencode
    $needsOpencodeRestart = $true
}
if ($StartMcpServer) {
    # Si arrancamos el server, opencode debe reconectarse
    $needsOpencodeRestart = $true
}
if ($needsTerminalRestart) {
    Write-Host "  - Abre una NUEVA terminal para que el PATH con sdk-mcp-server se propague." -ForegroundColor Yellow
}
if ($needsOpencodeRestart) {
    Write-Host "  - REINICIA opencode (Ctrl+C y vuelve a abrir) para que aplique el MCP discovery y/o se conecte al server." -ForegroundColor Yellow
}
if (-not $needsTerminalRestart -and -not $needsOpencodeRestart) {
    Write-Host "  (ninguno)" -ForegroundColor Gray
}

Write-Host ""
Write-Host "Siguientes pasos:" -ForegroundColor Green
Write-Host "  1. Abre una nueva terminal para que APS_NUGET_TOKEN este disponible"
Write-Host "  2. Verifica: dotnet nuget list source"
if ($StartMcpServer) {
    Write-Host "  3. El MCP server ya esta corriendo (PID en el resumen)"
} else {
    Write-Host "  3. Si vas a usar el MCP ahora: ejecuta 'sdk-mcp-server' (o 'pm2 start sdk-mcp-server')"
}
Write-Host "  4. REINICIA opencode para aplicar cambios (Ctrl+C y reabrir)"
Write-Host "  5. Antes de crear un proyecto, asegurate de tener dotnet 8.x/10.x instalado"
Write-Host "  6. Crea tu primera Function:  /aps-new-function MiFunction"
Write-Host "  7. Crea tu primera Web App:   /aps-new-webapp MiApi"
