---
name: refactor-protocol
description: Protocolo completo para ejecutar refactors grandes y seguros en proyectos APS multi-capa. Cubre el flujo de tres fases, el árbol de decisión para ejecución paralela vs secuencial, playbooks por tipo de refactor (renombrado de interfaz, extensión de interfaz, adopción de patrón, migración de convenciones), y procedimiento de rollback.
license: MIT
compatibility: opencode
metadata:
  audience: orchestrator,developer
  workflow: refactor
  stack: csharp,dotnet8,azure-functions
---

## Qué hago
Proveo el protocolo completo para ejecutar refactors grandes de forma segura en proyectos APS
con arquitectura multi-capa (Contracts → Impl/API → Tests). Úsame cuando el refactor afecte
más de 5 archivos, cruce más de una capa, o toque interfaces públicas en Contracts.

---

## Uso del MCP en el proceso de refactor

Los proyectos APS exponen a través del MCP documentación actualizada de sus paquetes de
framework y conectores externos. Cada agente debe **descubrir y usar las tools relevantes
en tiempo de ejecución**, sin depender de una lista estática de nombres de tools: en cada
proyecto el MCP puede exponer tools diferentes.

### Convención de tiers del MCP

Los paquetes APS expuestos en el MCP organizan sus tools por **tiers**. La
convención general es:

| Tier aproximado | Patrón de sufijo | Cuándo invocar |
|------|--------|---------------|
| **setup** | `*__setup*` | Al registrar el paquete en DI o configurar el host builder |
| **api** | `*__api*` | Al **generar o modificar código** que usa las interfaces del paquete |
| **sdk** | `*__readme_sdk`, `*__sdk`, `*__docs_sdk` | Al necesitar entender qué hace el paquete o cómo instalarlo |
| **dev** | `*__readme_dev`, `*__dev`, `*__docs_dev` | Solo cuando se va a modificar el paquete internamente |
| **ops git/ci** | `*__git_ops`, `*__publish`, `*__deploy_*` | Operaciones de git, publicación NuGet, deploy a Azure |
| **docs** | `*__docs`, `*__docs_sdk`, `*__docs_dev` | Generar o revisar documentación (README-sdk, README-dev) |
| **dominio** | `*__patterns`, `*__soap`, `*__wsdl`, `*__examples`, etc. | Casos específicos del paquete |

> **Esta tabla es orientativa**. Los paquetes pueden añadir tiers específicos
> no listados aquí. **La fuente de verdad es la descripción de cada tool en
> el MCP**: cada una indica explícitamente su caso de uso
> ("LLAMAR para: ...", "SIEMPRE que se genere código de ...").
>
> **No reproducir** el contenido de las tools en los skills/agents:
> invocar la tool y seguir sus instrucciones. Si la política del paquete
> cambia, la tool se actualiza y los agentes leen la versión correcta en
> runtime.

### Cuándo usa el MCP cada agente

| Agente | Tier principal | Cuándo |
|--------|---------------|--------|
| **Analyzer** | `api` | Al verificar contratos externos afectados por el refactor |
| **Worker Contracts** | `api`, `sdk` | `api` para alinear firmas; `sdk` para entender capacidades del paquete |
| **Worker CrossCutting** | `api`, `sdk` | `api` para regenerar Refit clients; `sdk` para entender contratos de conectores externos |
| **Worker Impl** | `api`, `setup`, `patterns` | `api` para interfaces; `setup` si la infraestructura cambia en DI; `patterns` para casos avanzados |
| **Worker Presentation** | `setup_functions`, `api` | `setup_functions` para Program.cs/host; `api` para middleware y telemetría |
| **Verifier** | `git_ops`, `publish`, `deploy_*` | Invoca `github__git_ops` antes de proponer commit |
| **Scaffolder** | `setup`, `publish`, `deploy_*`, `docs_*` | Invoca tools de CI/CD y docs al generar workflows y SGs |

