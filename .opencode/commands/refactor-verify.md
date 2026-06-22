---
description: Escape hatch para retomar un refactor interrumpido. Escanea .opencode/plans/ para encontrar el estado en curso, ejecuta build y tests, y propone el commit si todo pasa. Úsalo cuando la sesión del orchestrator se interrumpió con código ya modificado.
agent: refactor-orchestrator
subtask: false
---

Carga el skill `refactor-protocol` y ejecuta el protocolo de verificación y commit
para retomar un refactor interrumpido.

## Comportamiento esperado

El orchestrator:

1. **PASO 0 — Recuperar estado**: escanea `.opencode/plans/` buscando cualquier
   `state.md` con `## Estado: en curso` (formato `.opencode/plans/<slug>/state.md`).

   - Si encuentra uno: lee el archivo completo, presenta al usuario la descripción, fase
     actual y workers pendientes, y pregunta si quiere retomar desde donde quedo.
   - Si hay varios en curso: pregunta al usuario cuál retomar.
   - Si no hay ninguno en curso: avisa al usuario y pregunta si quiere ejecutar la
     verificación igualmente (asume que el código está modificado en memoria de sesión
     pero no hay plan guardado).

2. **Verificación**: invoca `@refactor-verifier` con el contexto del `state.md`:
   - `dotnet build` — build completo de la solución
   - `dotnet test --logger "console;verbosity=detailed"` — todos los proyectos de test

3. **Resultado**:
   - **PASS**: confirma build y tests en verde. Muestra `git diff --stat`. Propone el
     commit al usuario siguiendo el formato del skill `refactor-protocol` (sección
     "Formato de commit estándar"). Tras confirmar el commit: actualiza `state.md`
     marcando todas las fases `[x]` y `## Estado: completado`.
   - **FAIL**: muestra solo los errores relevantes (no el log completo). Indica en qué
     capa o archivo se originan. Sugiere qué worker debería re-ejecutarse para corregirlo.

## Restricciones

- No inicies un nuevo refactor desde aquí; si no hay `state.md` en curso y el usuario
  quiere analizar uno nuevo, sugiere `/refactor-plan <descripcion>` en su lugar
- Nunca hagas commit automático; siempre espera confirmación explícita
- Si la sesión fue interrumpida con código modificado, este command es la vía oficial
  para retomar; evita lanzar un nuevo orchestrator desde cero