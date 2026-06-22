---
name: add-feature
description: Protocolo para implementar nuevas funcionalidades desde cero (endpoints, servicios, jobs programados, event handlers, opciones de configuración). Cubre el análisis de reutilización, la decisión entre servicio nuevo vs extensión de existente, la evaluación de configuración requerida y el impacto en la API pública. El orchestrator debe cargar este skill cuando se pida crear una funcionalidad nueva que no existía antes.
license: MIT
compatibility: opencode
metadata:
  audience: orchestrator
  workflow: creation,feature
  stack: csharp,dotnet8,azure-functions,aspnetcore
---

## Qué hago

Guío al orchestrator para **crear funcionalidades nuevas** (no modificar existentes) con análisis
previo de reutilización, configuración y compatibilidad. A diferencia de los refactors, aquí
**no hay código previo** que preservar: el diseño empieza desde los requisitos del usuario.

**Cuándo usar este skill** (en lugar de `refactor-protocol`):
- Usuario pide un endpoint, servicio, job, handler, evento o configuración que NO existe
- La tarea es **creación pura**, no modificación de comportamiento existente
- El resultado añade archivos al repositorio, no cambia la signatura de los existentes

**Cuándo NO usar este skill** (usar `refactor-protocol` en su lugar):
- Modificar signatura de un servicio existente
- Cambiar comportamiento de un endpoint que ya existe
- Renombrar, extraer o mover código

---

## FASE 0 — Validación de estructura (siempre primera)

1. Cargar el skill `project-structure` y ejecutar la validación completa
2. Detectar el tipo de host: `FUNCTIONS` | `WEBAPP` | `NUGET_LIBRARY`
3. Actuar según el resultado:

| Estado | Acción |
|---|---|
| `HARD_BLOCK` | Detener. Informar al usuario. |
| `NUGET_LIBRARY` | Crear un endpoint HTTP es inesperado. Preguntar: "¿Quieres añadir una operación pública a la librería o realmente hay un host que no he detectado?" |
| `PREGUNTA` | Resolver las preguntas antes de continuar |
| `OK` / `WARNING` | Continuar a FASE 1 |

---

## FASE 1 — Recopilación de requisitos

El orchestrator infiere lo que pueda de la descripción del usuario (`$ARGUMENTS`) y **solo pregunta
lo que no esté claro**. No hacer preguntas cuya respuesta ya esté en la descripción.

### 1.1 Nombre, propósito y tipo de feature

- **Endpoint HTTP** (Function/Controller): `[VERBO] /ruta — descripción`
- **Servicio de dominio**: nombre del servicio y responsabilidad
- **Job/Event handler**: trigger + acción
- **Opción de configuración**: nombre de la opción y su propósito

### 1.2 Clasificación READ vs MUTATION

Determinar si la feature **muta estado** o es **solo lectura**. Esto afecta a:

- Dónde van los DTOs de response
- Si se requiere transacción / idempotencia
- Qué tests se necesitan

| Tipo | Características | Implicación |
|---|---|---|
| READ-ONLY | GET, devuelve datos existentes, no escribe | DTOs efímeros, tests mínimos |
| MUTATION | POST/PUT/DELETE, escribe o cambia estado | Requiere tests de éxito + error |

### 1.3 Recopilación de input/output esperado

- **Request**: estructura del body o query params
- **Response**: estructura del body de respuesta, status codes
- **Errores**: qué errores se deben mapear a qué status codes

---

## FASE 1.5 — Análisis de reutilización (CRÍTICA, no saltarse)

**Objetivo**: detectar si la feature ya existe parcial o totalmente antes de crear nada.

### Pasos

1. **Buscar servicios existentes** en `*.Impl/` con `@explore` usando el dominio de la feature
2. **Buscar métodos candidatos** que cubran el 80%+ del comportamiento requerido:
   - ¿Hay un método que ya devuelve el dato necesario con un filtro trivial?
   - ¿Hay un método que se podría sobrecargar para añadir el caso?
3. **Buscar endpoints similares** en `*.API/` con la misma forma de request/response

### Árbol de decisión

