---
name: bug-investigation
description: Protocolo para investigar y corregir bugs mediante reproducción automatizada. Cubre la recopilación del informe de bug, la búsqueda de la ruta de código, la elección de estrategia de reproducción (test vs runtime), la instrumentación temporal, el ciclo iterativo de hipótesis-validación y la limpieza OBLIGATORIA de todo código de debug. El orchestrator debe cargar este skill cuando se reporte un bug que requiera reproducir el comportamiento para entender su causa raíz.
license: MIT
compatibility: opencode
metadata:
  audience: orchestrator
  workflow: investigation, debugging
  stack: csharp,dotnet8,azure-functions,aspnetcore
---

## Qué hago

Guío al orchestrator a través del ciclo completo de investigación de un bug: reproducir el
comportamiento, inspeccionar valores, hipotetizar la causa, aplicar el fix mínimo y dejar el
repositorio **exactamente como estaba antes** (sin instrumentación residual).

**Cuándo usar este skill**:
- Usuario reporta un bug con un input concreto y un output inesperado
- Se necesita reproducir el comportamiento para entender la causa raíz
- El bug no es evidente solo leyendo el código (depende de valores en runtime)

**Cuándo NO usar este skill** (usar `refactor-protocol`):
- El bug es obvio y el fix se deduce por inspección
- Es un cambio de comportamiento intencional (no es bug, es feature)

---

## ⚠️ LIMITACIÓN FUNDAMENTAL — Leer antes de empezar

**Este skill es un asistente de debugging automatizado, NO un debugger interactivo.**

No sustituye a Visual Studio / Rider / VS Code para casos donde necesites:
- Stepping línea a línea con breakpoints
- Ventanas de Watch / Locals / Autos
- Modificación de variables en tiempo de ejecución
- Hot-reload sin recompilar

Conceptualmente, este skill hace **lo mismo que un developer haría con `Console.WriteLine` y
volver a compilar cada vez**, pero de forma automatizada y con disciplina sobre la limpieza.

| Capacidad | Disponible | Notas |
|---|---|---|
| Reproducir bug como test que falla | ✅ | Vía MSTest, ideal para bugs de lógica |
| Capturar valores de variables | ✅ | Vía `Console.WriteLine`, `ICustomEventService.SetMessage` |
| Levantar Azure Functions localmente | ✅ | `dotnet run` + `curl` |
| Iterar hipótesis-fix-validación | ✅ | Hasta 5 iteraciones, después escala al usuario |
| Comparar antes/después | ✅ | Snapshot del output |
| Stepping interactivo con breakpoints | ❌ | No soportado |
| Modificar variables en runtime | ❌ | Requiere recompilar |
| Streams de log persistentes | ❌ | El shell tool no es interactivo |

---

## FASE 0 — Recopilación del informe de bug

El orchestrator extrae o pregunta los siguientes datos. **No continuar sin tener al menos los
cuatro primeros**.

| Dato | Origen | Obligatorio |
|---|---|---|
| Descripción del síntoma | Usuario | ✅ |
| Input que reproduce el bug | Usuario / logs | ✅ |
| Output esperado vs actual | Usuario / logs | ✅ |
| Frecuencia (siempre / intermitente / primer caso) | Usuario | ✅ |
| Entorno donde se observa (dev / staging / prod) | Usuario | Recomendado |
| Logs relevantes (stack trace, mensajes) | Usuario / AppInsights | Recomendado |
| Hipótesis inicial del usuario (si la hay) | Usuario | Opcional |

Si el usuario no tiene logs ni el input exacto, **preguntar antes de continuar**. No improvisar
un escenario.

---

## FASE 1 — Análisis del código relacionado

Objetivo: identificar la ruta de código que produce el síntoma antes de tocar nada.

### Pasos

1. **Buscar por palabras clave del síntoma**:
   ```
   grep "<mensaje de error>" src/
   grep "<nombre de campo/operación afectado>" src/
   ```
