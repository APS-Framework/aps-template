#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Onboarding del entorno local para un proyecto APS Framework.

.DESCRIPTION
    Detecta el contexto (repo, org, suscripcion Azure) y configura el
    entorno para consumir paquetes APS desde GitHub Packages.

    Pensado para ser invocado por el subagent opencode 'aps-onboarder',
    que aporta contexto, preguntas al usuario e interpretacion de errores.
    Tambien se puede ejecutar directamente en una terminal.

    Pasos:
      1. Verifica prerequisitos (gh CLI, dotnet SDK, sesion gh activa)
      2. Detecta el repo con 'gh repo view' (org, nombre, visibilidad)
      3. Anade el scope 'read:packages' a la sesion gh
      4. Valida acceso al feed de paquetes de la organizacion
      5. Configura APS_NUGET_TOKEN y GITHUB_TOKEN como variables de usuario
      6. Detecta suscripcion de Azure si 'az' CLI esta disponible
      7. Crea NuGet.config en la raiz del repo si no existe
      8. Valida la configuracion ejecutando 'dotnet restore'

    Output estructurado con prefijos [OK], [WARN], [ERROR], [SKIP], [INFO]
    para que el subagent opencode pueda parsearlo facilmente.

.PARAMETER Org
    Nombre de la organizacion en GitHub. Si se omite, se detecta del repo.

.PARAMETER SkipEnvVars
    No configura las variables de entorno de usuario.

.PARAMETER SkipNuGetConfig
    No crea ni modifica NuGet.config.

.PARAMETER SkipRestore
    No ejecuta 'dotnet restore' al final.

.PARAMETER SkipAzure
    No detecta la suscripcion de Azure aunque 'az' este disponible.

.EXAMPLE
    pwsh ./scripts/setup-nuget.ps1

.EXAMPLE
    pwsh ./scripts/setup-nuget.ps1 -Org APS-Framework -SkipAzure

.NOTES
    Requiere PowerShell 7+. Funciona en Windows, Linux y macOS.
#>
[CmdletBinding()]
param(
    [string]$Org = "",
    [switch]$SkipEnvVars,
    [switch]$SkipNuGetConfig,
    [switch]$SkipRestore,
    [switch]$SkipAzure
)

$ErrorActionPreference = "Stop"

function Write-Step {
    param([string]$Message)
    Write-Host ""
    Write-Host "== $Message ==" -ForegroundColor Cyan
}

function Write-Ok      { param([string]$Message) Write-Host "[OK] $Message" -ForegroundColor Green }
function Write-Skip    { param([string]$Message) Write-Host "[SKIP] $Message" -ForegroundColor DarkGray }
function Write-Warn2   { param([string]$Message) Write-Host "[WARN] $Message" -ForegroundColor Yellow }
function Write-Err     { param([string]$Message) Write-Host "[ERROR] $Message" -ForegroundColor Red }
function Write-Info    { param([string]$Message) Write-Host "[INFO] $Message" -ForegroundColor Gray }

# ===========================================================================
# 1. Prerequisitos
# ===========================================================================
Write-Step "Prerequisitos"

try {
    $ghVersion = (gh --version 2>&1 | Select-Object -First 1) -replace 'gh version ', ''
    Write-Ok "gh CLI $ghVersion"
} catch {
    Write-Err "gh CLI no esta instalado. Instalar desde https://cli.github.com"
    exit 1
}

try {
    $dotnetVersion = (& dotnet --version 2>&1) -replace "`r`n", ''
    if ($dotnetVersion -notmatch '^[89]\.|^10\.') {
        Write-Warn2 "dotnet SDK $dotnetVersion. Recomendado: 8.x o 10.x"
    } else {
        Write-Ok "dotnet SDK $dotnetVersion"
    }
} catch {
    Write-Err "dotnet SDK no esta instalado. Instalar desde https://dotnet.microsoft.com/download"
    exit 1
}

# Func tools (opcional pero habitual en proyectos APS)
try {
    $funcVersion = (func --version 2>&1 | Select-Object -First 1) -replace "`r`n", ''
    Write-Ok "Azure Functions Core Tools $funcVersion"
} catch {
    Write-Skip "Azure Functions Core Tools no detectado (solo necesario si vas a crear Function Apps)"
}

# ===========================================================================
# 2. Contexto de GitHub (repo, org, usuario)
# ===========================================================================
Write-Step "Contexto de GitHub"

$ghStatus = gh auth status 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-Err "No hay sesion activa de gh. Ejecuta: gh auth login"
    exit 1
}

$ghUser = (gh api user --jq '.login' 2>&1) -replace "`r`n", ''
if ($LASTEXITCODE -eq 0 -and -not [string]::IsNullOrWhiteSpace($ghUser)) {
    Write-Ok "Usuario GitHub: $ghUser"
} else {
    Write-Warn2 "No se pudo obtener el usuario de GitHub"
}

# Detectar repo via 'gh repo view' (mas robusto que parsear git remote)
$repoJson = gh repo view --json owner,name,isInOrganization,visibility,defaultBranchRef,url 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-Warn2 "No se detecto un repo de GitHub en el directorio actual"
    Write-Info "  (esperado si se ejecuta fuera de un repo clonado)"
} else {
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
        Write-Warn2 "No se pudo parsear la salida de 'gh repo view': $_"
    }
}

