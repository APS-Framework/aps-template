# Sistema de Refactor con Agentes

Guía de uso del sistema de agentes OpenCode para ejecutar refactors grandes de forma segura
en proyectos APS.

> **Esta es documentación de referencia para humanos.** Los workflows que el orchestrator
> ejecuta viven en `.opencode/skills/` y se cargan bajo demanda. Si quieres que el agente
> actúe, usa los comandos listados abajo; si quieres entender cómo funciona el sistema,
> sigue leyendo.

---

## Comandos disponibles

| Comando | Skill cargado | Cuándo usarlo |
|---|---|---|
| `/refactor-plan <descripción>` | `refactor-protocol` (fase analyze) | Siempre primero. Análisis de impacto sin tocar ningún archivo. |
| `/refactor-start [descripción]` | `refactor-protocol` o `multi-phase-refactor` | Ejecuta el refactor. El orchestrator decide el modo de ejecución tras el análisis. |
| `/refactor-verify` | `refactor-protocol` (fase verify) | Recuperación: retoma la verificación si la sesión del orchestrator fue interrumpida. |
| `/add-feature <descripción>` | `add-feature` | Crea una funcionalidad nueva (endpoint, servicio, job, config) con análisis de reutilización. Cubre también la creación de endpoints HTTP. |
| `/investigate-bug <descripción>` | `bug-investigation` | Investiga y corrige un bug con reproducción automatizada. Incluye limpieza OBLIGATORIA de instrumentación. |

---

## Flujo de trabajo habitual

```
1. /refactor-plan "descripción del cambio"
      ↓
   Revisar el informe de impacto
      ↓
2. (aprobar) /refactor-start
      ↓
   El orchestrator presenta el modo recomendado y el plan
      ↓
   (aprobar) Ejecución delegada por capas
      ↓
   Verificación + propuesta de commit
```

**Regla de oro**: nunca ejecutar `/refactor-start` sin haber leído el output de `/refactor-plan`.

---

## El informe de impacto (`/refactor-plan`)

El analyzer produce un informe estructurado con estas secciones:

### Validación de estructura
Verifica que el proyecto cumple la estructura mínima esperada (capas presentes, `.sln` organizado,
Service Gateways correctamente ubicados). Los estados posibles son:

| Estado | Qué significa | Qué hacer |
|---|---|---|
| `OK` | Estructura correcta | Continuar |
| `WARNING` | Algo no ideal pero no bloqueante | Revisar el aviso; el orchestrator preguntará si continuar |
| `HARD_BLOCK` | Problema estructural que impediría el refactor | Resolver antes de continuar |
| `PREGUNTA` | El analyzer necesita información adicional | Responder las preguntas planteadas |

### Tipo de refactor
Clasifica el cambio en una de estas categorías:

- `INTERFACE_RENAME` — Renombrado de interfaz o contrato público
- `INTERFACE_EXTEND` — Nuevo miembro en interfaz existente
- `PATTERN_ADOPTION` — Introducción de nuevo patrón arquitectónico
- `CONVENTION_MIGRATION` — Migración de convención interna (async suffix, nullable, naming)
- `IMPL_ONLY` — Cambio limitado a implementaciones, sin tocar interfaces

### Archivos afectados por capa
Lista detallada con el motivo de cada archivo (declara / implementa / referencia el símbolo
afectado). Revisar esta lista antes de aprobar la ejecución.

### Cobertura de tests y gaps
Identifica qué elementos afectados **no tienen cobertura adecuada**:

| Severidad | Qué significa |
|---|---|
| `CRÍTICO` | Método público de interfaz en `*.Contracts/` sin test end-to-end |
| `ALTO` | Clase de `*.Impl/` con lógica de negocio sin test unitario |
| `MEDIO` | Método privado o helper sin test |
| `BAJO` | Código de infraestructura/plumbing sin test |

Si hay gaps `CRÍTICO` o `ALTO`, el orchestrator recomendará el **modo multi-fase** con tests
de caracterización antes de tocar código.

### Estrategia de ejecución recomendada
El analyzer recomienda una de estas estrategias:

- **Secuencial estricto**: cambios en Contracts primero, luego CrossCutting si aplica, luego Impl+Presentation, finalmente Tests
- **Contracts-first + paralelo**: Contracts en solitario, luego el resto en paralelo
- **Paralelo total**: todos los workers simultáneamente (para migraciones de convención)
- **Solo Impl+Tests**: cuando Contracts no cambia

### Nivel de riesgo
`BAJO` / `MEDIO` / `ALTO` según número de archivos, capas afectadas y presencia de dependencias externas.

---

## Modos de ejecución (`/refactor-start`)

El orchestrator evalúa el informe y elige el modo adecuado. Si recomienda multi-fase, lo presenta
al usuario con justificación y espera confirmación antes de continuar.

### Modo simple (refactor simple)
Para cambios de riesgo BAJO o MEDIO con una sola área semántica afectada.