2. **Identificar el método de entrada**: ¿es un endpoint HTTP? ¿un job? ¿un evento?
3. **Rastrear la cadena de llamadas** desde el método de entrada hasta donde se sospecha
   el bug (lectura del código, no ejecución)
4. **Listar archivos relevantes** con la línea donde se sospecha el bug

### Salida esperada

Una lista corta (1-5 archivos) con paths y líneas relevantes. **No continuar si la lista es
vacía o demasiado vaga** — eso indica que falta info en FASE 0.

---

## FASE 1.5 — PREFLIGHT de tests de regresión (obligatorio)

**Objetivo**: antes de aplicar cualquier fix, verificar que los componentes
afectados (incluyendo los tangenciales identificados en FASE 1) tienen
cobertura de tests. Si no la tienen, crearla **antes** de tocar el código.

### Pasos

1. **Identificar superficie afectada**: a partir de FASE 1, listar:
   - El método/clase donde se sospecha el bug
   - Los métodos que lo llaman (call sites identificados en el rastreo)
   - Cualquier componente tangencial que pueda verse afectado por el fix

2. **Para cada componente afectado**:
   - Buscar tests en `src/*.Test*/**` que lo ejerciten
   - Si tiene cobertura → OK, esos tests serán la red de regresión
   - Si **no** tiene cobertura → crear tests de caracterización:
     - Documentar el comportamiento **actual** (incluyendo el bug) con
       tests que pasen en verde hoy
     - Invocar `@refactor-worker-tests` para crearlos
     - Invocar `@refactor-verifier` para confirmar que pasan
     - Commit separado:
       ```
       test(characterization): add characterization tests for <clases>
       ```

3. **Estos tests de caracterización sirven como doble red**:
   - Confirmarán que el fix resuelve el bug (el test del bug se actualiza
     para esperar el output correcto)
   - Confirmarán que no se rompe nada más (regresión)

> **Si el usuario no aprueba la creación de tests de caracterización cuando
> hay gaps**, la investigación **no puede continuar** al fix. Informar del
> riesgo de aplicar un fix sin red de seguridad.

Elegir UNA estrategia antes de continuar. Cada una tiene trade-offs.

### 2.1 — Test unitario (preferida)

**Usar cuando**:
- El bug es de lógica pura
- El input es reproducible con mocks
- El método de sospecha es testeable aisladamente

**Cómo**:
1. Identificar el proyecto de test donde crear el test (`*.Test/`)
2. Crear un test que reproduzca el input del bug
3. Ejecutar: `dotnet test --filter "FullyQualifiedName~<TestName>" --logger "console;verbosity=detailed"`
4. Si falla con el output actual → bug reproducido ✓
5. Si pasa → el test no reproduce; revisar FASE 1

**Ventaja**: rápido, determinista, puede ejecutarse en bucle.

### 2.2 — Test de integración con Functions runtime

**Usar cuando**:
- El bug requiere el pipeline completo de Azure Functions
- El método de entrada es un endpoint HTTP
- El bug involucra middleware, autenticación o routing

**Cómo**:
1. Levantar el host en background: `dotnet run --project src/{Proyecto}.API/`
   (capturar output a un archivo de log)
2. Identificar un endpoint que dispare la operación sospechosa
3. Golpear con curl: `curl -X POST http://localhost:7071/api/<endpoint> -d '<body>'`
4. Leer el log del proceso para capturar el comportamiento

**Ventaja**: prueba todo el pipeline. **Desventaja**: proceso en background, hay que leer logs de archivo.

### 2.3 — Solo inspección de código (sin reproducción)

**Usar cuando**:
- El bug es determinista y evidente
- El usuario solo quiere confirmar la causa antes de aplicar el fix

**Cómo**: análisis estático, sin ejecutar nada. Pasar directamente a FASE 5 con el fix.

