---
name: project-structure
description: Detecta el tipo de solución APS y valida que su estructura de proyectos sea correcta antes de ejecutar cualquier refactor o generación de código. Cubre Functions, WebApp y NuGet library. Produce un informe de validación con severidades HARD_BLOCK, WARNING y PREGUNTA.
license: MIT
compatibility: opencode
metadata:
  audience: analyzer,orchestrator
  workflow: validation,refactor,scaffold
  stack: csharp,dotnet8,azure-functions,aspnetcore
---

## Qué hago
Valido que la estructura de proyectos de la solución sea correcta según su tipo antes de
ejecutar cualquier refactor o generación de código. Ejecutar esta validación antes del
análisis de impacto evita propagar cambios sobre una estructura incorrecta.

Úsame siempre como **primer paso** antes de analizar impacto o planificar cambios.

---

## § 1 — Detección del tipo de solución

Ejecuta estos pasos en orden. El primer resultado coincidente determina el tipo.

### 1.1 ¿Existe un proyecto `*.API/`?

Busca con Glob `src/*.API/**/*.csproj` o `src/*.API/`:

```
¿Existe src/*.API/?
├─ SÍ → ir a §1.2
└─ NO → tipo: NUGET_LIBRARY (ir a §2)
```

### 1.2 Identifica el tipo de host leyendo `Program.cs`

Lee `src/*.API/Program.cs` (o el equivalente en el proyecto encontrado):

```
¿Contiene FunctionsWorkerDefaults, AddAzureFunctionsWorker o IFunctionsWorkerMiddleware?
├─ SÍ → tipo: FUNCTIONS
└─ NO → ¿Contiene WebApplication.CreateBuilder o builder.WebHost?
    ├─ SÍ → tipo: WEBAPP
    └─ NO → tipo: AMBIGUO → registrar PREGUNTA para el orchestrator
```

### 1.3 ¿Hay Service Gateways en CrossCutting?

Lee el Layer Map de `AGENTS.md`. Si la capa `crosscutting` tiene proyectos listados:
- Examina sus `.csproj` buscando referencias a Refit, HttpClient generado o interfaz de client
- Si confirmas SG → activar validaciones §4

### Tipos resultantes

| Tipo | Descripción |
|---|---|
| `FUNCTIONS` | Azure Functions Isolated Worker |
| `WEBAPP` | ASP.NET Core WebApp / API Controllers / Minimal API |
| `NUGET_LIBRARY` | Solo class libraries, sin capa de presentación |
| `AMBIGUO` | No determinable → el orchestrator pregunta al usuario antes de continuar |

---

## § 2 — Estructura mínima requerida

### Por tipo de solución

| Tipo | Proyectos requeridos |
|---|---|
| `FUNCTIONS` | `src/*.Contracts/` + `src/*.Impl/` + `src/*.API/` |
| `WEBAPP` | `src/*.Contracts/` + `src/*.Impl/` + `src/*.API/` |
| `NUGET_LIBRARY` | `src/*.Contracts/` + `src/*.Impl/` |

Para cada proyecto requerido: verificar que el directorio existe Y que contiene al menos un `.csproj`.

**Severidad si falta**: `HARD_BLOCK` — el refactor no puede continuar hasta que se resuelva.

### Verificación de referencias entre proyectos

Para `FUNCTIONS` y `WEBAPP`, verificar que:
- `*.Impl.csproj` referencia `*.Contracts.csproj` (o el assembly de Contracts)
- `*.API.csproj` referencia `*.Impl.csproj` o `*.Contracts.csproj`

Si una referencia esperada falta → `WARNING`.

---

## § 3 — Organización del fichero de solución `.sln`

### ¿Existe un `.sln`?

Busca con Glob `*.sln` en raíz y en `local/`:

```
¿Existe *.sln?
├─ SÍ → ir a §3.1
└─ NO → registrar WARNING si hay más de 2 proyectos en src/
```

### 3.1 Verificar carpetas de solución

Lee el contenido del `.sln` y busca la sección `NestedProjects`:

```
¿Existe sección NestedProjects?
├─ SÍ → verificar que todos los proyectos tienen carpeta asignada (§3.2)
└─ NO → WARNING: "El .sln no tiene carpetas de solución; se recomienda organizarlo"
```

### 3.2 Convención de carpetas de solución

Las carpetas deben seguir el patrón `{N} - {Nombre de capa}`:
- `1 - Distributed Services` → proyectos `*.API/`
- `2 - Application` → proyectos `*.Contracts/`, `*.Impl/`
- `3 - Tests` → proyectos `*.Test*/`
- `9 - CrossCutting` → proyectos de Service Gateways y librerías transversales

Proyecto sin carpeta asignada en `NestedProjects` → `WARNING` (proyecto huérfano en el .sln).

---

## § 4 — Reglas de Service Gateway (activar si §1.3 detecta SG)

### 4.1 Contratos en el assembly correcto

Los contratos del SG (interfaces de client, modelos de request/response) deben vivir en el
assembly del SG, **no** en `*.Contracts/`.

