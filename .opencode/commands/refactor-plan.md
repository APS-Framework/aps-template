---
description: Analiza el impacto de un refactor propuesto sin modificar ningún archivo. Produce un informe estructurado con archivos afectados por capa, tipo de cambio, nivel de riesgo y estrategia de ejecución recomendada. Ejecutar siempre antes de /refactor-start.
agent: refactor-analyzer
subtask: true
---

Carga el skill `refactor-protocol` y ejecuta ÚNICAMENTE la fase de análisis para el siguiente refactor:

$ARGUMENTS

## Pasos obligatorios

1. Lee la sección **Layer Map** de `AGENTS.md` para conocer los paths y roles de cada capa
2. Invoca `@refactor-analyzer` con la descripción completa del refactor
3. Presenta el informe de impacto completo al usuario con formato legible
4. Concluye con una recomendación explícita:
   - ¿Es seguro proceder con `/refactor-start`?
   - ¿Hay riesgos que el usuario debe conocer antes de ejecutar?
   - ¿Cuál es la estrategia de ejecución recomendada?

## Restricciones
- No hagas ningún cambio en el código
- No inventes archivos ni referencias que no hayas encontrado en el código real
- Si la descripción del refactor es ambigua, pregunta antes de analizar
