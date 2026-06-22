---
name: aps-webapp-template
description: Plantillas literales de archivos para una ASP.NET Core Web App (.NET 8) con APS Framework: csproj, Program.cs, appsettings, SampleController y test minimo. Carga cuando el agente aps-scaffolder va a crear o modificar una Web App.
license: MIT
compatibility: opencode
metadata:
  audience: aps-scaffolder
  workflow: project-scaffolding
---

# Plantilla: ASP.NET Core Web App con APS

Reemplazar `{NombreProyecto}` por el nombre del proyecto en PascalCase.
Reemplazar `{paquetes-adicionales}` por los `<PackageReference>` extra que
requiera la descripcion del usuario (ver skill `aps-packages`).

---

## src/{NombreProyecto}/{NombreProyecto}.csproj

```xml
<Project Sdk="Microsoft.NET.Sdk.Web">
  <PropertyGroup>
    <TargetFramework>net8.0</TargetFramework>
    <RootNamespace>{NombreProyecto}</RootNamespace>
    <AssemblyName>{NombreProyecto}</AssemblyName>
    <Nullable>enable</Nullable>
    <ImplicitUsings>enable</ImplicitUsings>
    <LangVersion>latest</LangVersion>
  </PropertyGroup>
  <ItemGroup>
    <PackageReference Include="APS.Common" Version="*" />
    <PackageReference Include="APS.Telemetry" Version="*" />
    <PackageReference Include="APS.Worker" Version="*" />
    {paquetes-adicionales}
  </ItemGroup>
</Project>
```

---

## src/{NombreProyecto}/Program.cs

```csharp
using {NombreProyecto}.Controllers;
using APS.Telemetry;
using APS.Worker;

var builder = WebApplication.CreateBuilder(args);

builder.Services
    .AddControllers()
    .AddJsonOptions(o => o.JsonSerializerOptions.PropertyNamingPolicy = System.Text.Json.JsonNamingPolicy.CamelCase);

builder.Services
    .AddApsTelemetry(builder.Configuration)
    .AddApsErrorMiddleware();

builder.Services.AddSingleton<SampleController>();

var app = builder.Build();

app.UseApsErrorMiddleware();
app.UseApsCorrelation();
app.MapControllers();
app.MapGet("/health", () => Results.Ok(new { status = "ok" }));

app.Run();
```

> Ajuste fino: si la descripcion requiere mas servicios (p.ej.
> `AddApsGoogleAuth`, `AddApsBlob`, `AddApsServiceGateway<IClienteExterno>`),
> anadirlos en este bloque. Cargar skill `aps-packages` para la API exacta.

---

## src/{NombreProyecto}/appsettings.json

```json
{
  "Logging": {
    "LogLevel": {
      "Default": "Information",
      "Microsoft.AspNetCore": "Warning"
    }
  },
  "AllowedHosts": "*"
}
```

---

## src/{NombreProyecto}/appsettings.Development.json

```json
{
  "Logging": {
    "LogLevel": {
      "Default": "Debug",
      "Microsoft.AspNetCore": "Information"
    }
  }
}
```

---

## src/{NombreProyecto}/Controllers/SampleController.cs

```csharp
using Microsoft.AspNetCore.Mvc;

namespace {NombreProyecto}.Controllers;

[ApiController]
[Route("api/[controller]")]
public class SampleController : ControllerBase
{
    private readonly ILogger<SampleController> _logger;

    public SampleController(ILogger<SampleController> logger)
        => _logger = logger;

    [HttpGet]
    public IActionResult Get()
    {
        _logger.LogInformation("{NombreProyecto} sample endpoint invoked at {Time}", DateTimeOffset.UtcNow);
        return Ok(new
        {
            ok = true,
            project = "{NombreProyecto}",
            utc = DateTimeOffset.UtcNow,
        });
    }
}
```

> Si la descripcion es concreta, reemplazar el handler con la logica que
> use los paquetes anadidos. Mantener la firma `IActionResult`/`Task<T>`
> segun corresponda.

---

## tests/{NombreProyecto}.Tests/{NombreProyecto}.Tests.csproj

```xml
<Project Sdk="Microsoft.NET.Sdk">
  <PropertyGroup>
    <TargetFramework>net8.0</TargetFramework>
    <RootNamespace>{NombreProyecto}.Tests</RootNamespace>
    <AssemblyName>{NombreProyecto}.Tests</AssemblyName>
    <Nullable>enable</Nullable>
    <ImplicitUsings>enable</ImplicitUsings>
    <LangVersion>latest</LangVersion>
    <IsPackable>false</IsPackable>
    <IsTestProject>true</IsTestProject>
    <EnableMSTestRunner>true</EnableMSTestRunner>
  </PropertyGroup>
  <ItemGroup>
    <PackageReference Include="MSTest" Version="3.6.0" />
    <PackageReference Include="NSubstitute" Version="5.1.0" />
    <PackageReference Include="Shouldly" Version="4.2.1" />
    <PackageReference Include="Microsoft.AspNetCore.Mvc.Testing" Version="8.0.0" />
  </ItemGroup>
  <ItemGroup>
    <ProjectReference Include="..\..\src\{NombreProyecto}\{NombreProyecto}.csproj" />
  </ItemGroup>
</Project>
```

---

## tests/{NombreProyecto}.Tests/SampleControllerTests.cs

```csharp
using {NombreProyecto}.Controllers;
using Microsoft.Extensions.Logging.Abstractions;
using Shouldly;

namespace {NombreProyecto}.Tests;

[TestClass]
public class SampleControllerTests
{
    [TestMethod]
    public void Constructor_Accepts_Logger()
    {
        var c = new SampleController(NullLogger<SampleController>.Instance);
        c.ShouldNotBeNull();
    }
}
```

> Para test de integracion con `WebApplicationFactory<Program>`, anadir
> el archivo `WebAppFactoryTests.cs` despues de implementar la logica.
> Cargar skill `aps-conventions` para las reglas de naming.

---

## NuGet.config (raiz del proyecto, solo si no existe)

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

- Reemplazar `{Org}` por la organizacion real en GitHub. Debe coincidir
  en `key` y en el nombre del bloque `packageSourceCredentials`.
- Requiere la variable de entorno `APS_NUGET_TOKEN` (un Classic PAT con
  scope `read:packages`). El script `scripts/setup-nuget.ps1` la configura.

---

## Comandos de verificacion (orden)

```bash
# 1. Restaurar
dotnet restore src/{NombreProyecto}/{NombreProyecto}.csproj

# 2. Build
dotnet build src/{NombreProyecto}/{NombreProyecto}.csproj

# 3. Tests
dotnet test tests/{NombreProyecto}.Tests/{NombreProyecto}.Tests.csproj

# 4. Arrancar local
dotnet run --project src/{NombreProyecto}/{NombreProyecto}.csproj
```
