---
name: aps-function-template
description: Plantillas literales de archivos para una Azure Function (isolated worker, .NET 8) con APS Framework: csproj, Program.cs, host.json, SampleFunction, appsettings, local.settings.json y test minimo. Carga cuando el agente aps-scaffolder va a crear o modificar una Function App.
license: MIT
compatibility: opencode
metadata:
  audience: aps-scaffolder
  workflow: project-scaffolding
---

# Plantilla: Azure Function App con APS

Reemplazar `{NombreProyecto}` por el nombre del proyecto en PascalCase
(sin espacios, sin guiones). Reemplazar `{paquetes-adicionales}` por los
`<PackageReference>` extra que requiera la descripcion del usuario (ver
skill `aps-packages`).

---

## src/{NombreProyecto}/{NombreProyecto}.csproj

```xml
<Project Sdk="Microsoft.NET.Sdk">
  <PropertyGroup>
    <OutputType>Exe</OutputType>
    <TargetFramework>net8.0</TargetFramework>
    <RootNamespace>{NombreProyecto}</RootNamespace>
    <AssemblyName>{NombreProyecto}</AssemblyName>
    <Nullable>enable</Nullable>
    <ImplicitUsings>enable</ImplicitUsings>
    <LangVersion>latest</LangVersion>
    <_FunctionsSkipCleanOutput>true</_FunctionsSkipCleanOutput>
  </PropertyGroup>
  <ItemGroup>
    <PackageReference Include="Microsoft.Azure.Functions.Worker.Sdk" Version="2.0.0" />
    <PackageReference Include="Microsoft.Azure.Functions.Worker" Version="2.0.0" />
    <PackageReference Include="APS.Common" Version="*" />
    <PackageReference Include="APS.Telemetry" Version="*" />
    <PackageReference Include="APS.Worker" Version="*" />
    {paquetes-adicionales}
  </ItemGroup>
  <ItemGroup>
    <None Update="host.json">
      <CopyToOutputDirectory>PreserveNewest</CopyToOutputDirectory>
    </None>
    <None Update="local.settings.json">
      <CopyToOutputDirectory>PreserveNewest</CopyToOutputDirectory>
      <CopyToPublishDirectory>Never</CopyToPublishDirectory>
    </None>
  </ItemGroup>
</Project>
```

---

## src/{NombreProyecto}/Program.cs

```csharp
using {NombreProyecto}.Functions;
using APS.Telemetry;
using APS.Worker;

var builder = Host.CreateApplicationBuilder(args);

builder.Services
    .AddApsTelemetry(builder.Configuration)
    .AddApsErrorMiddleware()
    .AddSingleton<SampleFunction>();

builder.Build().Run();
```

> Ajuste fino: si la descripcion requiere mas servicios (p.ej. `AddApsBlob`,
> `AddApsCosmos`, `AddApsEventGridPublisher`), anadirlos en este bloque. Cargar
> skill `aps-packages` para la API exacta de cada uno.

---

## src/{NombreProyecto}/host.json

```json
{
  "version": "2.0",
  "logging": {
    "applicationInsights": {
      "samplingSettings": {
        "isEnabled": true,
        "maxTelemetryItemsPerSecond": 20
      }
    }
  },
  "telemetryMode": "OpenTelemetry"
}
```

---

## src/{NombreProyecto}/Functions/SampleFunction.cs

```csharp
using Microsoft.Azure.Functions.Worker;
using Microsoft.Azure.Functions.Worker.Http;

namespace {NombreProyecto}.Functions;

public class SampleFunction
{
    private readonly ILogger<SampleFunction> _logger;

    public SampleFunction(ILogger<SampleFunction> logger)
        => _logger = logger;

    [Function(nameof(SampleFunction))]
    public async Task<HttpResponseData> Run(
        [HttpTrigger(AuthorizationLevel.Function, "get", "post")] HttpRequestData req,
        CancellationToken ct)
    {
        _logger.LogInformation("{NombreProyecto} invoked at {Time}", DateTimeOffset.UtcNow);

        var response = req.CreateResponse(System.Net.HttpStatusCode.OK);
        await response.WriteAsJsonAsync(new
        {
            ok = true,
            project = "{NombreProyecto}",
            utc = DateTimeOffset.UtcNow,
        }, ct);
        return response;
    }
}
```

> Si la descripcion del usuario es concreta (p.ej. "function que publica
> eventos a Event Grid"), reemplazar el contenido de esta clase por un
> handler que use los paquetes anadidos. Cargar skill `aps-packages` para
> la API concreta.

---

## src/{NombreProyecto}/appsettings.json

```json
{
  "IsEncrypted": false,
  "Values": {
    "AzureWebJobsStorage": "UseDevelopmentStorage=true",
    "FUNCTIONS_WORKER_RUNTIME": "dotnet-isolated"
  }
}
```

---

## src/{NombreProyecto}/appsettings.Development.json

```json
{
  "IsEncrypted": false,
  "Values": {
    "FUNCTIONS_WORKER_RUNTIME": "dotnet-isolated"
  }
}
```

---

## src/{NombreProyecto}/local.settings.json (NO commitear)

```json
{
  "IsEncrypted": false,
  "Values": {
    "AzureWebJobsStorage": "UseDevelopmentStorage=true",
    "FUNCTIONS_WORKER_RUNTIME": "dotnet-isolated"
  }
}
```

> `local.settings.json` debe estar excluido en `.gitignore` (ver
> skill `aps-conventions`).

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
  </ItemGroup>
  <ItemGroup>
    <ProjectReference Include="..\..\src\{NombreProyecto}\{NombreProyecto}.csproj" />
  </ItemGroup>
</Project>
```

---

## tests/{NombreProyecto}.Tests/SampleFunctionTests.cs

```csharp
using {NombreProyecto}.Functions;
using Microsoft.Extensions.Logging.Abstractions;
using Shouldly;

namespace {NombreProyecto}.Tests;

[TestClass]
public class SampleFunctionTests
{
    [TestMethod]
    public void Constructor_Accepts_Logger()
    {
        var fn = new SampleFunction(NullLogger<SampleFunction>.Instance);
        fn.ShouldNotBeNull();
    }
}
```

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
# 1. Restaurar paquetes (requiere NuGet.config con fuente APS)
dotnet restore src/{NombreProyecto}/{NombreProyecto}.csproj

# 2. Build
dotnet build src/{NombreProyecto}/{NombreProyecto}.csproj

# 3. Tests
dotnet test tests/{NombreProyecto}.Tests/{NombreProyecto}.Tests.csproj

# 4. Arrancar local (requiere Azure Functions Core Tools)
func start --prefix {nombre-kebab}
```
