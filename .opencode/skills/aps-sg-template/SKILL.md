---
name: aps-sg-template
description: Plantillas literales de archivos para un Service Gateway (SG) APS: class library con interfaz Refit, modelos de dominio, IoCExtensions y csproj con dotnet pack. Carga cuando el agente aps-scaffolder va a crear un SG nuevo.
license: MIT
compatibility: opencode
metadata:
  audience: aps-scaffolder
  workflow: project-scaffolding
---

# Plantilla: Service Gateway (SG) con APS

Un Service Gateway es una class library que encapsula el acceso a una API
externa via Refit, con HttpClientFactory, Polly (retry/circuit breaker) y
Managed Identity opcional. Vive en la capa `crosscutting` del repo, NO en
`contracts`.

Reemplazar `{NombreSG}` por el nombre del proyecto en PascalCase (sin
spaces, sin guiones). Reemplazar `{ApiName}` por el nombre de la API
externa. Reemplazar `{BaseRoute}` por la ruta base del API.

---

## src/{NombreSG}/{NombreSG}.csproj

```xml
<Project Sdk="Microsoft.NET.Sdk">
  <PropertyGroup>
    <TargetFramework>net8.0</TargetFramework>
    <RootNamespace>{NombreSG}</RootNamespace>
    <AssemblyName>{NombreSG}</AssemblyName>
    <Nullable>enable</Nullable>
    <ImplicitUsings>enable</ImplicitUsings>
    <LangVersion>latest</LangVersion>
    <IsPackable>true</IsPackable>
    <PackageId>{NombreSG}</PackageId>
    <PackageVersion>1.0.0</PackageVersion>
    <Authors>APS</Authors>
    <RepositoryUrl>$(RepositoryUrl)</RepositoryUrl>
  </PropertyGroup>
  <ItemGroup>
    <PackageReference Include="APS.Common" Version="*" />
    <PackageReference Include="APS.ServiceGateway" Version="*" />
  </ItemGroup>
</Project>
```

> Si el SG publica NuGet, el `PackageId` debe coincidir con el nombre
> under el que se publicara en GitHub Packages. El workflow de publicacion
> se gestiona invocando la tool `github__publish` del MCP (ver skill
> `aps-deploy-template`). Para generar los README-sdk.md y README-dev.md
> del SG, invocar las tools `github__docs_sdk` y `github__docs_dev` del
> MCP respectivamente — son la fuente de verdad para el formato y
> contenido de estos archivos.

---

## src/{NombreSG}/I{ApiName}Client.cs

```csharp
using Refit;

namespace {NombreSG};

public interface I{ApiName}Client
{
    [Get("/{BaseRoute}/{id}")]
    Task<{ApiName}Response> GetByIdAsync(string id, CancellationToken ct);

    [Post("/{BaseRoute}")]
    Task<{ApiName}Response> CreateAsync([Body] {ApiName}Request request, CancellationToken ct);
}
```

> Anadir metodos segun los endpoints de la API externa. Cada metodo debe
> tener su modelo de request y response. Si la API usa SOAP, usar
> `APS.ServiceGateway` con el soporte SOAP en lugar de Refit.

---

## src/{NombreSG}/{ApiName}Request.cs

```csharp
namespace {NombreSG};

public class {ApiName}Request
{
    public string Id { get; init; } = string.Empty;
    public string Name { get; init; } = string.Empty;
}
```

---

## src/{NombreSG}/{ApiName}Response.cs

```csharp
namespace {NombreSG};

public class {ApiName}Response
{
    public string Id { get; init; } = string.Empty;
    public string Name { get; init; } = string.Empty;
    public string Status { get; init; } = string.Empty;
}
```

---

## src/{NombreSG}/IoCExtensions.cs

```csharp
using APS.ServiceGateway;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;

namespace {NombreSG};

public static class IoCExtensions
{
    public static IServiceCollection Add{NombreSG}(
        this IServiceCollection services,
        IConfiguration configuration,
        string configSection = "{NombreSG}")
    {
        services.AddApsServiceGateway<I{ApiName}Client>(configuration, configSection);
        return services;
    }
}
```

> `AddApsServiceGateway<T>` registra el cliente Refit con HttpClientFactory,
> Polly (retry/circuit breaker) y Managed Identity opcional. La seccion de
> configuracion en `appsettings.json` define `BaseUrl`, `RetryCount`,
> `CircuitBreakerThreshold`, etc.

---

## tests/{NombreSG}.Tests/{NombreSG}.Tests.csproj

```xml
<Project Sdk="Microsoft.NET.Sdk">
  <PropertyGroup>
    <TargetFramework>net8.0</TargetFramework>
    <RootNamespace>{NombreSG}.Tests</RootNamespace>
    <AssemblyName>{NombreSG}.Tests</AssemblyName>
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
    <ProjectReference Include="..\..\src\{NombreSG}\{NombreSG}.csproj" />
  </ItemGroup>
</Project>
```

---

## tests/{NombreSG}.Tests/IoCExtensionsTests.cs

```csharp
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using Shouldly;

namespace {NombreSG}.Tests;

[TestClass]
public class IoCExtensionsTests
{
    [TestMethod]
    public void Add{NombreSG}_WithValidConfig_RegistersClient()
    {
        var config = new ConfigurationBuilder()
            .AddInMemoryCollection(new Dictionary<string, string?>
            {
                ["{NombreSG}:BaseUrl"] = "https://api.example.com",
            })
            .Build();

        var services = new ServiceCollection();
        services.Add{NombreSG}(config);

        var provider = services.BuildServiceProvider();
        var client = provider.GetService<I{ApiName}Client>();
        client.ShouldNotBeNull();
    }
}
```

---

## NuGet.config (raiz, solo si no existe)

Usar la misma plantilla que `aps-function-template` o `aps-webapp-template`.
El SG consume paquetes APS (`APS.Common`, `APS.ServiceGateway`) del mismo
feed.

---

## appsettings.json de referencia (para el consumer)

El SG no tiene `appsettings.json` propio (es una libreria). El consumer
(Function App o Web App) debe anadir esta seccion:

```json
{
  "{NombreSG}": {
    "BaseUrl": "https://api.example.com",
    "RetryCount": 3,
    "CircuitBreakerThreshold": 5,
    "TimeoutSeconds": 30
  }
}
```

> Incluir esta seccion como comentario en el README del SG para que los
> consumers sepan que configuracion necesitan.

---

## Comandos de verificacion (orden)

```bash
# 1. Restaurar
dotnet restore src/{NombreSG}/{NombreSG}.csproj

# 2. Build
dotnet build src/{NombreSG}/{NombreSG}.csproj

# 3. Tests
dotnet test tests/{NombreSG}.Tests/{NombreSG}.Tests.csproj

# 4. Pack (solo si publica NuGet)
dotnet pack src/{NombreSG}/{NombreSG}.csproj --configuration Release
```
