# Catalogo de Demos de Referencia

> Este documento es un **catalogo de referencia**, no un roadmap del
> template. El template no incluye proyectos concretos; este catalogo
> describe ejemplos de proyectos que se pueden construir con el
> tooling de `.opencode/`.

## Como usar este catalogo

Cada demo de la tabla inferior es un ejemplo del tipo de proyecto que
se puede generar con los commands:

- `/aps-new-function [nombre] [descripcion...]`
- `/aps-new-webapp [nombre] [descripcion...]`

Los proyectos resultantes son **independientes** y pueden vivir en
este mismo repo o en repos separados, segun prefieras. La
recomendacion habitual es tener un repo por demo o agrupar varias
demos pequenas en un unico repo de showcase.

## Taxonomia

Las demos se agrupan en tiers por capacidad. Cada tier requiere el
conocimiento del anterior.

### Tier 1 - Fundamentos de Function App

| Demo                       | Que demuestra                                                              | Paquetes APS                                          |
| -------------------------- | -------------------------------------------------------------------------- | ----------------------------------------------------- |
| Hello Function             | HTTP-trigger minimo con telemetria, correlacion y logging estructurado     | `Worker`, `Telemetry`, `Common`                       |
| Configuracion tipada       | Binding de configuracion tipada desde App Configuration con Managed Identity| `DependencyInjection`, `App Configuration`            |
| Middleware de errores      | `ErrorMiddlewareBase`, mapeo de excepciones tipadas a HTTP status codes    | `Worker`, `Common`                                    |

### Tier 2 - Persistencia

| Demo                       | Que demuestra                                                              | Paquetes APS                                          |
| -------------------------- | -------------------------------------------------------------------------- | ----------------------------------------------------- |
| Blob JSON                  | Guardar/cargar JSON en Blob, prefijo ordenable                             | `Data.Blob`                                           |
| Blob streams + SAS         | Generar SAS de lectura/escritura para subida directa desde cliente         | `Data.Blob`                                           |
| Cosmos Repositorio         | Repositorio tipado, contenedor, lectura/escritura por id + partition key   | `Data.Cosmos`                                         |
| Cosmos Query Patterns      | Filtros, conteos, busquedas por prefijo                                    | `Data.Cosmos`                                         |
| Kusto Analytics            | Funcion que ejecuta KQL y mapea resultados a modelos                       | `Data.Kusto`                                          |

### Tier 3 - Mensajeria y Autenticacion

| Demo                       | Que demuestra                                                              | Paquetes APS                                          |
| -------------------------- | -------------------------------------------------------------------------- | ----------------------------------------------------- |
| Event Grid Publisher       | Publicar eventos de dominio (Duration, Id, payload)                        | `Messaging.EventGrid`                                 |
| Event Grid Subscriber      | Endpoint receptor con handshake inicial y procesamiento de eventos         | `Messaging.EventGrid`                                 |
| SendGrid Mail              | Enviar emails con plantilla y adjuntos                                     | `Messaging.Mail`                                      |
| Google JWT Auth            | Validar Google ID tokens, leer `ClaimsPrincipal` con extensiones tipadas   | `Auth`                                                |

### Tier 4 - Integracion HTTP

| Demo                       | Que demuestra                                                              | Paquetes APS                                          |
| -------------------------- | -------------------------------------------------------------------------- | ----------------------------------------------------- |
| Refit REST Client          | Cliente Refit tipado, logging HTTP, retry/circuit breaker con Polly        | `ServiceGateway`                                      |
| SOAP Client                | Cliente SOAP 1.1/1.2 con `SoapAction`, `SoapEnvelope` y `Fault`            | `ServiceGateway`                                      |
| Managed Identity / Autologin| Rutas dinamicas, autologin por metodo, propagacion de headers              | `ServiceGateway`, `DependencyInjection`               |

### Tier 5 - Dominio CS Level (Call Center)