### Cómo descubrir la tool adecuada

1. **Identifica el componente**: ¿acceso a datos? ¿mensajería? ¿conector externo? ¿host builder?
2. **Determina el tier** según lo que necesitas hacer (ver tabla anterior)
3. **Lee las descripciones** de las tools del MCP que coincidan con ese componente y tier
4. **Invoca la tool correcta** antes de escribir el código afectado

---

## Protocolo de tres fases

### FASE 1 — Analyze (siempre obligatoria, nunca saltarse)
**Objetivo**: Conocer el impacto completo antes de tocar una sola línea.

1. Invocar `@refactor-analyzer` con la descripción exacta del refactor
2. Esperar el informe completo (archivos afectados, tipo, riesgo, estrategia recomendada)
3. Presentar el informe al usuario para revisión
4. **NO proceder a Fase 2 sin aprobación explícita del usuario**

Señales de que debes pausar y consultar antes de continuar:
- Nivel de riesgo ALTO (más de 30 archivos o dependencias externas afectadas)
- El refactor toca `OperationServiceBase` o `OperationResolver` (clases base críticas)
- El analyzer detecta dependencias externas del ecosistema CS.Level que podrían romperse

### FASE 1.5 — PREFLIGHT de tests (obligatorio, no saltarse)

**Objetivo**: garantizar que existe cobertura de tests para todo el código que
se va a tocar **antes de generar cualquier cambio**.

1. Revisar el informe del analyzer (sección `### Cobertura de tests y gaps`)
2. Para cada gap de severidad **CRÍTICO** o **ALTO**:
   - Invocar `@refactor-worker-tests` para crear **tests de caracterización**
     que documenten el comportamiento actual del código afectado
   - Invocar `@refactor-verifier` para confirmar que los tests compilan y pasan
   - **Commit separado** antes de iniciar FASE 2:
       ```
       test(characterization): add characterization tests for <clases>
       ```
3. Para gaps **MEDIO** o **BAJO**: advertir al usuario pero continuar (no bloquear)
4. **Si no hay gaps**: continuar directamente a FASE 2

> **Para refactors multi-fase**: este PREFLIGHT es subsumido por la Fase
> PREFLIGHT de `multi-phase-refactor`, que es más detallada. No duplicar.

**Regla HARD**: si hay gaps CRÍTICO/ALTO y el usuario no aprueba la creación
de tests de caracterización, el refactor **no puede continuar**. Informar del
riesgo y ofrecer cancelar.
**Objetivo**: Aplicar los cambios en el orden correcto con el máximo paralelismo seguro.

**Obligatorio antes de invocar el primer worker**:
Presentar al usuario el plan completo con este formato y esperar su aprobación explícita.
El usuario puede discutir o modificar el plan en este momento. Solo tras confirmación
explícita se invoca el primer worker. Si el usuario pide "ejecutar sin preguntar", igualmente
se presenta el plan — la aprobación es siempre obligatoria.

```
[PLAN DE EJECUCIÓN]
Tipo: [INTERFACE_RENAME | INTERFACE_EXTEND | ...]
Estrategia: [Secuencial | Contracts-first + paralelo | Paralelo total]

Workers y orden:
  1. @refactor-worker-contracts  — [N archivos] — [descripción del cambio]
  2. @refactor-worker-impl       — [N archivos] — [descripción del cambio]
  3. @refactor-worker-presentation — [N archivos] — [descripción del cambio]
  4. @refactor-worker-tests      — [N archivos] — [descripción del cambio]

¿Proceder?
```

**Reglas de ejecución**:
- Si `Contracts` está en scope → va **primero y solo** (secuencial)
- Si `CrossCutting` está en scope → va **después de Contracts** (secuencial); solo si el analyzer detecta impacto en algún Service Gateway (Mail, Refit clients, etc.)
- Una vez Contracts (y CrossCutting si aplica) están limpios, `Impl` y `Presentation` pueden ir **en paralelo** (si el tipo lo permite)
- `Tests` siempre va **al final**, después de que Impl y Presentation estén completos
- Cada worker recibe: descripción exacta + lista de archivos + patrón destino con ejemplos reales