**Esta estrategia no requiere FASE 3 ni FASE 4**.

### 2.4 — Reproducción estadística (bugs intermitentes)

**Usar cuando**:
- El bug es intermitente (a veces pasa, a veces no)
- FASE 2.1 no reproduce el bug en una sola ejecución
- Se sospecha race condition, caching, o dependencia de estado acumulado

**Cómo**:
1. Crear el test de FASE 2.1 que **debería** reproducir el bug
2. Ejecutarlo en bucle N veces (empezar con N=50):

   ```bash
   for i in $(seq 1 50); do
     dotnet test --filter "FullyQualifiedName~<TestName>" --logger "console;verbosity=minimal" 2>&1 | tail -5
   done
   ```

   O en PowerShell:
   ```powershell
   1..50 | ForEach-Object {
     dotnet test --filter "FullyQualifiedName~<TestName>" --logger "console;verbosity=minimal" 2>&1 | Select-Object -Last 5
   }
   ```

3. Contar cuántas veces falla vs pasa:
   - **0 fallos / 50**: el test no reproduce el bug. Revisar FASE 1 o aumentar N.
   - **1-5 fallos / 50**: reproducción intermitente confirmada. El patrón de
     fallo puede revelar la condición (ej: falla siempre en la iteración 3 →
     estado acumulado; falla aleatorio → race condition).
   - **>40 fallos / 50**: reproducción casi-determinista. Tratar como FASE 2.1.

4. Si se reproduce, añadir `[TestMethod]` con `[RetryAttribute]` o un bucle
   interno para capturar el fallo en una sola ejecución de `dotnet test`:

   ```csharp
   [TestMethod]
   public async Task BugRepro_Intermittent_CapturesFailure()
   {
       for (int i = 0; i < 100; i++)
       {
           try
           {
               // ... código que debería reproducir el bug ...
               // Si llega aquí sin fallo en 100 intentos, el bug no se reprodujo
           }
           catch (Exception ex) when (ex.Message.Contains("<síntoma esperado>"))
           {
               // Bug reproducido en iteración {i}
               Assert.Fail($"Bug reproducido en iteración {i}: {ex.Message}");
           }
       }
   }
   ```

**Ventaja**: puede reproducir bugs que FASE 2.1 no detecta en una sola pasada.
**Desventaja**: lento (50+ ejecuciones de test), no determinista, el output es
voluminoso — usar `--verbosity=minimal` y capturar solo el resumen.

> **Señal de pausa**: si después de 200 ejecuciones no se reproduce, escalar al
> usuario. El bug puede requerir condiciones de entorno específicas (staging,
> carga, datos concretos) que no se pueden simular en local.

---

## FASE 3 — Instrumentación temporal (solo si FASE 2.1 o 2.2)

> ### ⚠️ TODO el código añadido en esta fase es TEMPORAL
>
> **Regla HARD**: debe ser eliminado en FASE 5.2 antes de hacer commit.
> El orchestrator debe trackear cada línea de instrumentación añadida para verificar su
> eliminación completa.

### Opciones de instrumentación (de menos a más invasiva)

| Opción | Cuándo usar | Código típico |
|---|---|---|
| `ITestContext.WriteLine` | En tests MSTest | `TestContext.WriteLine($"value={x}");` |
| `Console.WriteLine` | En código de producción (temporal) | `Console.WriteLine($"DEBUG: x={x}");` |
| `ICustomEventService.SetMessage` | En Functions (telemetría) | `_context.SetMessage(true, $"DEBUG: x={x}");` |
| Breakpoints via `Debugger.Break()` | Solo en local, **no commitear nunca** | `if (x > 100) System.Diagnostics.Debugger.Break();` |

**Preferencia**: empezar por `ITestContext.WriteLine` o `Console.WriteLine` antes de tocar
`ICustomEventService` (que es código de producción compartido).

### Tracking obligatorio

