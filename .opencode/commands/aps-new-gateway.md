---
description: Crea un Service Gateway (SG) nuevo: class library con interfaz Refit, modelos, IoCExtensions y csproj con dotnet pack. El SG vive en la capa crosscutting del repo. Uso: /aps-new-gateway <nombre> <descripcion-api>.
agent: aps-scaffolder
subtask: false
---

Carga el skill `aps-sg-template` y crea un Service Gateway nuevo:

$ARGUMENTS

## Comportamiento esperado

El scaffolder reconoce que es un SG (no Function ni WebApp) y aplica el
template `aps-sg-template`:

1. Carga skills: `aps-sg-template`, `aps-packages`, `aps-conventions`
2. Recopila: nombre del SG, nombre de la API externa, endpoints a cubrir
3. Detecta paquetes: siempre `APS.Common` + `APS.ServiceGateway`
4. Genera:
   - `src/{NombreSG}/{NombreSG}.csproj` (class library, `IsPackable=true`)
   - `src/{NombreSG}/I{ApiName}Client.cs` (interfaz Refit)
   - `src/{NombreSG}/{ApiName}Request.cs` y `{ApiName}Response.cs`
   - `src/{NombreSG}/IoCExtensions.cs` (registro con `AddApsServiceGateway`)
   - `tests/{NombreSG}.Tests/` (MSTest + NSubstitute + Shouldly)
5. Registra en `.sln` si existe
6. Verifica: `dotnet restore` + `build` + `test` (si hay token)
7. Actualiza `AGENTS.md`: anade fila a `crosscutting` en Layer Map y a la
   tabla de Service Gateways

## Restricciones

- El SG es una **class library**, no un ejecutable. No tiene `Program.cs`
  ni `host.json`.
- La interfaz Refit define la API publica del SG. Los consumers la importan
  via `Add{NombreSG}(...)` en su `Program.cs`.
- Si el SG publica NuGet, el workflow de publicacion se gestiona por
  separado (no lo crea este command). Anadir la informacion del workflow
  a la tabla de Service Gateways en `AGENTS.md` cuando se cree.

## Ejemplos de uso

```
/aps-new-gateway Resiber cliente SOAP de Resibernet para PNR y ticketing
/aps-new-gateway Airpricing API REST de precios y horarios de vuelos
/aps-new-gateway Adyen cliente de la API de pagos de Adyen
```