| Demo                       | Que demuestra                                                              | Paquetes CS                                           |
| -------------------------- | -------------------------------------------------------------------------- | ----------------------------------------------------- |
| Ecommerce Operations       | Anadir ancillaries a una reserva contra Ecommerce                          | `CS.Level.Connector.Ecommerce`                        |
| Adyen Payment Link         | Crear enlace de pago Adyen y mapear tipos de respuesta                     | `CS.Adyen.Client`                                     |
| Airpricing Query           | Consultar precios, horarios y calendarios de vuelo                         | `CS.Airpricing.Client`                                |
| CS Booking Orchestration   | Orquestar PNR, pasajeros, asientos, pagos usando `ICSOperation<T>`         | `CS.Level.Booking`, `CS.Level.Domain`                 |
| Resiber SOAP Nativo        | Llamadas SOAP nativas a RES / TKT / Tarificacion con envelopes XML         | `Resiber.Native.Client`                               |

### Tier 6 - Plataforma y CI/CD

| Demo                       | Que demuestra                                                              | Notas                                                 |
| -------------------------- | -------------------------------------------------------------------------- | ----------------------------------------------------- |
| MCP Server                 | Alojar herramientas APS como servidor MCP                                  | Requiere `mcp-manifest.json` y topic de discovery     |
| Reusable Workflows Caller  | Consumir workflows reutilizables desde este repo                           | Caller de 15 lineas invocando el workflow centralizado |

## Capacidades transversales del tooling

### Agents (`.opencode/agents/`)

| Agent               | Modo     | Proposito                                                                 |
| ------------------- | -------- | ------------------------------------------------------------------------- |
| `aps-scaffolder`    | subagent | Crea Functions / WebApps con APS desde una descripcion en lenguaje natural|

### Skills (`.opencode/skills/`)

| Skill                          | Carga cuando...                                                                 |
| ------------------------------ | ------------------------------------------------------------------------------- |
| `aps-packages`                 | Hay que decidir que paquetes APS anadir segun la descripcion del usuario        |
| `aps-conventions`              | Se va a crear o modificar un proyecto                                          |
| `aps-function-template`        | Se va a crear una Function App                                                  |
| `aps-webapp-template`          | Se va a crear una Web App                                                      |

### Commands (`.opencode/commands/`)

| Comando                       | Accion                                                                                     |
| ----------------------------- | ------------------------------------------------------------------------------------------ |
| `/aps-onboard`                | Detecta repo/org, valida acceso al feed NuGet, configura `APS_NUGET_TOKEN`, detecta suscripcion Azure. **Accion explicita del usuario.** |
| `/aps-new-function`           | Scaffold completo de una Function App desde descripcion                                    |
| `/aps-new-webapp`             | Scaffold completo de una Web App desde descripcion                                        |
| `/aps-add-package`            | Anade un paquete APS a un proyecto existente                                              |

## Como construir una demo de esta lista

1. Asegurate de que el entorno esta conectado (ver README.md → "Configurar credenciales NuGet")
2. Ejecuta el command correspondiente, por ejemplo:

```
/aps-new-function EventPublisher "function que publica eventos a Event Grid cuando se crea un pedido"
```

3. El agente `aps-scaffolder`:
   - Detecta que necesitas `APS.Messaging.EventGrid`
   - Crea el proyecto con la estructura estandar
   - Registra el handler de publicacion como ejemplo
   - Deja un `SampleFunction` y notas en el README sobre como extenderlo

4. Tu trabajo: reemplazar el handler de ejemplo con la logica real,
   anadir tests, configurar `local.settings.json` con las connection
   strings, y desplegar.

## Workflows de CI/CD

Los GitHub Actions (build, test, deploy) **no se incluyen** en este
template. Se crean bajo demanda por el agente correspondiente cuando
el proyecto lo necesita. La convencion habitual es:

- Consumir el workflow reutilizable de publicacion NuGet desde
  `APS-Framework/.github` (ver skill `aps-github-workflow` cuando
  exista).
- Workflows especificos de build/test/deploy de Function Apps
  reutilizando el patron `Azure/functions-action`.

## Proximos pasos sugeridos

1. Si quieres una coleccion de demos listas para inspeccionar, clona o
   crea un repo `aps-framework-examples` que contenga varios de los
   proyectos de la tabla superior, cada uno en su carpeta.
2. Si quieres profundizar en la integracion con CS Level (Tier 5),
   asegurate de tener acceso a un sandbox de Resiber / Amadeus antes
   de empezar.
3. Si vas a publicar paquetes propios, anade el topic de discovery de
   tu org al `mcp-manifest.json` y registra las tools siguiendo la guia
   de `sdk-mcp-server`.