El orchestrator mantiene una lista en memoria de TODAS las líneas de instrumentación añadidas:

```
[INSTRUMENTACIÓN AÑADIDA — FASE 3]
- src/{Proyecto}.Impl/Services/XxxService.cs:42 → Console.WriteLine($"DEBUG total={total}")
- src/{Proyecto}.Impl/Services/XxxService.cs:67 → Console.WriteLine($"DEBUG op={op}")
- src/{Proyecto}.Test/Services/XxxServiceTests.cs:23 → TestContext.WriteLine(...)
```

Esta lista se usará en FASE 5.2 para verificar eliminación completa.

---

## FASE 4 — Ciclo hipótesis-validación

Iterar hasta reproducir el bug y entender la causa. **Máximo 5 iteraciones**.

### Estructura de cada iteración

```
Iteración N:
  1. HIPÓTESIS: "Creo que el bug está en [lugar] porque [razonamiento]"
  2. INSTRUMENTO: añadir log específico en la línea sospechada
  3. EJECUTO: dotnet test [...] --logger "console;verbosity=detailed"
  4. OBSERVO: el output muestra [valor real] vs [valor esperado]
  5. CONCLUYO:
     · Si la observación confirma la hipótesis → pasar a FASE 5 con el fix
     · Si no la confirma → siguiente iteración con hipótesis refinada
```

### Reglas del ciclo

- **Una hipótesis por iteración** (no acumular variables)
- **Máximo 5 iteraciones**; si no converge, escalar al usuario con la información recogida
- **Anotar cada iteración** en el plan de sesión (o en el archivo `.opencode/plans/<slug>/state.md`
  si se está usando `refactor-session`)

---

## FASE 5 — Fix y limpieza (REQUISITO HARD)

> ### ⚠️ Esta fase es la más importante del skill
>
> El éxito de la investigación se mide por que **el repositorio quede limpio** después.
> Ningún commit de fix de bug debe contener `Console.WriteLine`, `TestContext.WriteLine` o
> cualquier otra instrumentación añadida durante FASE 3.

### 5.1 — Aplicar el fix mínimo

- Regla: el fix debe ser el **menor cambio** que resuelve el bug
- Si el fix requiere refactorizar más → escalar al usuario (considerar `refactor-protocol`)
- Aplicar el fix exactamente en la línea identificada en FASE 4

### 5.2 — Limpieza de instrumentación (NO NEGOCIABLE)

Ejecutar esta lista de verificación **antes de hacer commit**:

```
[CHECKLIST DE LIMPIEZA — FASE 5.2]

Búsqueda de Console.WriteLine / Debug.WriteLine / TestContext.WriteLine:
  Comando: grep -rn "Console.WriteLine\|Debug.WriteLine\|TestContext.WriteLine" src/ --include="*.cs"
  Esperado: NINGÚN resultado (excepto los Console.WriteLine preexistentes que NO son de esta investigación)

Búsqueda de Debugger.Break:
  Comando: grep -rn "Debugger.Break" src/ --include="*.cs"
  Esperado: NINGÚN resultado

Búsqueda de comentarios DEBUG/TEMP/INVESTIGACIÓN:
  Comando: grep -rn "// DEBUG\|// TEMP\|// INVESTIG\|// INVESTIGACION" src/ --include="*.cs"
  Esperado: NINGÚN resultado

Búsqueda de _context.SetMessage con prefijo DEBUG:
  Comando: grep -rn 'SetMessage.*DEBUG' src/ --include="*.cs"
  Esperado: NINGÚN resultado (o solo los legítimos del proyecto)
```

**Si CUALQUIER búsqueda devuelve resultados que sean de esta investigación, NO proceder al commit.
Limpiar primero y volver a verificar.**

### 5.3 — Verificar que el fix funciona (criterio de cierre)

Para dar por correcta la investigación, deben pasar **AMBOS** conjuntos de tests:

