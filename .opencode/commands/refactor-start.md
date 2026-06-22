---
description: Ejecuta un refactor previamente analizado con /refactor-plan. Activa el refactor-orchestrator, que delega en workers especializados por capa y verifica el resultado antes de proponer un único commit final.
agent: refactor-orchestrator
subtask: false
---

El usuario ha aprobado el refactor. Carga el skill `refactor-protocol` y ejecuta el protocolo completo:

$ARGUMENTS

## Comportamiento esperado

1. **Si hay un plan previo en el contexto de la sesión**: revísalo y úsalo como punto de partida
   para la Fase 2 (ejecución). No repitas el análisis completo, solo confirma que el scope
   no ha cambiado.

2. **Si no hay plan previo en el contexto**: ejecuta primero la Fase 1 (análisis completo con
   `@refactor-analyzer`) antes de proceder. Nunca saltes el análisis.

3. Presenta el plan de ejecución al usuario (qué workers, en qué orden, en paralelo o secuencial)
   y espera confirmación explícita antes de invocar los workers.

4. Sigue el protocolo completo de tres fases hasta el reporte del verifier.
