---
description: Investiga y corrige un bug con reproducción automatizada. Cubre la recopilación del informe de bug, la búsqueda de la ruta de código, instrumentación temporal, ciclo de hipótesis-validación y limpieza OBLIGATORIA de código de debug. Uso: /investigate-bug <descripcion>.
agent: refactor-orchestrator
subtask: false
---

Carga el skill `bug-investigation` y ejecuta el protocolo completo de investigación
para el siguiente bug:

$ARGUMENTS

## Comportamiento esperado

El orchestrator delega la investigación en si mismo, cargando el skill `bug-investigation`
como fuente de verdad del protocolo. Las fases (FASE 0-6) están definidas en el skill;
este command solo aporta el contexto de invocación.

## Cuando usarlo

- El usuario reporta un bug con un input concreto y un output inesperado
- El bug requiere reproducir el comportamiento para entender la causa raíz
- El bug NO es evidente solo leyendo el código

Si el bug es obvio y el fix se deduce por inspección, **no usar este command** — editar
directamente es más eficiente.

## Restricciones duras (recordatorio)

- **Limpieza obligatoria**: antes de proponer commit, ejecutar el checklist de FASE 5.2
  del skill. CERO `Console.WriteLine` / `TestContext.WriteLine` / `Debugger.Break` /
  comentarios `// DEBUG` en el commit final.
- **Máximo 5 iteraciones**: si no converge, escalar al usuario
- **No commit automático**: el formato del commit es el del skill (`fix(<scope>): ...`)
  y requiere confirmación explícita
- **No expandir el fix**: si el fix mínimo requiere refactor mayor, escalar al usuario
  (considerar `/refactor-plan`)

## Relación con otros comandos

| Command | Cuando |
|---|---|
| `/refactor-plan` | Si el fix requiere cambios estructurales mayores (firmas, refactor de patrón) |
| `/add-feature` | Si el "bug" resulta ser una funcionalidad que nunca existió (no es bug) |

## Ejemplos de uso

```
/investigate-bug POST /api/refunds devuelve total incorrecto cuando hay multiples documentos
/investigate-bug el campo passenger.email llega como null en algun flujo
/investigate-bug timer de reconciliacion no se dispara cada 5 minutos
```