```
¿Existe método que cubre 100% del caso?
└── SÍ → NO crear método nuevo. Crear solo:
        · Endpoint (Function/Controller) en *.API/
        · DTO Request/Response exclusivo en *.API/
        · Test del shape del response

¿Existe método casi-idóneo (filtro, paginación, orden)?
├── SÍ → considerar:
│   ├── Añadir parámetro opcional al método existente (con valor por defecto)
│   ├── Crear overload con signatura más específica
│   └── Crear método de extensión que envuelva al existente
└── NO → continuar con creación de método nuevo

¿Existe servicio relacionado pero diferente (e.g., similar responsabilidad)?
├── SÍ → preguntar al usuario: "¿Extiendo [CSXxxService] o creo uno nuevo [CSYyyService]?"
└── NO → crear servicio nuevo
```

### Salida esperada de esta fase

Una de estas tres decisiones, **presentada al usuario antes de continuar**:

1. **Reutilización pura**: la feature se implementa como wrapper de un método existente
2. **Extensión**: añadir overload/método a un servicio existente
3. **Creación nueva**: servicio y métodos nuevos (justificar por qué no se puede reutilizar)

---

## FASE 1.6 — Análisis de configuración (NUEVA)

**Objetivo**: detectar si la feature requiere parámetros configurables y, si sí, dónde definirlos.

### Preguntas clave

1. ¿La feature tiene **valores por defecto razonables** sin configuración externa?
2. ¿Hay **umbrales, paginación, timeouts, o flags** que deberían ser configurables por entorno?
3. ¿Se conecta a un **sistema externo** con URL/clave/secret?
4. ¿Necesita **feature flags** para rollout gradual?

### Árbol de decisión

```
¿La feature requiere configuración?
├── NO → no crear IXxxOptions, no tocar AddCustomConfiguration
└── SÍ → continuar

¿Qué tipo de configuración?
├── Connection string o secreto
│   └── Usar IConfiguration con nombre en appsettings.json (gestionado por AddCustomConfiguration)
├── Valor simple (umbral, timeout, flag)
│   └── Crear IXxxOptions en *.Impl/ (interface) + añadir a AddCustomConfiguration<T>("key")
└── Lista de valores (allowed origins, mappings)
    └── Crear IXxxOptions con propiedad de tipo IEnumerable<T>
```

### Convención del proyecto

El proyecto usa `AddCustomConfiguration<IXxxOptions>("config-section")` en `IoCExtensions.cs`
(líneas 43-45 del proyecto actual). Las interfaces viven en `*.Impl/` y se referencian desde
`*.Impl/Services/`.

### Salida esperada

Si la feature requiere configuración, presentar al usuario:
- Nombre de la interface (e.g., `IPendingPaymentOptions`)
- Propiedades con sus tipos y valores por defecto
- Sección en `appsettings.json` (e.g., `"RAMBLA.PendingPayment"`)
- Modificación de `IoCExtensions.AddCSLevelBooking()`

Si NO requiere, indicarlo explícitamente en el plan.

---

## FASE 1.7 — Análisis de impacto en API pública

**Objetivo**: evitar romper consumers existentes.

### Si la feature reutiliza un método existente

- ¿El método se mantiene con la misma signatura? → sin impacto
- ¿Se añade un parámetro opcional? → verificar que ningún call site se rompa
- ¿Se añade un overload? → verificar que el compilador resuelva sin ambigüedad
- ¿Se renombra? → buscar todos los call sites con `grep` y migrar

### Si la feature añade un servicio nuevo

- ¿El servicio se registra en DI? → asegurar registro en `IoCExtensions`
- ¿Algún servicio existente tiene dependencia circular potencial? → verificar

### Si la feature añade un endpoint nuevo

- ¿La ruta colisiona con otra ruta existente? → verificar
- ¿El método HTTP es coherente con REST? (GET para lectura, POST para mutación)

---

## FASE 1.8 — PREFLIGHT de tests de regresión (obligatorio)

**Objetivo**: antes de generar código nuevo o modificar existente, verificar
que los componentes que se van a tocar (aunque sea tangencialmente) tienen
cobertura de tests. Si no la tienen, crearla y ejecutarla **antes** de iniciar
la implementación.

### Pasos

1. **Identificar superficie tangencial**: a partir de FASE 1.5 (reutilización
   vs extensión vs nuevo), listar:
   - Servicios existentes cuyos métodos se van a extender o sobrecargar
   - Interfaces existentes que se van a modificar
   - Endpoints existentes que pueden verse afectados por routing/DI
   - Cualquier archivo existente que se va a editar (no crear)