Verificar: ¿hay tipos en `*.Contracts/` que solo use el SG y no el resto de la solución?
- Si sí → `WARNING`: "Posibles contratos del SG ubicados en *.Contracts/"

### 4.2 Workflow de publicación NuGet

Buscar en `.github/workflows/` un fichero que referencie el workflow
reutilizable `nuget-ci-publish.yml` de `APS-Framework/.github` o, en su
defecto, un paso de `dotnet pack` o `dotnet nuget push`:

```
¿Existe workflow de publicación para el SG?
├─ SÍ → OK
└─ NO → WARNING: "El SG no tiene workflow de publicación NuGet.
         Sugerir al usuario ejecutar /aps-new-workflow para generar
         el caller que invoca nuget-ci-publish.yml de
         APS-Framework/.github."
```

> Los workflows reutilizables viven en
> [`APS-Framework/.github`](https://github.com/APS-Framework/.github).
> Cada repo consumidor solo necesita un caller mínimo en
> `.github/workflows/publish.yml` que invoca
> `APS-Framework/.github/.github/workflows/nuget-ci-publish.yml@main`
> con `secrets: inherit`.

### 4.3 SG en el Layer Map

El SG debe estar listado en la capa `crosscutting` del Layer Map de `AGENTS.md`:

```
¿El SG aparece en AGENTS.md Layer Map?
├─ SÍ → OK
└─ NO → WARNING: "El SG no está registrado en el Layer Map de AGENTS.md"
```

---

## § 5 — Validaciones condicionales por tipo de solicitud

Aplica estas comprobaciones adicionales según lo que se haya pedido:

| Solicitud | Validación adicional | Severidad si falla |
|---|---|---|
| Nuevo endpoint / Function / Controller | El archivo destino debe estar en `src/*.API/` | WARNING |
| Nuevo modelo de dominio compartido | Debe ir en `src/*.Contracts/`, no en `*.API/` ni `*.Impl/` | WARNING |
| Nuevo response contract | ¿Hay SG? → SÍ: SG assembly; NO: `src/*.API/` (ver §5.1) | PREGUNTA si ambiguo |
| Nuevo Service Gateway | ¿Sigue naming convention del proyecto? ¿NuGet workflow a crear? | WARNING + acción |
| Refactor de interfaz pública | Verificar que todas las capas consumidoras existen | HARD_BLOCK si falta capa |
| Nuevo proyecto | ¿Naming convention `{Company}.{Domain}.{Sufijo}`? ¿Carpeta en .sln? | WARNING |

### 5.1 Árbol de decisión para response contracts

```
¿Existe un SG en CrossCutting que exponga los endpoints de *.API/?
├─ SÍ → el response contract va en el assembly del SG (CrossCutting)
│        NO en *.API/ ni en *.Contracts/
└─ NO → el response contract va en *.API/
         NO en *.Contracts/ (es exclusivo de la presentación)
```

---

## § 6 — Casos que el orchestrator debe preguntar al usuario

Antes de continuar, el orchestrator debe hacer una pregunta explícita al usuario si:

| Caso | Pregunta sugerida |
|---|---|
| Tipo `AMBIGUO` (§1.2) | "No puedo determinar el tipo de host. ¿Es una Azure Function, una WebApp, o una librería NuGet?" |
| Nuevo contrato de dudosa ubicación | "¿Este tipo es de dominio compartido (→ Contracts) o exclusivo de un endpoint (→ API o SG)?" |
| `.sln` inexistente con múltiples proyectos | "¿Existe un fichero `.sln` fuera de `src/` que deba considerar?" |
| SG detectado pero sin entrada en Layer Map | "He detectado un posible SG en CrossCutting no registrado. ¿Confirmas que es un SG publicado como NuGet?" |

---

## § 7 — Formato del informe de validación

Incluye siempre esta sección en tu output antes del análisis de impacto:

```
### Validación de estructura

Tipo de solución detectado: [FUNCTIONS | WEBAPP | NUGET_LIBRARY | AMBIGUO]

Estructura mínima:
- src/*.Contracts/  [OK | HARD_BLOCK: no encontrado]
- src/*.Impl/       [OK | HARD_BLOCK: no encontrado]
- src/*.API/        [OK | HARD_BLOCK: no encontrado | N/A (NUGET_LIBRARY)]

Organización .sln:  [OK | WARNING: <detalle> | N/A: no existe .sln]

Service Gateway:    [N/A | OK | WARNING: <detalle>]

Validaciones condicionales (según solicitud):
- [OK | WARNING | PREGUNTA: <detalle>]

Estado global: [OK — continuar | WARNING — continuar con aviso | HARD_BLOCK — detener | PREGUNTA — esperar respuesta del usuario]
```

---

## Severidades y acciones

| Severidad | Significado | Acción del orchestrator |
|---|---|---|
| `OK` | Todo correcto | Continuar |
| `WARNING` | Anomalía no bloqueante | Informar al usuario, preguntar si continuar |
| `HARD_BLOCK` | Estructura inválida, refactor no viable | Detener. No invocar workers hasta que se resuelva |
| `PREGUNTA` | Información insuficiente para decidir | Preguntar al usuario antes de continuar |