**Instrucción al invocar un worker**:
```
Descripción del cambio: [qué hay que hacer, exactamente]
Archivos a modificar: [lista de paths del informe del analyzer]
Patrón de destino: [ejemplo de cómo debe quedar el código]
Contexto adicional: [notas del analyzer relevantes para esta capa]
```

### FASE 3 — Verify (validación y commit único)
**Objetivo**: Confirmar que no se ha roto nada y cerrar con un commit limpio y descriptivo.

1. Invocar `@refactor-verifier`
2. Si PASS → proponer commit siguiendo el formato estándar (ver sección al final)
3. Si FAIL → identificar capa fallida, re-invocar el worker específico, re-verificar
4. Máximo 2 intentos de corrección automática. Si persiste el fallo → escalar al usuario
5. **El commit siempre requiere confirmación del usuario. Nunca se ejecuta automáticamente.**

---

## Árbol de decisión: ¿Paralelo o secuencial?

```
¿El refactor modifica firmas en Contracts?
├─ SÍ → ¿Solo renombrado de interfaz/tipo?
│   ├─ SÍ → SECUENCIAL ESTRICTO
│   │        Contracts → CrossCutting* → Impl + Presentation (paralelo) → Tests
│   └─ NO → ¿Añade nuevo miembro a interfaz existente?
│       ├─ SÍ → SECUENCIAL
│       │        Contracts → CrossCutting* → Impl → Presentation → Tests
│       └─ NO → CONSULTAR AL USUARIO (caso complejo)
└─ NO → ¿Los cambios en Impl son independientes entre servicios?
    ├─ SÍ → PARALELO TOTAL
    │        Impl + Presentation + Tests (simultáneo)
    └─ NO → SECUENCIAL dentro de la capa
             (ej: si ServiceA depende de ServiceB)
```

`*` CrossCutting solo si el analyzer detecta impacto en algún Service Gateway (Mail, Refit clients, etc.).

**Casos especiales**:
- Si el refactor solo toca `Impl` sin tocar interfaces → `Impl + Tests` en paralelo, sin Workers de Contracts, CrossCutting ni Presentation
- Si el refactor es una migración de convención pura (async suffix, nullable) → PARALELO TOTAL siempre

---

## Playbooks por tipo de refactor

### INTERFACE_RENAME — Renombrado de interfaz o tipo público
**Ejemplo**: `IBookingService` → `IFlightBookingService`

**Estrategia**: Secuencial estricto — Contracts primero (solitario)

**Worker Contracts debe**:
- Renombrar la interfaz en su archivo de declaración
- Actualizar el nombre del archivo si sigue la convención `I{Nombre}.cs`
- Buscar referencias internas en Contracts (herencias `IHija : IViejaInterfaz`, composiciones)
- Actualizar los using statements internos de Contracts

**Worker Impl debe** (tras Contracts y CrossCutting):
- Buscar todas las clases que implementan la interfaz (`class CSXxx : IViejaInterfaz`)
- Actualizar la declaración de cada clase
- Actualizar los constructores de DI donde el parámetro es del tipo viejo
- Actualizar los using statements

**Worker CrossCutting debe** (tras Contracts, en paralelo con Impl si no depende de Impl):
- Buscar usages de la interfaz renombrada en el SG afectado (ver Layer Map de `AGENTS.md` → `crosscutting`)
- Actualizar la declaración del campo/parámetro y los using statements
- Solo aplica si el SG consume directamente la interfaz renombrada

**Worker Presentation debe** (en paralelo con Impl):
- Buscar constructores de Azure Functions con parámetro del tipo viejo
- Actualizar el tipo del parámetro y del campo privado si lo almacena
- Actualizar los using statements