```
[ANÁLISIS]     ✓  12 archivos en 2 capas — Estrategia: Impl + Tests paralelo
[PLAN]         ✓  Impl + Tests en paralelo — ¿Proceder?
[EJECUCIÓN]    Impl ✓ | Tests ✓
[VERIFICACIÓN] dotnet build ✓ | dotnet test ✓ (47 tests)
[COMMIT]       Listo → "refactor(impl): extract IOperationDispatcher from OperationResolver"
```

### Modo multi-fase
Se recomienda cuando:
- Riesgo ALTO y ≥ 30 archivos afectados
- El cambio toca ≥ 2 áreas semánticas distintas en `*.Contracts/`
- Hay gaps de cobertura `CRÍTICO` o `ALTO`

**Fases del protocolo multi-fase**:

#### PREFLIGHT — Tests de caracterización
Si hay gaps de cobertura, el worker de tests crea **tests de caracterización** antes de tocar
código de producción. Estos tests documentan el comportamiento observable actual del código y
actúan como red de seguridad. Se commitean en un commit separado:
```
test(characterization): add characterization tests for OperationResolver, OperationServiceBase
```

#### Fase N — Refactor por etapas
El orchestrator descompone el refactor en fases lógicas y presenta la lista completa al usuario
para aprobación antes de comenzar. Cada fase muestra:
- Capas y archivos afectados
- Criterios de aprobación específicos (tests nombrados que deben pasar)

El verifier valida cada fase con `dotnet test --filter` sobre los tests nombrados antes de pasar
a la siguiente.

#### FINAL — Verificación global y commit único
Una vez todas las fases han pasado, el verifier ejecuta el suite completo y propone un único
commit descriptivo con el resumen de todas las fases.

---

## Verificación y commit

El `refactor-verifier` ejecuta siempre:

1. `dotnet build` — si falla, para aquí y reporta los errores con la capa probable
2. `dotnet test --logger "console;verbosity=detailed"` — reporta tests fallidos con stack trace
3. En modo multi-fase: `dotnet test --filter` para cada criterio nombrado de la fase
4. `git diff --stat` — resumen de archivos modificados
5. Propuesta de commit en formato convencional

**El commit nunca se ejecuta automáticamente.** El orchestrator lo propone y espera confirmación
explícita del usuario.

---

## Cuando algo falla

### El verifier reporta FAIL en build
El orchestrator identifica la capa responsable y re-invoca el worker correspondiente con
instrucciones de corrección. Si falla por segunda vez, recomienda revertir.

### El verifier reporta FAIL en tests
Misma lógica: re-invoca el worker de la capa que introdujo la regresión. Si falla dos veces,
recomienda `git restore <archivos>` para los archivos de esa capa.

### La sesión del orchestrator fue interrumpida
Si el código ya está modificado pero no hay commit, usar `/refactor-verify` para retomar desde
la verificación sin relanzar el orchestrator completo.

**Persistencia de sesión**: los refactors grandes (especialmente los multi-fase) persisten su
progreso en `.opencode/plans/<slug>/state.md` siguiendo el protocolo de la skill
`refactor-session`. Si la sesión se cancela o se interrumpe, el siguiente agente que detecte
esos archivos preguntará al usuario si desea reanudar. **No perder el contexto entre sesiones
es responsabilidad del orchestrator**, no del usuario.

### Revertir todo
```bash
git restore .
```
O usar `/undo` en OpenCode si la sesión está activa.

---

## Capas del proyecto

> Los paths exactos de cada capa los define el **Layer Map** en `AGENTS.md` del repo
> concreto. La tabla siguiente usa la convención estándar APS:

| Layer | Path (convención) | Rol |
|---|---|---|
| `contracts` | `src/{Proyecto}.Contracts/` | Interfaces, modelos, requests/responses, excepciones |
| `crosscutting` | `src/{SG-1}/`, `src/{SG-2}/`, ... | Service Gateways y librerías transversales (ver AGENTS.md) |
| `impl` | `src/{Proyecto}.Impl/` | Servicios, operaciones, mappers, comparers |
| `presentation` | `src/{Proyecto}.API/` | Azure Functions, Controllers ASP.NET Core, entry points HTTP/Timer |
| `tests` | `src/{Proyecto}.Test*/` | Tests unitarios MSTest v3 + NSubstitute + Shouldly |

**Orden de dependencias**:
```
Presentation
     ↓
Impl  ←──  CrossCutting
     ↓          ↓
  Contracts ←───┘
     ↑
   Tests
```

Si `Contracts` cambia, los workers se ejecutan en este orden: Contracts → CrossCutting (si aplica)
→ Impl + Presentation (paralelo) → Tests. Este orden nunca se invierte.

---

## Notas sobre Service Gateways

Los contratos de un Service Gateway (SG) viven en el **propio assembly del SG**, no en
`*.Contracts/`. Si el refactor modifica la API pública de un SG, el orchestrator lo indica
explícitamente y el workflow de publicación de la nueva versión NuGet debe gestionarse por
separado al commit.