# Override manual si no se detecto org
if ([string]::IsNullOrWhiteSpace($Org)) {
    if ($args -and $args[0]) {
        $Org = $args[0]
        Write-Info "Org usada de argumento posicional: $Org"
    } else {
        Write-Warn2 "No se detecto organizacion. Usar -Org <nombre> o ejecutar dentro de un repo clonado."
    }
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
if (-not [string]::IsNullOrWhiteSpace($Org)) {
    Write-Step "Validando acceso al feed de $Org"

    $headersJson = gh api /user/packages --include 2>&1 | Out-String
    if ($LASTEXITCODE -eq 0) {
        # gh api /user/packages no falla por 401 si el token es valido,
        # pero no da info sobre la org. Probamos con /orgs/{org}/packages.
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
} else {
    Write-Skip "Validacion de feed omitida (sin org)"
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

    # Hacer visibles para el restore de este proceso
    $env:APS_NUGET_TOKEN = $token
    $env:GITHUB_TOKEN = $token
} else {
    Write-Skip "Configuracion de variables omitida (-SkipEnvVars)"
}

# ===========================================================================
# 6. Deteccion de Azure (opcional, solo si 'az' esta disponible)
# ===========================================================================
if (-not $SkipAzure) {
    Write-Step "Suscripcion de Azure"

    try {
        $azVersion = (az --version 2>&1 | Select-Object -First 1) -replace "`r`n", ''
        Write-Ok "Azure CLI detectado: $azVersion"

        $accountJson = az account show 2>&1 | Out-String
        if ($LASTEXITCODE -eq 0) {
            try {
                $account = $accountJson | ConvertFrom-Json
                $subId = $account.id
                $subName = $account.name
                $tenantId = $account.tenantId
                $userName = $account.user.name

                Write-Ok "Suscripcion activa: $subName ($subId)"
                Write-Info "  Tenant: $tenantId"
                Write-Info "  Usuario: $userName"
            } catch {
                Write-Warn2 "No se pudo parsear la salida de 'az account show': $_"
            }
        } else {
            Write-Warn2 "'az' instalado pero no autenticado. Ejecuta: az login"
        }
    } catch {
        Write-Skip "Azure CLI no instalado. Si no vas a desplegar a Azure, puedes ignorar este aviso."
    }
} else {
    Write-Skip "Deteccion de Azure omitida (-SkipAzure)"
}

# ===========================================================================
# 7. NuGet.config
# ===========================================================================
if (-not $SkipNuGetConfig) {
    Write-Step "NuGet.config"

    $nugetConfigPath = Join-Path (Get-Location) "NuGet.config"

    if (Test-Path $nugetConfigPath) {
        Write-Skip "NuGet.config ya existe en $nugetConfigPath (no se modifica)"
    } elseif ([string]::IsNullOrWhiteSpace($Org)) {
        Write-Warn2 "No se puede crear NuGet.config sin organizacion. Pasa -Org."
    } else {
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
        $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
        [System.IO.File]::WriteAllText($nugetConfigPath, $content, $utf8NoBom)
        Write-Ok "NuGet.config creado en $nugetConfigPath"
        Write-Info "  Feed privado: $feedUrl"
    }
} else {
    Write-Skip "Creacion de NuGet.config omitida (-SkipNuGetConfig)"
}

# ===========================================================================
# 8. Validacion con dotnet restore
# ===========================================================================
if (-not $SkipRestore) {
    Write-Step "Validacion con dotnet restore"

    $csprojFiles = Get-ChildItem -Path . -Recurse -Filter "*.csproj" -ErrorAction SilentlyContinue
    if (-not $csprojFiles -or $csprojFiles.Count -eq 0) {
        Write-Skip "No hay .csproj en el repo todavia (esperado en primer setup)"
    } else {
        $restoreOutput = dotnet restore 2>&1 | Out-String
        if ($LASTEXITCODE -ne 0) {
            Write-Warn2 "dotnet restore finalizo con errores:"
            Write-Host $restoreOutput
            Write-Host ""
            Write-Host "Diagnostico:" -ForegroundColor Yellow
            Write-Host "  401/403            Token sin scope 'read:packages' o sin acceso a la org"
            Write-Host "  NU1101 (paquete)   El paquete/ version no existe en el feed"
            Write-Host "  Conexion           Verifica que la URL del feed es correcta (https://nuget.pkg.github.com/$Org/index.json)"
        } else {
            Write-Ok "dotnet restore OK"
        }
    }
} else {
    Write-Skip "dotnet restore omitido (-SkipRestore)"
}

# ===========================================================================
# Resumen final (output compacto para que el agent lo procese)
# ===========================================================================
Write-Step "Onboarding completado"
Write-Host ""
Write-Host "Resumen:" -ForegroundColor Green
Write-Host "  Org detectada:  $($Org ?? '(ninguna)')"
Write-Host "  Feed NuGet:     $(if ($Org) { "https://nuget.pkg.github.com/$Org/index.json" } else { '(no configurado)' })"
Write-Host "  Token GitHub:   $(if (gh auth token 2>$null) { 'configurado (APS_NUGET_TOKEN)' } else { 'NO configurado' })"
Write-Host "  Azure CLI:      $(if (Get-Command az -ErrorAction SilentlyContinue) { 'disponible' } else { 'no instalado' })"

Write-Host ""
Write-Host "Siguientes pasos:" -ForegroundColor Green
Write-Host "  1. Abre una nueva terminal para que las variables esten disponibles"
Write-Host "  2. Verifica: dotnet nuget list source"
Write-Host "  3. Crea tu primera Function:  /aps-new-function MiFunction"
Write-Host "  4. Crea tu primera Web App:   /aps-new-webapp MiApi"