**Worker Tests debe** (tras Impl y API):
- Buscar `Substitute.For<IViejaInterfaz>()` → reemplazar por `Substitute.For<INuevaInterfaz>()`
- Actualizar todos los tipos de campos y variables que usan la interfaz
- Actualizar los using statements

---

### INTERFACE_EXTEND — Nuevo miembro en interfaz existente
**Ejemplo**: Añadir `Task<VoucherResponse> GetVoucherAsync(VoucherRequest request)` a `IBookingService`

**Estrategia**: Secuencial — Contracts, luego Impl, luego API, luego Tests

**Worker Contracts debe**:
- Añadir la firma del nuevo método en la interfaz (con documentación XML si existe el patrón)
- Crear los tipos `VoucherRequest` y `VoucherResponse` si son nuevos
- Si la interfaz tiene Default Interface Methods (patrón `IOperationRepository`), añadir también
  la implementación por defecto si corresponde

**Worker Impl debe** (tras Contracts):
- Implementar el nuevo método en TODAS las clases que implementen la interfaz
- Priorizar `OperationServiceBase` si tiene lógica compartida aplicable
- Seguir el patrón Template Method existente (definir `abstract` en base, implementar en subclases)
- Si hay múltiples implementaciones (ej: `CSBookingService`, `CSTestBookingService`), implementar en todas

**Worker CrossCutting debe** (tras Contracts, si el nuevo miembro afecta contratos que un SG consume):
- Actualizar usages del tipo/interfaz en el SG afectado (ver Layer Map de `AGENTS.md` → `crosscutting`)
- Solo aplica si el nuevo miembro introduce tipos que el SG usa directamente

**Worker Presentation debe** (tras Impl):
- Si el nuevo método tiene un endpoint HTTP asociado: crear la Azure Function correspondiente
  siguiendo el patrón exacto de las Functions existentes en el mismo directorio
- Mantener el mismo estilo de serialización/deserialización JSON

**Worker Tests debe** (tras Impl y API):
- Añadir al menos un test para el happy path del nuevo método
- Añadir tests para casos de error si corresponde
- Actualizar los setups de NSubstitute en tests existentes si usan la interfaz
- Seguir el naming `Método_Escenario_ResultadoEsperado`

---

### PATTERN_ADOPTION — Adopción de nuevo patrón arquitectónico
**Ejemplo**: Introducir Result pattern en lugar de excepciones en las operaciones de reserva

**Estrategia**: Contracts primero (si hay nuevos tipos) → Impl + API en paralelo → Tests

**Worker Contracts debe**:
- Crear los tipos del patrón (`Result<T>`, `BookingError`, etc.) si no existen en el proyecto
- Actualizar las firmas de las interfaces afectadas para retornar los nuevos tipos
- Documentar los casos de error en los tipos si hay convención existente

**Worker Impl debe** (tras Contracts):
- Refactorizar los métodos para usar el nuevo patrón en lugar del mecanismo anterior
- Mantener coherencia con `OperationServiceBase` y `CSSyncState` si gestionan estados relacionados
- No cambiar la lógica de negocio, solo el mecanismo de retorno/error

**Worker CrossCutting debe** (tras Contracts, si los nuevos tipos afectan algún SG):
- Actualizar el SG para usar los nuevos tipos del patrón en lugar del mecanismo anterior
- Solo aplica si el SG expone o consume los contratos modificados

**Worker Presentation debe** (en paralelo con Impl):
- Actualizar las Azure Functions para manejar el nuevo tipo de retorno
- Convertir `Result<T>` al `HttpResponseData` apropiado (200 para success, 4xx/5xx para errores)
- Mantener los contratos HTTP existentes (códigos de respuesta, estructura JSON)

**Worker Tests debe** (tras Impl y API):
- Actualizar los tests existentes para verificar el nuevo tipo de retorno
- Añadir tests que verifiquen los casos de error usando el nuevo mecanismo
- Usar `Shouldly` para verificar el tipo y contenido del Result

