---
description: Crea una nueva ASP.NET Core Web App con APS Framework a partir de una descripcion. Uso: /aps-new-webapp [nombre] [descripcion...]
agent: aps-scaffolder
model: minimax/MiniMax-M3
---

# /aps-new-webapp

Crea un nuevo proyecto ASP.NET Core Web App (.NET 8) que use paquetes de
APS Framework, a partir de la descripcion del usuario.

## Argumentos

- `$1` (opcional) = nombre del proyecto en PascalCase. Si se omite, preguntar.
- `$ARGUMENTS` (opcional) = descripcion en lenguaje natural de lo que hace
  la webapp. Si se omite, preguntar.

## Comportamiento

Cargar subagent `aps-scaffolder` con el procedimiento completo.
Ademas:

- **Tipo de proyecto**: Web App (siempre)
- **Plantilla**: `aps-webapp-template`
- **Ruta por defecto**: `./src/{NombreProyecto}/` (o la que indique el usuario)

## Diferencias con /aps-new-function

- SDK del csproj: `Microsoft.NET.Sdk.Web` (no `Microsoft.NET.Sdk`)
- No genera `host.json` ni `local.settings.json`
- Genera `Controllers/SampleController.cs` en vez de `Functions/SampleFunction.cs`
- `Program.cs` usa `WebApplication.CreateBuilder` y `app.MapControllers`
- Tests usan `Microsoft.AspNetCore.Mvc.Testing` para `WebApplicationFactory<Program>`

## Ejemplos de uso

```
/aps-new-webapp
/aps-new-webapp OrdersApi
/aps-new-webapp OrdersApi web api para gestionar pedidos
/aps-new-webapp AuthApi "web api con login con Google que expone /api/me"
```

## Interaccion esperada con el usuario

Si faltan el nombre o la descripcion, el subagent preguntara usando la
herramienta `question`. Las preguntas seran concretas, con 2-4 opciones y
campo libre.

Tras crear el proyecto, el subagent mostrara el resumen estandar definido
en `aps-scaffolder` (archivos creados, paquetes instalados, build status).
