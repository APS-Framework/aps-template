---
name: aps-packages
description: Catalogo de paquetes NuGet del ecosistema APS Framework y CS Level, con palabras clave para detectar que paquetes necesita un proyecto a partir de una descripcion en lenguaje natural. Carga cuando el agente aps-scaffolder debe decidir que paquetes anadir.
license: MIT
compatibility: opencode
metadata:
  audience: aps-scaffolder
  workflow: package-selection
---

# Catalogo de paquetes APS

Los paquetes viven en el feed NuGet privado de APS. El proyecto debe tener
`NuGet.config` con la fuente configurada o tenerla registrada globalmente.
Para simplificar, las plantillas usan `Version="*"`: tras el primer build
exitoso, fijar la version concreta en `Directory.Packages.props`.

## Paquetes base (obligatorios en cualquier proyecto APS)

Estos tres siempre se instalan, salvo que el usuario indique lo contrario.

| Paquete          | Proposito                                                                                  | Cuando incluirlo                       |
| ---------------- | ------------------------------------------------------------------------------------------ | -------------------------------------- |
| `APS.Common`     | Excepciones tipadas (`BusinessException`, `ValidationException`, etc.) y extensiones      | Siempre                                |
| `APS.Telemetry`  | Correlacion cross-host, logging estructurado, `AddApsTelemetry`                             | Siempre                                |
| `APS.Worker`     | Middleware de errores y mapeo de excepciones a HTTP status codes                           | Siempre en Functions; recomendado en WebApps |

## Paquetes por capacidad

Buscar las palabras clave de la descripcion del usuario y mapear a paquetes.

### Persistencia

| Paquete             | Palabras clave                                          | Notas                                                                                |
| ------------------- | ------------------------------------------------------- | ------------------------------------------------------------------------------------ |
| `APS.Data.Blob`     | `blob`, `storage`, `archivo`, `fichero`, `sas`, `upload` | Soporta JSON, streams binarios, prefijo ordenable, SAS de lectura/escritura          |
| `APS.Data.Cosmos`   | `cosmos`, `documentdb`, `nosql`, `coleccion`            | Repositorios tipados por contenedor, particion por clave, queries LINQ                |
| `APS.Data.Kusto`    | `kusto`, `adx`, `data explorer`, `kql`, `analytics`      | Ejecucion de queries KQL y mapeo a modelos C#                                         |

### Mensajeria

| Paquete                   | Palabras clave                                                | Notas                                                                          |
| ------------------------- | ------------------------------------------------------------- | ------------------------------------------------------------------------------ |
| `APS.Messaging.EventGrid` | `event grid`, `evento`, `publicar`, `subscriber`, `webhook`    | Publicacion con `Duration` e `Id`, handshake para webhooks, publishers keyed    |
| `APS.Messaging.Mail`      | `email`, `correo`, `sendgrid`, `mail`, `plantilla`, `template`| Envio con plantillas, adjuntos, CC/BCC                                         |

### Autenticacion

| Paquete      | Palabras clave                                       | Notas                                                                          |
| ------------ | ---------------------------------------------------- | ------------------------------------------------------------------------------ |
| `APS.Auth`   | `auth`, `google`, `oauth`, `jwt`, `id token`, `bearer` | Validacion de Google ID tokens en ASP.NET Core y Azure Functions               |

### Integracion HTTP

| Paquete              | Palabras clave                                                  | Notas                                                                                  |
| -------------------- | --------------------------------------------------------------- | -------------------------------------------------------------------------------------- |
| `APS.ServiceGateway` | `refit`, `http client`, `api externa`, `rest`, `soap`, `polly`   | Refit tipado, HttpClientFactory, Polly retry/CB, Managed Identity, SOAP 1.1/1.2         |

### Inyeccion de dependencias

| Paquete                    | Palabras clave                                                  | Notas                                                                                |
| -------------------------- | --------------------------------------------------------------- | ------------------------------------------------------------------------------------ |
| `APS.DependencyInjection`  | `app configuration`, `config tipada`, `scoped bag`, `correlation` | Helpers de DI, binding tipado, `IScopedBag` para propagar datos en el mismo scope     |

## Paquetes del dominio CS Level (Call Center)

Requieren credenciales y entorno CS Level. Solo incluir si el usuario lo pide
explicitamente o si la descripcion menciona "CS Level", "reserva", "PNR",
"pasaje", "vuelo", "ticketing", "pago", "ecommerce", "adyen", etc.

| Paquete                          | Palabras clave                                                | Notas                                                                                       |
| -------------------------------- | ------------------------------------------------------------- | ------------------------------------------------------------------------------------------- |
| `CS.Level.Domain`                | `cs level`, `dominio`, `reserva`, `booking`                   | Modelos, conectores PSS (`IRambla*`), servicios `ICS*`                                       |
| `CS.Level.Booking`               | `booking`, `pnr`, `orquestar reserva`                         | Orquestacion de PNR, pasajeros, asientos, pagos                                              |
| `CS.Level.Availability.Client`   | `disponibilidad`, `availability`, `tarifa`                    | Cliente HTTP de availability y tarifas                                                       |
| `CS.Level.Connector.Ecommerce`   | `ecommerce`, `ancillary`, `bundle`                            | Connector CS.Level hacia Ecommerce (reservas, ancillaries, seats)                            |
| `CS.Level.Connector.Resiber`     | `resiber connector`, `pss rambla`                             | Implementacion de `IRambla*` sobre Resiber                                                   |
| `CS.Airpricing.Client`           | `airpricing`, `precio vuelo`, `horarios vuelo`                | Cliente HTTP para precios, horarios, calendarios                                            |
| `CS.Adyen.Client`                | `adyen`, `pago`, `payment link`, `devolucion`                 | Cliente Refit de la API de pagos de Adyen                                                    |
| `CS.Ecommerce.Client`            | `ecommerce client`                                            | Cliente Refit para bookings/ancillaries/vouchers                                             |
| `Resiber.Native.Client`          | `resiber soap`, `pss soap`                                    | Cliente SOAP nativo para Resibernet (RES, TKT, InfoVuelos, Tarificacion)                     |

## Versionado

- Microsoft: fijar version concreta (`2.0.0` para Functions Worker, `8.0.x` para ASP.NET Core)
- APS y CS Level: `*` en el csproj; resolver en primer build; fijar en
  `Directory.Packages.props` cuando el proyecto se estabilice

## Feed NuGet

El proyecto debe tener `NuGet.config` con la fuente APS, por ejemplo:

```xml
<?xml version="1.0" encoding="utf-8"?>
<configuration>
  <packageSources>
    <clear />
    <add key="nuget.org" value="https://api.nuget.org/v3/index.json" protocolVersion="3" />
    <add key="{Org}" value="https://nuget.pkg.github.com/{Org}/index.json" />
  </packageSources>
</configuration>
```

Ajustar `{Org}` al nombre real de la organizacion en GitHub. Si el proyecto no
tiene `NuGet.config`, crearlo en la raiz. La plantilla completa (con
`packageSourceCredentials`) la genera `scripts/setup-nuget.ps1`.
