# Skill: multi-phase-refactor

Protocolo para refactors grandes que requieren ejecución en etapas con aprobación explícita entre
cada una. Se usa cuando el riesgo es ALTO, hay muchos archivos afectados, o el cambio toca áreas
semánticamente distintas de `*.Contracts/` que conviene aislar para facilitar revisión y rollback
parcial.

## Cuándo usar este skill vs `refactor-protocol`

| Criterio | Usar `refactor-protocol` | Usar `multi-phase-refactor` |
|---|---|---|
| Riesgo del analyzer | BAJO o MEDIO | ALTO |
| Archivos afectados | < 30 | ≥ 30 |
| Capas tocadas | 1-2 | 3 o más |
| Cambio en Contracts | Un solo área semántica | ≥ 2 áreas semánticas separadas |
| Usuario invocó | `/refactor-start` | `/refactor-sequential` |
| Gaps de test CRÍTICO | No | Sí (PREFLIGHT obligatorio) |

Si **cualquier** condición de la columna derecha se cumple: usa este skill.
Si **todas** las condiciones apuntan a `refactor-protocol`: usa ese skill en su lugar.

---

## Macrofases del protocolo

### Fase 0 — Análisis y setup (ya completada por el orchestrator)

- El orchestrator ya invocó el analyzer y tiene el informe completo
- Ya se detectó que el refactor es multi-fase (por riesgo ALTO, archivos ≥ 30, multi-área o comando `/refactor-sequential`)
- El orchestrator carga este skill y continúa en PREFLIGHT

---

### Fase PREFLIGHT — Tests de caracterización

**Obligatoria** si el informe del analyzer reporta gaps de severidad **CRÍTICO** o **ALTO**.
Opcional pero recomendada si hay gaps **MEDIO**.

1. El orchestrator presenta al usuario los gaps de cobertura encontrados
2. Propone crear **tests de caracterización** — tests que documentan el comportamiento **actual**
   del código sin juicios sobre si es correcto o deseable; son la red de seguridad del refactor
3. Espera aprobación del usuario antes de invocar ningún worker
4. Si aprobado: invoca `@refactor-worker-tests` con este prompt:
   > "Crea tests de caracterización para [ClaseA, ClaseB, ...]. Los tests deben documentar el
   > comportamiento observable actual, no el comportamiento deseado futuro. Nómbralos con el
   > sufijo `_Characterization` para distinguirlos de los tests de regresión normales."
5. Invoca `@refactor-verifier` para confirmar que los nuevos tests compilan y pasan en verde
6. Presenta al usuario el resumen de tests creados y espera confirmación para continuar
7. **Commit separado obligatorio** antes de iniciar cualquier cambio de código:
   ```
   test(characterization): add characterization tests for <Clase1>, <Clase2>
   ```

---

### Fase N — Refactor por etapas (1 a N fases)

El orchestrator descompone el refactor en fases lógicas y presenta la lista completa al usuario
**antes de empezar ninguna fase**. El usuario puede reorganizar, fusionar o cancelar fases antes
de aprobar.

**Criterios de descomposición**:
- Cada fase toca **un área semántica coherente** de Contracts (o ninguna)
- Si Contracts cambia, esa capa va **en solitario** en su propia fase
- Si varias áreas de Impl pueden cambiar independientemente, son fases separadas
- Tests siempre al final de cada fase (nunca comparten fase con Contracts ni Impl)

#### Antes de iniciar cada fase N

1. El orchestrator presenta el **plan de la fase** al usuario:
   ```
   [FASE N/Total] <nombre descriptivo de la fase>
   Capas:    [Contracts | CrossCutting | Impl | Presentation | Tests]
   Archivos: N archivos modificados
   Criterios de aprobación:
     - Build limpio
     - Tests específicos que DEBEN pasar: <lista de nombres de test>
     - Comportamiento preservado: <descripción en 1 línea>
   ```
2. Espera confirmación explícita del usuario antes de invocar workers

#### Ejecución de la fase

