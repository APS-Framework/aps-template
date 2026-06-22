# Skill: refactor-session

Protocolo de **persistencia de sesión** para refactors grandes. Define cómo el orchestrator debe
escribir el progreso del refactor a un archivo para que, si la sesión se interrumpe o se cancela,
se pueda reanudar sin perder el contexto ni repetir análisis.

Este skill **se invoca automáticamente** al inicio de cualquier comando de refactor
(`/refactor-plan`, `/refactor-start`, `/refactor-sequential`) o cuando el analyzer/orchestrator
detecta que va a ejecutar un workflow multi-fase.

---

## Por qué este skill existe

Sin este contrato, los agentes `@plan` ejecutan su análisis en memoria y al cerrarse la sesión
se pierde todo: impacto detectado, archivos a tocar, fases aprobadas, decisiones del usuario.
Esto obliga a repetir el análisis desde cero cada vez.

Con este skill:
- El orchestrator **escribe a un archivo** antes de cada acción significativa
- Al reanudar, carga el archivo y sabe exactamente dónde quedó
- El usuario puede revisar el plan en cualquier momento abriendo el archivo

---

## Ubicación del archivo de sesión

`<root>/.opencode/plans/<slug>/state.md`

Donde:
- `<root>` es la raíz del workspace
- `<slug>` es un kebab-case derivado de la descripción con prefijo de fecha (e.g., `20260622-operation-resolver-solid`)
- Un plan es una **carpeta** (no un archivo plano) que contiene `state.md` y, opcionalmente, otros artefactos de la sesión (`analisis.md`, `notas.md`, etc.)

**Reglas**:
- Un plan por sesión de refactor; cada plan vive en su propia carpeta bajo `.opencode/plans/`
- Si la carpeta ya existe para el mismo slug, **se actualiza** (no se sobrescribe sin leer)
- El `state.md` se commitea al repositorio **al finalizar** el refactor junto con el commit de código
  (sirve como documentación histórica)

> **Importante**: el plugin `pending-plans` (en `.opencode/plugins/pending-plans.ts`) y el
> orchestrator (`refactor-orchestrator.md`) esperan este formato exacto. Cualquier desvío
> rompe la recuperación de sesión entre invocaciones.

---

## Plantilla del archivo

```markdown
# Refactor: <título corto>

**Iniciado**: <YYYY-MM-DD HH:MM>
**Estado**: <ANALYZING | AWAITING_APPROVAL | IN_PROGRESS | COMPLETED | ABORTED>
**Modo**: <simple | multi-phase>
**Skill principal**: <refactor-protocol | multi-phase-refactor>

## Descripción

<descripción en lenguaje natural que dio el usuario>

## Informe del analyzer

- **Archivos en scope**: <N>
- **Capas afectadas**: <lista>
- **Nivel de riesgo**: <BAJO | MEDIO | ALTO>
- **Tipo de cambio**: <INTERFACE_RENAME | INTERFACE_EXTEND | PATTERN_ADOPTION |
  CONVENTION_MIGRATION | REFACTOR>

## Archivos afectados

### Contracts
- [ ] `src/.../IXxx.cs` — <descripción del cambio>

### Impl
- [ ] `src/.../XxxService.cs` — <descripción del cambio>

### Presentation
- [ ] `src/.../XxxFunction.cs` — <descripción del cambio>

### CrossCutting
- [ ] `src/.../XxxGateway.cs` — <descripción del cambio>

### Tests
- [ ] `src/.../XxxTests.cs` — <descripción del cambio>

## Decisiones del usuario

- **<YYYY-MM-DD HH:MM>**: <decisión registrada durante la conversación>
- **<YYYY-MM-DD HH:MM>**: <otra decisión>

## Estado de fases

### Fase 1 — <nombre>
- **Estado**: <PENDING | IN_PROGRESS | DONE | BLOCKED>
- **Workers**: <qué workers se invocaron>
- **Resultado**: <resumen>

### Fase 2 — <nombre>
- **Estado**: <PENDING | ...>

## Commits

- <hash> — <mensaje del commit>

## Notas y blockers

- <cualquier cosa que el orchestrator quiera recordar para la próxima sesión>
```