1. **Test del bug** (FASE 2.1 / 2.2 / 2.4): actualizado para esperar el output
   correcto → debe pasar en verde
2. **Tests de caracterización** (FASE 1.5, si se crearon): deben seguir pasando
   (confirman que el fix no rompe el comportamiento existente)
3. **Suite completa del proyecto afectado**: `dotnet test` → no debe haber
   regresiones en tests existentes

Si cualquiera falla, el fix **no puede cerrarse**. Identificar si es un problema
del fix (revisar FASE 5.1) o un test que necesita actualización (el fix cambió
un comportamiento que el test documentaba incorrectamente).

4. Si `refactor-session` está activo, actualizar el archivo `.opencode/plans/<slug>/state.md` con:
   - Iteraciones realizadas
   - Causa raíz identificada
   - Diff del fix aplicado
   - Confirmación de checklist de limpieza
   - Confirmación de tests nuevos + regresión en verde

---

## FASE 6 — Commit y cierre

### Formato del commit

```
fix(<scope>): <síntoma breve en imperativo>

- Root cause: <descripción técnica de la causa raíz>
- Fix: <descripción del cambio mínimo aplicado>
- Repro: <nombre del test que reproduce el bug>

(ejemplo)
fix(operations): refund total ignores multiple documents when summing

- Root cause: ExecuteBankRefund only summed the first refunded document
- Fix: replace .FirstOrDefault() with .Sum() over all RefundedDocuments
- Repro: CSRefundOperationServiceTests.RefundTotal_WhenMultipleDocuments_ThenSumsAll
```

### Cierre

- Si `refactor-session` está activo, marcar el plan como `COMPLETED`
- Si la causa raíz revela un patrón de bug recurrente, considerar crear un test de regresión
  en el módulo de tests del proyecto

---

## Anti-patrones

- ❌ **Hacer commit con `Console.WriteLine` o similar aún en el código** — es el anti-patrón #1
- ❌ **Aplicar un fix que va más allá del bug** ("ya que estoy aquí, refactorizo...")
- ❌ **Borrar tests que fallan en lugar de arreglarlos** durante la investigación
- ❌ **Añadir `try/catch` que silencian la excepción** para "arreglar" el síntoma
- ❌ **Hacer más de 5 iteraciones de hipótesis** sin escalar al usuario
- ❌ **Modificar la instrumentación durante la investigación sin actualizar la lista de tracking**
- ❌ **Olvidar el `[Theory]` o `[DataRow]`** que documenta los inputs del bug
- ❌ **Ejecutar `dotnet test` sin `--logger "console;verbosity=detailed"`** cuando se busca output de debug

---

## Señales de pausa

El orchestrator debe pausar y consultar al usuario cuando:

- El bug no es reproducible después de 5 iteraciones
- El fix mínimo requeriría cambiar la signatura de un método público
- El usuario no tiene el input exacto que reproduce el bug
- La causa raíz revela un problema de diseño más profundo (considerar `refactor-protocol`)
- El repositorio no compila antes de empezar la investigación (resolver primero)

---

## Relación con otros skills

| Skill | Cuándo |
|---|---|
| `refactor-protocol` | Si el fix requiere cambios estructurales mayores (firmas, refactor de patrón) |
| `add-feature` | Si el "bug" resulta ser una funcionalidad que nunca existió (no es bug) |
| `refactor-session` | Si se quiere persistir el progreso de la investigación en `.opencode/plans/<slug>/state.md` |

---

## Anti-patrón crítico: instrumentación residual

> **Si un commit de fix de bug contiene `Console.WriteLine`, `TestContext.WriteLine`,
> `Debugger.Break` o cualquier marcador de debug añadido durante la investigación,
> el commit debe ser rechazado por el orchestrator.**
>
> El éxito de un fix de bug no se mide solo por que el bug desaparezca, sino por que el
> repositorio quede **exactamente como estaba antes** (más el fix, menos el bug).
