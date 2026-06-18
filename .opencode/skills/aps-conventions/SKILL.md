---
name: aps-conventions
description: Convenciones de organizacion de proyectos APS: estructura de carpetas, archivos obligatorios (Directory.Build.props, .gitignore, NuGet.config), telemetria y middleware de errores obligatorios, naming de proyectos y namespaces. Carga siempre que el agente aps-scaffolder vaya a crear o modificar un proyecto.
license: MIT
compatibility: opencode
metadata:
  audience: aps-scaffolder
  workflow: project-scaffolding
---

# Convenciones APS

Reglas que todo proyecto generado con las tools de `aps-scaffolder` debe
cumplir. Son portables: valen para este repo POC, para un proyecto real,
para una demo interna o para el repo de un cliente.

## Estructura de carpetas estandar

```
{ProyectoRoot}/
+-- src/
|   +-- {NombreProyecto}/
|       +-- Program.cs
|       +-- {NombreProyecto}.csproj
|       +-- host.json                 (solo Function App)
|       +-- appsettings.json
|       +-- appsettings.Development.json
|       +-- local.settings.json       (solo Function App, no commitear)
|       +-- Functions/                (solo Function App)
|       |   +-- SampleFunction.cs
|       +-- Controllers/              (solo Web App, si aplica)
|       |   +-- SampleController.cs
|       +-- Services/                 (opcional, si la logica lo requiere)
|       +-- Models/                   (opcional)
+-- tests/
|   +-- {NombreProyecto}.Tests/
|       +-- {NombreProyecto}.Tests.csproj
|       +-- SampleFunctionTests.cs    o SampleControllerTests.cs
+-- Directory.Build.props             (obligatorio, raiz)
+-- Directory.Packages.props          (recomendado, raiz)
+-- NuGet.config                      (obligatorio si se usan paquetes APS)
+-- .gitignore                        (obligatorio)
+-- README.md                         (obligatorio)
+-- {NombreProyecto}.sln              (opcional; recomendado si hay mas de un proyecto)
```

Si el usuario ya tiene una estructura distinta, **respetarla** y solo anadir
lo que falte.

## Naming

- **Nombre del proyecto**: PascalCase, sin espacios, sin guiones.
  Ejemplos: `Orders`, `BookingApi`, `EventGridNotifications`.
- **Namespace raiz**: identico al nombre del proyecto.
  Si el proyecto esta en `src/Orders.Api/`, el namespace es `Orders.Api`.
- **Assembly**: identico al nombre del proyecto.
- **Tests**: sufijo `.Tests` (`Orders.Tests`, `BookingApi.Tests`).
- **Function classes**: sufijo `Function` (`OrdersFunction`, `PaymentFunction`).
- **Controller classes**: sufijo `Controller` (`OrdersController`).
- **Service classes**: sufijo `Service` o `Handler` (`OrdersService`, `PaymentHandler`).

## Directory.Build.props (obligatorio)

```xml
<Project>
  <PropertyGroup>
    <TargetFramework>net8.0</TargetFramework>
    <Nullable>enable</Nullable>
    <ImplicitUsings>enable</ImplicitUsings>
    <LangVersion>latest</LangVersion>
    <TreatWarningsAsErrors>false</TreatWarningsAsErrors>
    <AnalysisLevel>latest</AnalysisLevel>
    <EnforceCodeStyleInBuild>false</EnforceCodeStyleInBuild>
  </PropertyGroup>
</Project>
```

## .gitignore (obligatorio, debe contener)

```
# .NET
bin/
obj/
*.user
.vs/
.vscode/
*.suo

# Azure Functions
local.settings.json
**/local.settings.json
appsettings.Development.local.json

# Resultados y cobertura
TestResults/
coverage*.xml
*.trx
```

## Configuracion del entorno local (accion EXPLICITA del usuario)

El template es **agnostico del entorno y la organizacion** por defecto:
incluye un `NuGet.config` con el placeholder `%APS_NUGET_TOKEN%` que NO
funciona hasta que el desarrollador conecte el repo con su organizacion
de GitHub.

Conectar el repo es una **decision explicita del usuario**, no algo que
el agente (o el template) haga automaticamente. Depende de:

- La organizacion a la que pertenece el repo
- La cuenta de GitHub del desarrollador
- La suscripcion de Azure donde se desplegara
- Las credenciales disponibles (Classic PAT con `read:packages`)

