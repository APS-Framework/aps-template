---
name: aps-deploy-template
description: Guía para generar callers de los workflows reutilizables de APS-Framework/.github mediante las tools del MCP. Carga cuando el agente aps-scaffolder va a crear o actualizar workflows de CI/CD.
license: MIT
compatibility: opencode
metadata:
  audience: aps-scaffolder
  workflow: ci-cd-scaffolding
---

# Callers para workflows reutilizables de APS-Framework

Los workflows de CI/CD **no se crean desde cero** ni se reproducen en este
skill. La organización `APS-Framework` mantiene workflows reutilizables en
el repo [`APS-Framework/.github`](https://github.com/APS-Framework/.github),
y el MCP expone tools que contienen las plantillas de caller, los inputs
requeridos y los secrets necesarios.

**Principio**: invocar las tools del MCP para obtener el contenido correcto
de cada caller. Si los workflows reutilizables cambian sus inputs o secrets,
las tools del MCP se actualizan y este skill no necesita cambios.

---

## Tools del MCP a invocar

| Tool | Cuándo invocarla | Qué devuelve |
|---|---|---|
| `github__publish` | Para CI + publicación NuGet | Template del caller `publish.yml`, inputs del workflow, secrets requeridos |
| `github__deploy_functions` | Para deploy de Azure Functions | Template del caller `deploy.yml`, inputs (`environment`, `function_app_name`, `project_path`), secrets OIDC requeridos |
| `github__deploy_container_app` | Para deploy de Azure Container Apps | Template del caller `deploy.yml`, inputs (`environment`, `acr_name`, `container_app_name`, `resource_group`, `container_repository`), secrets OIDC + variables requeridos |
| `github__setup` | Para configurar feed NuGet en CI | Configuración de `nuget.config` y credenciales para GitHub Actions |

> Las descripciones de cada tool en el MCP son la fuente de verdad. **No
> reproducir** el contenido de las tools en este skill: invocarlas y seguir
> sus instrucciones.

---

## Cuándo generar cada caller

| Tipo de repo | Callers a generar | Tool(s) a invocar |
|---|---|---|
| **SDK / NuGet library / SG** | `publish.yml` | `github__publish` |
| **Azure Functions** | `publish.yml` + `deploy.yml` | `github__publish` + `github__deploy_functions` |
| **Container App** | `publish.yml` + `deploy.yml` | `github__publish` + `github__deploy_container_app` |
| **Web App (App Service)** | `publish.yml` | `github__publish` (no hay workflow reutilizable para deploy directo) |

> Si el repo publica paquetes Y despliega una app, **ambos** callers
> coexisten en `.github/workflows/`.

---

## Procedimiento del scaffolder

1. Detectar el tipo de host del proyecto (`AGENTS.md` o csproj inspection)
2. Según la tabla anterior, invocar la(s) tool(s) del MCP correspondiente(s)
3. La tool devuelve el template del caller con los inputs y secrets correctos
4. Reemplazar placeholders (`{NombreProyecto}`, variables de entorno)
5. Crear los archivos en `.github/workflows/`
6. Si ya existe un caller, avisar antes de sobreescribir
7. Resumen al usuario con:
   - Archivos creados
   - Secrets de organización requeridos (según lo que devuelva la tool)
   - Variables de GitHub requeridas (según lo que devuelva la tool)
   - Como disparar el primer deploy o publicación

## Limitación

- **Web App (App Service)**: no hay workflow reutilizable para deploy
  directo. El caller `publish.yml` cubre CI. Para deploy, el usuario debe
  crear un workflow propio o usar Azure CLI manualmente.