---

### CONVENTION_MIGRATION — Migración de convención interna
**Ejemplo**: Añadir sufijo `Async` a todos los métodos async, o habilitar nullable annotations

**Estrategia**: Paralelo total — todos los workers simultáneamente

**Instrucción común a todos los workers**:
- Buscar el patrón afectado dentro de su scope de archivos
- Aplicar el cambio de forma mecánica y consistente
- Actualizar también las llamadas internas al método/tipo dentro de su propia capa
- NO preocuparse por las referencias en otras capas (otro worker lo hará en paralelo)

**Para migración a async suffix**:
- Renombrar `Get()` → `GetAsync()` en la declaración Y en todos los call sites de la misma capa
- Actualizar las expresiones `await` si el call site ya era async

**Para nullable annotations**:
- Añadir `?` a tipos de referencia que pueden ser null
- Añadir `!` (null-forgiving operator) solo cuando el flujo garantiza no-null y el análisis estático falla
- No añadir `ArgumentNullException.ThrowIfNull` en masa; solo donde el analyzer indique riesgo real

**Nota post-ejecución**: El orchestrator debe verificar, tras la ejecución paralela, que no hayan
quedado referencias cruzadas sin actualizar. El verifier (`dotnet build`) lo confirmará.

---

## Procedimiento de rollback

### Si el verifier falla (primer intento):
1. El orchestrator identifica la capa fallida del log de errores
2. Re-invoca el worker correspondiente con instrucciones de corrección específicas
3. Vuelve a invocar el verifier

### Si el verifier falla (segundo intento):
1. Reportar al usuario con el log de errores completo
2. Recomendar una de estas opciones en orden de preferencia:
   - **Opción A** (preferida): `/undo` en OpenCode — revierte toda la sesión
   - **Opción B**: `git restore .` — descarta todos los cambios no commiteados
   - **Opción C**: corregir manualmente el error específico reportado

### Señales de rollback inmediato (sin intentar corrección automática):
- Más de 20 errores de compilación tras la primera verificación
- Errores en `OperationServiceBase` o `OperationResolver` (clases base críticas del patrón Template Method)
- Errores de compilación en múltiples capas simultáneamente (indica desincronización entre workers)
- El build falla con errores de tipo "assembly reference" (posible impacto en dependencias externas)

---

## Formato de commit estándar

```
refactor(<scope>): <acción en inglés, imperativo, sin punto final>

- <cambio aplicado en capa 1>
- <cambio aplicado en capa 2>
- <cambio aplicado en capa 3>
```

**Scopes válidos**:
- Nombre de la capa afectada: `contracts`, `crosscutting`, `impl`, `presentation`, `tests`
- Nombre del dominio afectado: `booking`, `cancel`, `passenger`, `voucher`, `payment`
- Nombre del tipo de cambio: `async`, `nullable`, `naming`

**Ejemplos de commits correctos**:
```
refactor(contracts): rename IBookingService to IFlightBookingService

- Updated interface declaration and file name in Contracts layer
- Updated all implementations in Impl: CSBookingService, CSTestBookingService
- Updated constructor injection in API Functions
- Updated NSubstitute mocks in Test layer
```

```
refactor(impl): adopt Result pattern in booking operation services

- Added Result<T> and BookingError types to Contracts
- Refactored CSBookingService and CSCancelService to return Result<T>
- Updated BookingFunction and CancelFunction HTTP response handling
- Updated test assertions to verify Result type and error cases
```

---

## Cuándo usar este skill

Usa siempre este skill cuando:
- El refactor afecta más de 5 archivos
- El cambio cruza más de una capa
- El cambio toca interfaces públicas en Contracts
- Hay riesgo de romper tests existentes

No es necesario para cambios menores de una sola capa en menos de 5 archivos.