2. **Para cada componente existente que se va a tocar**:
   - Buscar tests en `src/*.Test*/**` que lo ejerciten
   - Si tiene cobertura → OK, continuar
   - Si **no** tiene cobertura → **HARD BLOCK**:
     - Invocar `@refactor-worker-tests` para crear tests de caracterización
       del comportamiento actual
     - Invocar `@refactor-verifier` para confirmar que pasan en verde
     - Commit separado:
       ```
       test(characterization): add characterization tests for <clases>
       ```

3. **Si la feature es 100% creación nueva** (no toca archivos existentes):
   - No hay superficie de regresión → omitir PREFLIGHT
   - Pero los tests de la feature nueva se crean en FASE 4 y deben pasar en FASE 5

### Criterio de cierre (FASE 5)

Para dar por correcta la feature, `@refactor-verifier` debe confirmar que pasan:
1. **Tests nuevos** de la feature (servicio + endpoint)
2. **Tests existentes** de los componentes tangenciales (regresión)

Si cualquiera falla, la feature **no puede cerrarse**.

---

## FASE 2 — Árbol de decisión: qué crear y dónde

Aplicar la decisión de la FASE 1.5 (reutilización / extensión / nuevo) más la FASE 1.6 (config).

### Para endpoint READ-ONLY con reutilización

```
*.API/
  + {Nombre}Function.cs       — Function/Controller nuevo
  + {Nombre}Request.cs        — exclusivo de presentación
  + {Nombre}Response.cs       — exclusivo de presentación
*.Test*/
  + {Nombre}FunctionTests.cs  — test de shape del response (NO lógica)
```

### Para endpoint MUTATION con servicio nuevo

```
*.Contracts/
  + ICS{Nombre}Service.cs     — interfaz del servicio
  + {Nombre}Request.cs        — si Request compartido
  + {Nombre}Response.cs       — si Response compartido
*.Impl/
  + CS{Nombre}Service.cs      — implementación
  + I{Nombre}Options.cs       — SOLO si FASE 1.6 detectó config
*.API/
  + {Nombre}Function.cs       — Function/Controller
  + {Nombre}Request.cs        — exclusivo (si no se puso en Contracts)
  + {Nombre}Response.cs       — exclusivo (si no se puso en Contracts)
*.Test*/
  + CS{Nombre}ServiceTests.cs — happy path + al menos un error
```

### Para extensión de servicio existente

```
*.Contracts/
  ~ ICS{Nombre}Service.cs     — añadir firma del método (o crear overload)
*.Impl/
  ~ CS{Nombre}Service.cs      — implementar el nuevo método/overload
*.API/
  + {Nombre}Function.cs       — Function/Controller nuevo
  + {Nombre}Request.cs        — si exclusivo
  + {Nombre}Response.cs       — si exclusivo
*.Test*/
  + (o ~) tests del servicio — añadir caso para el nuevo método
```

---

## FASE 3 — Plan de creación

Antes de invocar workers, el orchestrator presenta este plan al usuario y espera confirmación
explícita:

```
[PLAN DE CREACIÓN] Feature: <nombre> — <descripción breve>
Host: <FUNCTIONS | WEBAPP>
Clasificación: <READ-ONLY | MUTATION>
Estrategia: <REUTILIZACIÓN | EXTENSIÓN | NUEVO>

Análisis de reutilización (FASE 1.5):
  · Servicio candidato: <ICSXxxService> o "ninguno"
  · Método candidato: <XxxService.YyyMethod> o "ninguno"
  · Decisión: <REUTILIZACIÓN | EXTENSIÓN | NUEVO>

Análisis de configuración (FASE 1.6):
  · Requiere config: <SÍ | NO>
  · Si sí: <IXxxOptions + sección appsettings>

Impacto en API pública (FASE 1.7):
  · Call sites afectados: <lista> o "ninguno"
  · Breaking change: <SÍ | NO>

Artefactos a crear:

  *.Contracts/ ([N] archivos):
    + ICS{Nombre}Service.cs    — nueva interfaz (o: añadir método a IXxx)
    + {Nombre}Request.cs       — si tipo compartido
    + {Nombre}Response.cs      — si tipo compartido

  *.Impl/ ([N] archivos):
    + CS{Nombre}Service.cs     — implementación del servicio
    + I{Nombre}Options.cs      — SOLO si requiere config (FASE 1.6)

  *.API/ ([N] archivos):
    + {Nombre}Function.cs      — Azure Function (o: {Nombre}Controller.cs)
    + {Nombre}Request.cs       — si tipo exclusivo
    + {Nombre}Response.cs      — si tipo exclusivo

  *.Test*/ ([N] archivos):
    + CS{Nombre}ServiceTests.cs — tests del servicio (happy path + error)
    + {Nombre}FunctionTests.cs  — tests del endpoint (si aplica)

Modificaciones a archivos existentes:
  ~ src/.../IoCExtensions.cs   — registrar servicio y opciones (si aplica)

Orden de ejecución: Contracts → Impl → Presentation → Tests

¿Proceder?
```