**Regla dura**: Ningun agente opencode debe auto-ejecutar el setup de
NuGet. El usuario debe correr explicitamente `/aps-onboard` o
`pwsh ./scripts/setup-nuget.ps1` cuando este listo para conectar.

### Que necesita el usuario antes de poder restaurar paquetes APS

- `gh` CLI instalado y autenticado (`gh auth login`)
- Scope `read:packages` anadido a la sesion (`gh auth refresh --scopes "read:packages"`)
- Variable de entorno `APS_NUGET_TOKEN` apuntando al token de la sesion `gh`
- `dotnet` SDK 8.x o 10.x

### Que hace `/aps-onboard` (cuando el usuario lo invoca)

1. Verifica prerequisitos (gh, dotnet)
2. Refresca scopes de gh
3. Configura `APS_NUGET_TOKEN` y `GITHUB_TOKEN` en variables de usuario
4. Detecta la org desde `git remote get-url origin`
5. Sobrescribe el `NuGet.config` con la org detectada
6. Valida con `dotnet restore`

Tras ejecutarlo, **abrir una nueva terminal** para que las variables
esten disponibles. Hasta entonces, el `NuGet.config` del template
seguira con placeholders y los restores fallaran.

## NuGet.config (obligatorio para paquetes APS)

Feed real: GitHub Packages de la organizacion publicadora.

```xml
<?xml version="1.0" encoding="utf-8"?>
<configuration>
  <packageSources>
    <clear />
    <add key="nuget.org" value="https://api.nuget.org/v3/index.json" protocolVersion="3" />
    <add key="{Org}" value="https://nuget.pkg.github.com/{Org}/index.json" />
  </packageSources>
  <packageSourceCredentials>
    <{Org}>
      <add key="Username" value="x" />
      <add key="ClearTextPassword" value="%APS_NUGET_TOKEN%" />
    </{Org}>
  </packageSourceCredentials>
</configuration>
```

- Reemplazar `{Org}` por el nombre real de la organizacion en GitHub
  (sensible a mayusculas, debe coincidir con `key` y con el nombre del
  bloque `packageSourceCredentials`).
- Solo incluir entradas para feeds de los que el proyecto consume paquetes.
- Si el proyecto no consume paquetes privados, basta con nuget.org.
- Sin este archivo, el build falla con `NU1101: Unable to find package APS.Telemetry`.
- El script `setup-nuget.ps1` lo crea automaticamente detectando la org
  del remote `origin` de git.

## Paquetes base obligatorios

Toda Function App y Web App nueva debe incluir:

- `APS.Common`
- `APS.Telemetry`
- `APS.Worker`

Y un `Program.cs` que los active. Ver skills `aps-function-template` y
`aps-webapp-template` para los contenidos exactos.

## Telemetria y errores

- `AddApsTelemetry(...)` debe estar en el `Program.cs` antes de construir el host
- `AddApsErrorMiddleware()` o equivalente debe estar en el pipeline
- Las excepciones de dominio (`APS.Common`) se propagan sin mapear; las
  genericas se loguean y devuelven 500 con el `correlationId` en el body

## Codigo

- File-scoped namespaces
- Nullable reference types habilitado
- Inyeccion de dependencias por constructor
- `ILogger<T>` inyectado, nunca `Console.WriteLine`
- Handlers de HTTP en clases separadas (no `static`), para poder testear
- Sin emojis en el codigo fuente

## Reglas duras para el agente

1. **No** ejecutar `dotnet new` para reutilizar plantillas de Microsoft; usar
   solo las plantillas de `aps-function-template` o `aps-webapp-template`.
2. **No** hacer commit ni push.
3. **No** modificar archivos fuera del scope del comando (salvo `.gitignore`
   y `NuGet.config` si faltan y el proyecto los necesita).
4. Si el directorio destino ya existe, **abortar y avisar**.
5. Si el proyecto destino es un repo existente con `.sln`, anadir el
   nuevo proyecto al `.sln` (`dotnet sln <sln> add <csproj>`). Si no hay
   `.sln` y se van a crear multiples proyectos, crear uno nuevo.
6. Tras crear, ejecutar `dotnet build` y verificar 0 errores. Si falla,
   **abortar y reportar** la traza al usuario.
7. Resumir al usuario: archivos creados, paquetes instalados, resultado del build.
