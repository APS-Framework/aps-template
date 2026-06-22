---
description: Crea una funcionalidad nueva (endpoint, servicio, job, handler, opción de configuración). Cubre análisis de reutilización, configuración, impacto en API pública y ubicación por capa. Uso: /add-feature <descripcion>.
agent: refactor-orchestrator
subtask: false
---

Carga el skill `add-feature` y ejecuta el protocolo completo de creación:

$ARGUMENTS

## Comportamiento esperado

El orchestrator detecta el tipo de feature (endpoint HTTP, servicio de dominio, job/event handler,
opción de configuración) a partir de la descripción del usuario y aplica la rama correspondiente
del skill:

1. **FASE 0 — Validación de estructura**: ejecuta la validación del proyecto antes de hacer nada
   más. Si el estado es `HARD_BLOCK`, detente e informa al usuario.

2. **FASE 1 — Recopilación de requisitos + análisis de reutilización/config/impacto**: infiere
   lo que puedas de la descripción. Solo pregunta lo que no esté claro. **No hagas preguntas
   redundantes.** Las preguntas clave son:
   - Servicio candidato en `*.Impl/` (¿reutilización, extensión o nuevo?)
   - ¿Requiere configuración (`IXxxOptions` + sección `appsettings`)?
   - ¿Rompe API pública? (call sites afectados)

3. **FASE 2 — Árbol de decisión**: determina qué artefactos crear y en qué capa va cada uno.
   Ante cualquier duda sobre la ubicación de un artefacto, pregunta al usuario.

4. **FASE 3 — Plan de creación**: presenta el plan completo al usuario (artefactos, capas,
   orden de ejecución) y espera confirmación explícita antes de invocar workers.

5. **FASE 4 — Ejecución**: invoca los workers en el orden correcto según el skill.
   Nunca saltes el orden: Contracts (si aplica) → Impl → Presentation → CrossCutting (si aplica) → Tests.

6. **FASE 5 — Verificación**: invoca `@refactor-verifier` y propone el commit con el formato
   `feat(<scope>): add <nombre-corto>` solo tras build y tests en verde.

## Endpoints HTTP

Si la descripción del usuario menciona un endpoint HTTP (Function o Controller), el orchestrator
lo trata como una feature MUTATION o READ-ONLY según corresponda. La diferencia entre ambas
está cubierta en el skill (`add-feature/SKILL.md` § FASE 2).

> **Nota**: este command reemplaza al antiguo `/add-endpoint`, eliminado por redundancia.

## Restricciones

- Nunca crees código sin haber presentado y obtenido confirmación del plan (FASE 3)
- Nunca omitas los tests (worker-tests siempre va al final)
- Si el proyecto es de tipo `NUGET_LIBRARY`, pregunta antes de continuar
- Ante la duda sobre la ubicación de un artefacto, consulta al usuario — nunca asumas

## Ejemplos de uso

```
/add-feature
/add-feature POST /api/bookings que crea una reserva
/add-feature endpoint GET /api/passengers/{id}
/add-feature job que reconcilia pagos pendientes cada 5 minutos
/add-feature opción de configuración para habilitar dry-run en refunds
```