**Sin aprobación explícita del usuario, no invocar workers.**

---

## FASE 4 — Ejecución

### Orden de workers

1. **`@refactor-worker-contracts`** — solo si hay nuevos tipos o signaturas en `*.Contracts/`
2. **`@refactor-worker-impl`** — siempre que haya código en `*.Impl/`
3. **`@refactor-worker-presentation`** — siempre que haya un endpoint
4. **`@refactor-worker-tests`** — siempre al final

> Nota: NO se invoca `@refactor-worker-crosscutting` salvo que la feature exponga un nuevo
> Service Gateway. Esto es un caso raro en creación; suele ser en refactors.

### Instrucciones a cada worker

Incluir en el prompt:
- El plan completo (FASE 3)
- Los patrones del proyecto: leer un archivo similar antes de crear
- La lista exacta de archivos con su contenido esperado
- **Si FASE 1.6 detectó config**: el path de `IXxxOptions` y la sección de configuración

---

## FASE 5 — Verificación y commit

1. Invocar `@refactor-verifier`
2. Si PASS → proponer commit con formato:
   ```
   feat(<scope>): add <nombre-corto> feature

   - Added ICS{Nombre}Service interface and CS{Nombre}Service implementation
   - Added {VERB} /{ruta} Function/Controller
   - Added {Nombre}Request/{Nombre}Response contracts
   - Added I{Nombre}Options for new configuration (si aplica)
   - Added unit tests for CS{Nombre}Service
   ```
3. Si FAIL → identificar capa fallida, re-invocar worker, re-verificar

---

## Patrones por host

### FUNCTIONS — Azure Functions Isolated Worker

Antes de crear la Function, leer una Function HTTP existente y copiar su estilo. Ejemplo típico:

```csharp
public class {Nombre}Function
{
    private readonly I{Nombre}Service _{campo};

    public {Nombre}Function(I{Nombre}Service {campo}) => _{campo} = {campo};

    [Function("{Nombre}Function")]
    public async Task<HttpResponseData> RunAsync(
        [HttpTrigger(AuthorizationLevel.Function, "post", Route = "{ruta}")] HttpRequestData req)
    {
        var request = await req.ReadFromJsonAsync<{Nombre}Request>();
        var result = await _{campo}.ExecuteAsync(request);
        var response = req.CreateResponse(HttpStatusCode.OK);
        await response.WriteAsJsonAsync(result);
        return response;
    }
}
```

**Verificar antes de crear**:
- ¿`AuthorizationLevel.Function` o `Anonymous`? (copiar del proyecto)
- ¿`ReadFromJsonAsync` o lectura manual? (copiar del proyecto)
- ¿DI registrado en `IoCExtensions.AddCSLevelBooking()`? (añadir si no)

### WEBAPP — ASP.NET Core

Antes de crear el Controller/Endpoint, leer uno existente:
- ¿Controllers con `[ApiController]` o Minimal API?
- ¿`IActionResult` / `ActionResult<T>` o `Results<T>`?
- ¿Validación con FluentValidation, DataAnnotations u otro?

Copiar el estilo existente.

---

### Non-HTTP triggers (Timer, Service Bus, Event Grid)

Antes de crear el trigger, leer uno existente en el proyecto y copiar su estilo.
Si no hay ninguno, usar estos patrones de referencia.

#### Timer trigger

```csharp
public class {Nombre}Function
{
    private readonly I{Nombre}Service _{campo};

    public {Nombre}Function(I{Nombre}Service {campo}) => _{campo} = {campo};

    [Function("{Nombre}Function")]
    public async Task RunAsync(
        [TimerTrigger("0 */5 * * * *")] TimerInfo timer,
        CancellationToken ct)
    {
        await _{campo}.ExecuteAsync(ct);
    }
}
```

