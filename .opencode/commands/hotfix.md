---
description: Fix rápido para bugs en producción. Sin ciclo de hipótesis ni instrumentación: inspección directa, fix mínimo, test de regresión y commit con prefijo hotfix(). Uso: /hotfix <descripcion>.
agent: refactor-orchestrator
subtask: false
---

Carga el skill `bug-investigation` pero ejecuta **solo FASE 0, FASE 1, FASE 2.3
(inspección) y FASE 5** del protocolo. Omite FASE 3 (instrumentación), FASE 4
(ciclo de hipótesis) y FASE 6 (cierre de sesión).

$ARGUMENTS

## Cuándo usarlo

- El bug está en producción y la velocidad importa más que el proceso
- La causa raíz es evidente por inspección del código (FASE 2.3 del skill)
- El fix es un cambio mínimo que no requiere reproducción automatizada

## Cuándo NO usarlo

- El bug no es evidente y requiere reproducción → usar `/investigate-bug`
- El fix requiere cambios estructurales → usar `/refactor-plan`
- El "bug" resulta ser una funcionalidad que nunca existió → usar `/add-feature`

## Flujo simplificado

1. **FASE 0** (recopilación): sintoma + input + output esperado. Mínimo: sintoma
   y descripción del comportamiento incorrecto.

2. **FASE 1** (análisis): `grep` para localizar la ruta de código. Lista de
   archivos y líneas relevantes.

3. **FASE 1.5** (PREFLIGHT de tests): verificar que los componentes afectados
   (el método con el bug + call sites tangenciales) tienen cobertura de tests.
   - Si tienen cobertura → esos tests son la red de regresión
   - Si **no** tienen cobertura → **HARD BLOCK**: crear tests de caracterización
     del comportamiento actual (incluyendo el bug) y verificar que pasan antes
     de aplicar el fix. Commit separado:
     ```
     test(characterization): add characterization tests for <clases>
     ```

4. **FASE 2.3** (inspección): confirmar la causa raíz por lectura del código.
   **No crear test de reproducción**.

5. **FASE 5.1** (fix mínimo): aplicar el menor cambio que resuelve el bug.

6. **FASE 5.2** (limpieza): aunque no se añadió instrumentación, ejecutar el
   checklist para verificar que no quedó código de debug residual.

7. **FASE 5.3** (criterio de cierre): deben pasar **AMBOS** conjuntos:
   - **Tests nuevos** (de caracterización creados en paso 3 + test de regresión
     del fix): el test del bug se actualiza para esperar el output correcto
   - **Tests existentes** (suite completa del proyecto): `dotnet test` → no
     debe haber regresiones

8. **Commit** con formato:
   ```
   hotfix(<scope>): <síntoma breve en imperativo>

   - Root cause: <descripción técnica>
   - Fix: <descripción del cambio mínimo>
   ```

## Restricciones

- **No instrumentar**: este flujo no añade `Console.WriteLine` ni breakpoints.
  Si sientes que necesitas instrumentar, el bug no es candidato para hotfix —
  usa `/investigate-bug` en su lugar.
- **No expandir el fix**: si el fix mínimo resulta ser mayor de lo esperado,
  pausa e informa al usuario. Sugiere `/investigate-bug` o `/refactor-plan`.
- **No commit automático**: espera confirmación explícita del usuario.
- **Cherry-pick**: si el proyecto usa ramas de release, recuerda al usuario que
  el hotfix debe cherry-pickearse a la rama de release correspondiente.

## Ejemplos de uso

```
/hotfix POST /api/refunds devuelve 500 cuando amount es 0
/hotfix el campo passenger.email llega null cuando el booking no tiene profile
/hotfix timer de reconciliacion se dispara cada 1 minuto en vez de cada 5
```