3. Invoca workers según la estrategia decidida en el análisis (secuencial o paralelo)
4. Incluye en el prompt de cada worker:
   - Descripción exacta del cambio de esa fase
   - Lista de archivos a modificar
   - Patrón o convención de destino con ejemplos del código existente

#### Verificación de la fase

5. Invoca `@refactor-verifier` pasándole los **criterios específicos de la fase**:
   - Lista de test names que deben pasar (tests de regresión + tests de caracterización relevantes)
   - El verifier ejecutará `dotnet test --filter` para cada criterio nombrado
6. Si **PASS**:
   - El orchestrator **no hace commit todavía** (salvo que el usuario lo haya pedido explícitamente)
   - Genera el resumen de contexto (ver §Resumen entre fases)
   - Continúa a la siguiente fase
7. Si **FAIL**:
   - Re-invoca el worker problemático con las correcciones necesarias
   - Vuelve a invocar el verifier
   - Si falla por segunda vez: detener y recomendar `git restore <archivos de la fase>`

---

### Fase FINAL — Verificación global y commit único

Una vez todas las fases N han pasado su verificación:

1. Invoca `@refactor-verifier` **sin criterios específicos** (verifica el suite completo)
2. Si **PASS global**: propón un **único commit** que cubra todas las fases:
   ```
   refactor(<scope>): <descripción del refactor completo>

   Phase 1: <resumen en 1 línea>
   Phase 2: <resumen en 1 línea>
   ...
   Note: characterization tests added in prior commit
   ```
3. Espera confirmación del usuario antes de ejecutar el commit
4. Si hubo un commit de PREFLIGHT: mencionarlo en el body como contexto

---

## Criterios de aprobación por fase

Los criterios de aprobación no son solo "build + all tests". Para cada fase, el orchestrator
debe especificar al verifier:

1. **Tests de regresión afectados**: tests que cubren directamente el código de esa fase
2. **Tests de caracterización relevantes**: si la fase toca código con tests de caracterización creados en PREFLIGHT
3. **Tests de integración si aplica**: si la fase conecta dos capas (ej: Impl llama a Contracts renovados)

El verifier usará `dotnet test --filter "FullyQualifiedName~<pattern>"` para validar cada criterio
por nombre antes de ejecutar el suite completo.

---

## Rollback por fase

| Situación | Acción |
|---|---|
| Verificación de fase N falla por segunda vez | `git restore` de los archivos modificados en esa fase |
| Usuario cancela entre fases | Los commits anteriores se mantienen; solo se revierte el trabajo pendiente |
| Verificación FINAL falla | Identificar qué fase introdujo la regresión con `git diff <base> HEAD`; revertir solo esa fase |
| PREFLIGHT falla en build | Corregir los tests de caracterización antes de tocar código de producción |

**Nunca se usa `git reset --hard`** sin confirmación explícita del usuario.
Los tests de caracterización (si existen) se mantienen aunque se revierta el refactor;
son documentación valiosa del comportamiento actual.

---

## Resumen de contexto entre fases

Al finalizar cada fase (antes de empezar la siguiente), el orchestrator genera este resumen compacto
para mantener al usuario informado sin saturar la ventana de contexto:

```
[RESUMEN FASE N/Total]
Cambios realizados:
  - ruta/Archivo1.cs — <motivo en 1 línea>
  - ruta/Archivo2.cs — <motivo en 1 línea>
Estado:         PASS (build ✓, N tests ✓)
Criterios:      ✓ <NombreTest1>  ✓ <NombreTest2>
Próxima fase:   [N+1/Total] <nombre y objetivo>
```

---

## Señales de pausa obligatoria

El orchestrator debe **detenerse y consultar al usuario** si detecta cualquiera de estos eventos:

- Un worker reporta que el cambio en su capa es **mayor al previsto** (más archivos de los que el plan indicaba)
- Un test de caracterización falla en PREFLIGHT (el comportamiento actual es ambiguo o inconsistente)
- El verifier encuentra tests fallidos en **capas no tocadas** por la fase actual (regresión inesperada)
- Una dependencia externa (paquete NuGet) requiere cambios no previstos en el análisis
