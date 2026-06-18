---
description: Anade un paquete APS Framework a un proyecto existente y configura el wiring basico. Uso: /aps-add-package <paquete> [ruta]
agent: aps-scaffolder
model: anthropic/claude-sonnet-4-20250514
---

# /aps-add-package

Anade un paquete del ecosistema APS Framework (o CS Level) a un proyecto
.NET existente y deja la configuracion minima necesaria para usarlo.

## Argumentos

- `$1` (obligatorio) = nombre del paquete (p.ej. `APS.Data.Blob`,
  `APS.Messaging.EventGrid`, `CS.Adyen.Client`, `Resiber.Native.Client`).
- `$2` (opcional) = ruta al `.csproj` destino. Si se omite, buscar el
  unico `.csproj` en el directorio actual. Si hay varios, preguntar.

## Comportamiento

1. **Detectar tipo de proyecto** leyendo el `.csproj`:
   - `Microsoft.Azure.Functions.Worker.Sdk` -> Function App
   - `Microsoft.NET.Sdk.Web` -> Web App
   - Si no es ninguno, **abortar y avisar** de que el comando solo soporta
     Functions y Web Apps.

2. **Cargar skills**:
   - `aps-packages` (para confirmar el nombre y agrupar con dependencias)
   - `aps-conventions` (para reglas de codigo y `NuGet.config`)
   - `aps-function-template` o `aps-webapp-template` (segun tipo) para
     ver como se registran servicios en el `Program.cs`

3. **Verificar `NuGet.config`**: si no existe en la raiz del repo, crearlo
   (ver skill `aps-conventions`).

4. **Anadir el paquete**:
   ```bash
   dotnet add [csproj] package [paquete]
   ```

5. **Configurar el wiring** en `Program.cs`:
   - Function App: anadir el `Add...` correspondiente (p.ej.
     `builder.Services.AddApsBlob(builder.Configuration)`) en el bloque
     de `builder.Services`.
   - Web App: anadir el equivalente y, si es un middleware, registrar
     `app.Use...()` despues de `app.UseApsErrorMiddleware()`.
   - Si el paquete es un cliente Refit (p.ej. `CS.Adyen.Client`,
     `APS.ServiceGateway`), anadir la interfaz con su extension de
     registro (p.ej. `AddApsServiceGatewayClient<ICliente>(...)`).
   - Si no sabes la extension exacta, **preguntar al usuario** o dejar
     un comentario `// TODO: configurar {paquete}` en `Program.cs`.

6. **Si el handler de ejemplo no existe o no usa el paquete**, anadir un
   endpoint basico en `Functions/SampleFunction.cs` o
   `Controllers/SampleController.cs` que demuestre el uso del paquete
   (incluso aunque sea trivial, p.ej. una llamada `await client.PingAsync()`).

7. **Anadir test minimo** que verifique que el wiring compila y se
   puede instanciar la nueva dependencia.

8. **Verificar**:
   ```bash
   dotnet restore [csproj]
   dotnet build [csproj]
   ```

## Reglas duras

- **No** anadir paquetes que no esten en `aps-packages` sin avisar al usuario.
- **No** modificar otros proyectos del repo.
- **No** reemplazar el handler existente: si ya hay uno, solo anadir
  el wiring y un endpoint nuevo o una llamada adicional.
- **No** hacer commit ni push.

## Ejemplos de uso

```
/aps-add-package APS.Data.Blob
/aps-add-package APS.Messaging.EventGrid src/MyFunction/MyFunction.csproj
/aps-add-package CS.Adyen.Client
/aps-add-package Resiber.Native.Client src/Booking/Booking.csproj
```