- El CRON expression `0 */5 * * * *` significa cada 5 minutos (NCRONTAB, 6 campos).
- `TimerInfo` puede ser null en local; no asumir que tiene valor.
- Registrar el servicio en `IoCExtensions` como siempre.

#### Service Bus trigger

```csharp
public class {Nombre}Function
{
    private readonly I{Nombre}Service _{campo};

    public {Nombre}Function(I{Nombre}Service {campo}) => _{campo} = {campo};

    [Function("{Nombre}Function")]
    public async Task RunAsync(
        [ServiceBusTrigger("%{Nombre}QueueName%", Connection = "ServiceBusConnection")]
        string message,
        CancellationToken ct)
    {
        var request = JsonSerializer.Deserialize<{Nombre}Request>(message);
        await _{campo}.ExecuteAsync(request!, ct);
    }
}
```

- `%{Nombre}QueueName%` resuelve desde `appsettings.json` (clave
  `{Nombre}QueueName` con valor del nombre de la cola/Topic).
- `Connection = "ServiceBusConnection"` resuelve desde `appsettings.json` o
  Key Vault (string de conexión, no entity ID).
- Requiere paquete `APS.Messaging.ServiceBus` (ver `aps-packages`).

#### Event Grid trigger

```csharp
public class {Nombre}Function
{
    private readonly I{Nombre}Service _{campo};

    public {Nombre}Function(I{Nombre}Service {campo}) => _{campo} = {campo};

    [Function("{Nombre}Function")]
    public async Task RunAsync(
        [EventGridTrigger] EventGridEvent eventGridEvent,
        CancellationToken ct)
    {
        var data = eventGridEvent.Data.ToObjectFromJson<{Nombre}EventData>();
        await _{campo}.ExecuteAsync(data!, ct);
    }
}
```

- `EventGridEvent` viene del namespace `Microsoft.Azure.Functions.Worker`.
- Requiere paquete `APS.Messaging.EventGrid` (ver `aps-packages`).

#### Ubicación de artefactos para non-HTTP triggers

Igual que endpoint HTTP, pero sin Request/Response de presentación (el input
viene del binding, no del body HTTP). El árbol de decisión de FASE 2 se aplica
igual para Contracts/Impl/Tests.

```
*.Contracts/
  + ICS{Nombre}Service.cs     — interfaz del servicio
  + {Nombre}Request.cs        — modelo del input (deserializado del mensaje)
*.Impl/
  + CS{Nombre}Service.cs      — implementación
*.API/ (o *.Functions/)
  + {Nombre}Function.cs       — Function con trigger (sin HttpResponseData)
*.Test*/
  + CS{Nombre}ServiceTests.cs — tests del servicio (happy path + error)
```

> Si el trigger es un Timer (no hay input externo), `{Nombre}Request` no es
> necesario. El servicio recibe `CancellationToken` únicamente.

---

## Anti-patrones

- ❌ Crear un servicio nuevo sin haber pasado por FASE 1.5 (análisis de reutilización)
- ❌ Añadir parámetros de configuración hardcodeados en lugar de `IXxxOptions`
- ❌ Usar `IConfiguration` directamente en el servicio (debe inyectarse `IXxxOptions`)
- ❌ Crear DTOs en `*.Contracts/` cuando son exclusivos del endpoint
- ❌ Hacer commit sin haber pasado por FASE 5 (verificación)
- ❌ Saltarse la aprobación del plan (FASE 3) por ahorrar tiempo
- ❌ Olvidar registrar el servicio en `IoCExtensions.AddCSLevelBooking()`

---

## Cobertura de creación de endpoints

Anteriormente existía un skill dedicado `add-endpoint` que fue eliminado por redundancia:
crear un endpoint HTTP no es un refactor (no hay código previo que preservar) sino **creación
pura**, que es exactamente lo que cubre `add-feature`. Si el usuario describe un endpoint,
el orchestrator detecta que es un caso READ-ONLY o MUTATION de creación de feature y aplica
el árbol de decisión simplificado de este skill.

Invocar el command `/add-feature` y describir el endpoint (verbo HTTP, ruta, propósito) es
suficiente.