---

## Lifecycle del archivo

### Paso 1 — Al iniciar (en `/refactor-plan`)

El analyzer crea el archivo con:
- Cabecera completa (descripción, fecha, modo)
- Informe de impacto
- Lista de archivos por capa con checkboxes vacíos `[ ]`
- Estado: `AWAITING_APPROVAL`

### Paso 2 — Tras aprobación del usuario

El orchestrator actualiza:
- Estado → `IN_PROGRESS`
- Sección "Decisiones del usuario" con la aprobación
- Si es multi-fase, desglosa las fases con checkboxes

### Paso 3 — Tras cada worker

El orchestrator actualiza:
- Marca archivos completados `[x]` en su capa
- Marca la fase como `DONE` o `IN_PROGRESS`
- Añade nota si el worker reportó algo relevante

### Paso 4 — Al finalizar (en `/refactor-verify`)

El verifier actualiza:
- Estado → `COMPLETED` (o `BLOCKED` si algo falla)
- Sección "Commits" con los hashes reales
- Notas finales

---

## Procedimiento de reanudación

Cuando se carga una sesión y existe un plan en `.opencode/plans/<slug>/state.md`:

1. **Listar carpetas** en `.opencode/plans/` con `state.md` cuyo `## Estado` sea distinto de `completado`
2. Si hay exactamente uno: presentarlo al usuario con "¿Deseas reanudar este refactor?"
3. Si hay varios: preguntar cuál reanudar
4. Si el usuario dice sí:
   - Leer el archivo completo
   - Mostrar el estado actual (qué fases están `DONE`, cuáles `PENDING`)
   - Preguntar al usuario si continúa desde el último `IN_PROGRESS` o si quiere revisar el plan
   - Continuar con la fase apropiada del skill principal (`refactor-protocol` o `multi-phase-refactor`)

Si el archivo está en estado `en curso` y el usuario lo retoma, equivale a una confirmación
de continuar — preguntar de nuevo antes de proceder.

> **Detección automática**: el plugin `pending-plans` escanea `.opencode/plans/<slug>/state.md` al
> inicio de cada sesión y muestra un toast si encuentra checkboxes pendientes (`- [ ]`).
> El orchestrator (`refactor-orchestrator.md` PASO 0) hace la misma comprobación al
> arrancar y ofrece retomar.

---

## Convenciones

- **NO** incluir en el archivo:
  - Código fuente completo (soloPaths y descripciones de cambios)
  - Logs de ejecución extensos (resumir)
  - Información sensible (secretos, credenciales)
- **SÍ** incluir:
  - Paths relativos a la raíz del workspace
  - Decisiones del usuario textuales
  - Errores y blockers con contexto suficiente para resolver
- El archivo debe ser **legible por humanos**, no un dump de estado interno

---

## Cuándo usar este skill

| Situación | Invocar skill |
|---|---|
| Usuario ejecuta `/refactor-plan` | ✅ Siempre |
| Usuario ejecuta `/refactor-start` sin plan previo | ✅ Crear plan + ejecutar |
| Usuario ejecuta `/refactor-sequential` | ✅ Siempre |
| Analyzer detecta riesgo ALTO | ✅ Antes de delegar a workers |
| Sesión interrumpida con refactor en curso | ✅ Reanudar desde archivo |
| Refactor trivial (< 5 archivos, 1 capa) | ❌ No necesario |

---

## Anti-patrones

- ❌ Sobrescribir el archivo sin leer el anterior (pierde historial)
- ❌ Escribir archivos de sesión fuera de `.opencode/plans/<slug>/state.md` (la ubicación
  canónica; el plugin `pending-plans` y el orchestrator solo detectan este path)
- ❌ Escribir `state.md` como archivo plano en `.opencode/plans/<slug>.md` (debe ser
  carpeta con `state.md` dentro)
- ❌ Commits por cada actualización del archivo (solo al final o en checkpoints importantes)
- ❌ Incluir el contenido completo de los archivos modificados (soloPaths)
- ❌ Marcar fases como `DONE` antes de que el verifier confirme build + tests en verde
