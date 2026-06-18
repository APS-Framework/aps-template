---
description: Crea una nueva Azure Function con APS Framework a partir de una descripcion. Uso: /aps-new-function [nombre] [descripcion...]
agent: aps-scaffolder
model: anthropic/claude-sonnet-4-20250514
---

# /aps-new-function

Crea un nuevo proyecto Azure Function (isolated worker, .NET 8) que use
paquetes de APS Framework, a partir de la descripcion del usuario.

## Argumentos

- `$1` (opcional) = nombre del proyecto en PascalCase. Si se omite, preguntar.
- `$ARGUMENTS` (opcional) = descripcion en lenguaje natural de lo que hace
  la function. Si se omite, preguntar.

## Comportamiento

Cargar skill `aps-scaffolder` (subagent) con el procedimiento completo.
Ademas:

- **Tipo de proyecto**: Function App (siempre)
- **Plantilla**: `aps-function-template`
- **Ruta por defecto**: `./src/{NombreProyecto}/` (o la que indique el usuario)

## Ejemplos de uso

```
/aps-new-function
/aps-new-function OrderProcessor
/aps-new-function OrderProcessor function que procesa pedidos y los guarda en Cosmos
/aps-new-function EventPublisher "function que publica eventos a Event Grid cuando se crea un pedido"
```

## Interaccion esperada con el usuario

Si faltan el nombre o la descripcion, el subagent preguntara usando la
herramienta `question`. Las preguntas seran concretas, con 2-4 opciones y
campo libre.

Tras crear el proyecto, el subagent mostrara el resumen estandar definido
en `aps-scaffolder` (archivos creados, paquetes instalados, build status).
