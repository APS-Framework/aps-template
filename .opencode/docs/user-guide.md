# Guía de uso de opencode en proyectos APS

Esta guía explica qué commands y agents están disponibles, cuándo usar cada
uno y cómo se relacionan entre sí. Está orientada al usuario que trabaja con
un repo creado desde el APS Framework Template.

---

## Índice

1. [Setup inicial](#1-setup-inicial)
2. [Crear proyectos](#2-crear-proyectos)
3. [Añadir features](#3-añadir-features)
4. [Refactorizar código existente](#4-refactorizar-código-existente)
5. [Investigar y corregir bugs](#5-investigar-y-corregir-bugs)
6. [Hotfixes en producción](#6-hotfixes-en-producción)
7. [CI/CD](#7-cicd)
8. [Recuperar sesiones interrumpidas](#8-recuperar-sesiones-interrumpidas)
9. [Referencia rápida de commands](#9-referencia-rápida-de-commands)
10. [Referencia rápida de agents](#10-referencia-rápida-de-agents)

---

## 1. Setup inicial

### `/aps-onboard`

Conecta el repo con tu organización de GitHub y prepara el MCP server.

**Cuándo ejecutarlo**: la primera vez que clonas el repo, al cambiar de
máquina, o cuando `dotnet restore` falla con 401/403 contra feeds privados.

```
/aps-onboard
```

**Qué hace**:
- Verifica `gh` CLI instalado y autenticado
- Detecta el repo y la org con `gh repo view`
- Configura `APS_NUGET_TOKEN` y `GITHUB_TOKEN` como variables de usuario
- Genera/actualiza `NuGet.config` con la org detectada
- Ajusta `opencode.json` (MCP discovery)
- Instala `@APS-Framework/sdk-mcp-server` si no está presente
- Pregunta antes de arrancar el MCP server

**Qué NO hace**: no valida `dotnet`, `func` ni `az`. Esas herramientas las
verifican los agentes que las necesitan, bajo demanda.

> **Importante**: tras ejecutarlo, abre una terminal nueva y reinicia
> opencode si el script lo indica.

---

## 2. Crear proyectos

### `/aps-new-function`

Crea una Azure Function App (Isolated Worker, .NET 8) con paquetes APS.

```
/aps-new-function MiFunction "function que procesa pedidos y los guarda en Cosmos"
```

### `/aps-new-webapp`

Crea una ASP.NET Core Web App (.NET 8) con paquetes APS.

```
/aps-new-webapp MiApi "web api con login con Google"
```

### `/aps-new-gateway`

Crea un Service Gateway: class library con interfaz Refit, modelos,
IoCExtensions y csproj con `dotnet pack`.

```
/aps-new-gateway Airpricing "API REST de precios y horarios de vuelos"
```

### `/aps-add-package`

Añade un paquete APS a un proyecto existente y configura el wiring básico.

```
/aps-add-package APS.Messaging.EventGrid
/aps-add-package APS.Data.Cosmos src/MiProyecto
```

### Qué hacen estos commands

El agente `aps-scaffolder`:
1. Detecta paquetes APS necesarios a partir de la descripción (keywords)
2. Genera el scaffold desde plantillas (csproj, Program.cs, handler de
   ejemplo, tests mínimos)
3. Registra el proyecto en el `.sln` si existe
4. Ejecuta `dotnet restore` + `build` + `test` si hay token configurado
5. Actualiza `AGENTS.md` (Layer Map, tipo de host, tabla de SGs)

> Si `APS_NUGET_TOKEN` no está configurado, el scaffolder crea el proyecto
> pero omite el restore. Ejecuta `/aps-onboard` para conectar.

---

## 3. Añadir features

### `/add-feature`

Crea una funcionalidad nueva que no existe: endpoint HTTP, servicio de
dominio, job/trigger, event handler, o opción de configuración.

```
/add-feature POST /api/bookings que crea una reserva
/add-feature GET /api/passengers/{id}
/add-feature job que reconcilia pagos pendientes cada 5 minutos
/add-feature opción de configuración para habilitar dry-run en refunds
```

**Qué hace el orchestrator**:
1. Valida la estructura del proyecto (skill `project-structure`)
2. Analiza reutilización (¿hay un servicio existente que cubre el caso?)
3. Evalúa configuración necesaria (`IXxxOptions`)
4. Verifica impacto en API pública
5. **PREFLIGHT de tests**: verifica cobertura de componentes tangenciales
   antes de tocar código. Si hay gaps, crea tests de caracterización primero
6. Presenta el plan completo y espera aprobación explícita
7. Ejecuta workers por capa: Contracts → Impl → Presentation → Tests
8. Verifica con `dotnet build` + `dotnet test` (nuevos + regresión)

> **Soporta non-HTTP triggers**: Timer, Service Bus, Event Grid. Describe
> el trigger en el argumento y el skill decide el patrón adecuado.

---

## 4. Refactorizar código existente

### Paso 1: `/refactor-plan`

Analiza el impacto de un refactor **sin modificar nada**. Produce un
informe con archivos afectados por capa, tipo de cambio, nivel de riesgo,
gaps de tests y estrategia recomendada.

```
/refactor-plan renombrar IBookingService a IFlightBookingService
/refactor-plan adoptar Result pattern en operaciones de reserva
/refactor-plan añadir sufijo Async a todos los métodos async
```

> Siempre ejecuta `/refactor-plan` antes de `/refactor-start`.

### Paso 2: `/refactor-start`

Ejecuta el refactor previamente analizado. El orchestrator:

1. Carga el informe del analyzer
2. Detecta si requiere modo multi-fase (alto riesgo, muchas áreas)
3. **PREFLIGHT de tests**: si hay gaps CRÍTICO/ALTO, crea tests de
   caracterización del comportamiento actual antes de tocar código
4. Presenta el plan y espera aprobación explícita
5. Delega en workers especializados por capa
6. Verifica con `dotnet build` + `dotnet test`
7. Propone commit (requiere confirmación explícita)

```
/refactor-start
```

### Cuándo usar refactor simple vs multi-fase

El orchestrator lo detecta automáticamente:

| Condición | Modo |
|---|---|
| Riesgo ALTO y ≥30 archivos | Multi-fase |
| ≥2 áreas semánticas distintas | Multi-fase |
| Gaps de tests CRÍTICO/ALTO | Multi-fase |
| Ninguna de las anteriores | Simple |

En modo multi-fase, el orchestrator:
- Crea tests de caracterización antes de tocar código (PREFLIGHT)
- Descompone el refactor en fases lógicas
- Pide aprobación antes de cada fase
- Commit único al final de todas las fases

---

## 5. Investigar y corregir bugs

### `/investigate-bug`

Investiga un bug con reproducción automatizada. Útil cuando el bug no es
evidente solo leyendo el código y necesitas reproducirlo para entender la
causa raíz.

```
/investigate-bug POST /api/refunds devuelve total incorrecto cuando hay multiples documentos
/investigate-bug el campo passenger.email llega como null en algun flujo
/investigate-bug timer de reconciliacion no se dispara cada 5 minutos
```

**Flujo**:
1. Recopila el informe (síntoma, input, output esperado vs actual, frecuencia)
2. Rastrea la ruta de código sospechosa
3. **PREFLIGHT de tests**: verifica cobertura de los componentes afectados.
   Si no hay, crea tests de caracterización del comportamiento actual
4. Elige estrategia de reproducción: test unitario, integration, inspección,
   o estadística (bugs intermitentes)
5. Ciclo de hipótesis-validación (máx 5 iteraciones)
6. Aplica el fix mínimo
7. Limpieza obligatoria de instrumentación temporal (`Console.WriteLine`, etc.)
8. Verifica: test del bug + tests de caracterización + suite completa
9. Propone commit `fix(<scope>): ...`

> **Limitación**: no sustituye a un debugger interactivo (VS/Rider). Es un
> asistente de debugging automatizado, equivalente a lo que harías con
> `Console.WriteLine` pero con disciplina.

---

## 6. Hotfixes en producción

### `/hotfix`

Fix rápido para bugs en producción. Sin ciclo de hipótesis ni
instrumentación: inspección directa, fix mínimo, test de regresión.

```
/hotfix POST /api/refunds devuelve 500 cuando amount es 0
/hotfix el campo passenger.email llega null cuando el booking no tiene profile
```

**Cuándo usar hotfix vs investigate-bug**:

| Criterio | `/hotfix` | `/investigate-bug` |
|---|---|---|
| Causa raíz evidente por inspección | ✅ | — |
| Necesitas reproducir para entender | — | ✅ |
| Velocidad优先 (producción) | ✅ | — |
| Bug intermitente | — | ✅ |

**Flujo del hotfix**:
1. Recopila síntoma + input + output
2. Localiza la ruta de código
3. **PREFLIGHT de tests**: verifica cobertura. Si no hay, crea tests de
   caracterización primero
4. Confirma causa raíz por inspección
5. Aplica fix mínimo
6. Verifica: tests nuevos + suite completa (regresión)
7. Propone commit `hotfix(<scope>): ...`
8. Recuerda cherry-pick a rama de release

> **No instrumentar**: si sientes que necesitas `Console.WriteLine` o
> breakpoints, el bug no es candidato para hotfix. Usa `/investigate-bug`.

---

## 7. CI/CD

### `/aps-new-workflow`

Genera callers mínimos para los workflows reutilizables de
[`APS-Framework/.github`](https://github.com/APS-Framework/.github) invocando
las tools del MCP.

```
/aps-new-workflow          # ci + deploy (lo que aplique)
/aps-new-workflow ci       # solo CI (build + test + publish NuGet)
/aps-new-workflow deploy   # solo deploy
```

**Qué genera según el tipo de host**:

| Tipo de host | `ci` | `deploy` |
|---|---|---|
| FUNCTIONS | `publish.yml` | `deploy.yml` (azure-functions-deploy) |
| WEBAPP | `publish.yml` | — (no hay workflow reutilizable) |
| NUGET_LIBRARY / SG | `publish.yml` | — |
| Container App | `publish.yml` | `deploy.yml` (container-app-deploy) |

> Los workflows no se crean desde cero: el scaffolder invoca las tools
> `github__publish`, `github__deploy_functions`, `github__deploy_container_app`
> del MCP para obtener los templates correctos. Si los workflows
> reutilizables cambian, las tools se actualizan y los callers generados
> serán correctos sin cambios en este template.

**Secrets y variables**: el resumen del command indica qué secrets y
variables debes configurar en GitHub. El scaffolder no los configura.

---

## 8. Recuperar sesiones interrumpidas

### `/refactor-verify`

Retoma un refactor que se interrumpió (sesión cerrada, crash, etc.).

```
/refactor-verify
```

**Qué hace**:
1. Escanea `.opencode/plans/` buscando `state.md` con `## Estado: en curso`
2. Si encuentra uno: presenta descripción, fase actual y workers pendientes
3. Ejecuta `dotnet build` + `dotnet test`
4. Si PASS: muestra `git diff --stat` y propone commit
5. Si FAIL: muestra errores y sugiere qué worker re-ejecutar

> Si hay varios refactors en curso, pregunta cuál retomar.

---

## 9. Referencia rápida de commands

| Command | Agente | Qué hace | Cuándo |
|---|---|---|---|
| `/aps-onboard` | aps-onboarder | Conecta repo con org de GitHub + MCP | Primera vez, cambio de máquina |
| `/aps-new-function` | aps-scaffolder | Crea Azure Function App | Nuevo proyecto Function |
| `/aps-new-webapp` | aps-scaffolder | Crea ASP.NET Core Web App | Nuevo proyecto WebApp |
| `/aps-new-gateway` | aps-scaffolder | Crea Service Gateway | Nuevo SG (Refit client) |
| `/aps-add-package` | aps-scaffolder | Añade paquete APS a proyecto existente | Extender capacidades |
| `/aps-new-workflow` | aps-scaffolder | Genera callers CI/CD | Configurar pipelines |
| `/add-feature` | refactor-orchestrator | Crea feature nueva | Endpoint, servicio, job, config |
| `/refactor-plan` | refactor-analyzer | Analiza impacto (read-only) | Antes de refactor |
| `/refactor-start` | refactor-orchestrator | Ejecuta refactor | Tras `/refactor-plan` |
| `/refactor-verify` | refactor-orchestrator | Retoma refactor interrumpido | Sesión cortada |
| `/investigate-bug` | refactor-orchestrator | Investiga bug con reproducción | Bug no evidente |
| `/hotfix` | refactor-orchestrator | Fix rápido en producción | Bug evidente, urgente |

---

## 10. Referencia rápida de agents

### Agents visibles (invocables directamente)

| Agent | Modelo | Rol |
|---|---|---|
| `aps-onboarder` | MiniMax-M2.7-highspeed | Onboarding local: gh CLI, NuGet.config, MCP server |
| `aps-scaffolder` | MiniMax-M3 | Scaffolding: Functions, WebApps, SGs, workflows, paquetes |
| `refactor-orchestrator` | (default) | Coordina refactors, features, bugfixes, hotfixes |

### Agents internos (no invocar directamente)

| Agent | Rol | Cuándo actúa |
|---|---|---|
| `refactor-analyzer` | Análisis de impacto read-only | Invocado por `/refactor-plan` |
| `refactor-verifier` | Build + test + propuesta de commit | Invocado por el orchestrator |
| `refactor-worker-contracts` | Cambios en capa Contracts | Invocado por el orchestrator |
| `refactor-worker-crosscutting` | Cambios en Service Gateways | Invocado por el orchestrator |
| `refactor-worker-impl` | Cambios en capa Impl | Invocado por el orchestrator |
| `refactor-worker-presentation` | Cambios en capa Presentation | Invocado por el orchestrator |
| `refactor-worker-tests` | Cambios en capa Tests | Invocado por el orchestrator (siempre último) |

> Los workers están **aislados por permisos**: cada uno solo puede editar
> archivos de su capa. No pueden ejecutar bash ni invocar otros agentes.

---

## Reglas universales

### PREFLIGHT de tests (todos los flujos)

Antes de generar cualquier código (refactor, feature, bugfix, hotfix), el
orchestrator verifica que existe cobertura de tests para todo el código que
se va a tocar, aunque sea tangencialmente.

- Si hay gaps → crea tests de caracterización del comportamiento actual
- Los tests deben compilar y pasar antes de tocar código de producción
- Commit separado: `test(characterization): add characterization tests for ...`

### Criterio de cierre (todos los flujos)

Para dar por correcta cualquier actuación, `dotnet build` + `dotnet test`
deben confirmar que pasan **ambos** conjuntos:

1. **Tests nuevos** (creados durante la sesión)
2. **Tests existentes** (regresión — toda la suite del proyecto)

Si cualquiera falla, el flujo no puede cerrarse.

### Aprobación explícita

Ningún flujo hace commit automático. El commit siempre requiere
confirmación explícita del usuario.

### MCP como fuente de verdad

Los agentes invocan las tools del MCP en runtime para obtener:

- Contratos de paquetes APS (tier `api`)
- Documentación de paquetes (tier `readme_sdk`/`readme_dev`)
- Operaciones git y validación de docs (tool `github__git_ops`)
- Templates de workflows CI/CD (tools `github__publish`, `github__deploy_*`)
- Generación de READMEs (tools `github__docs_sdk`, `github__docs_dev`)

**No reproducir** el contenido de las tools en skills/agents: invocarlas y
seguir sus instrucciones. Si la política cambia, la tool se actualiza y los
agentes leen la versión correcta automáticamente.

---

## Stack de tests

Todos los proyectos usan el mismo stack:

- **MSTest v3** — `[TestClass]`, `[TestMethod]`, `EnableMSTestRunner`
- **NSubstitute 5.x** — `Substitute.For<IInterface>()`, `.Returns()`, `.Received()`
- **Shouldly 4.x** — `result.ShouldBe(expected)`, `action.ShouldThrow<TException>()`
- Naming: `Metodo_Escenario_ResultadoEsperado`

---

## AGENTS.md

El archivo `AGENTS.md` en la raíz del repo es el **archivo contractual** que
los agentes leen al arrancar para conocer la estructura del proyecto:

- **Layer Map**: mapea cada capa (contracts, impl, presentation, tests,
  crosscutting) a las rutas reales del repo
- **Tipo de host**: FUNCTIONS, WEBAPP, o NUGET_LIBRARY
- **Convenciones internas**: naming, patrones arquitectónicos
- **Service Gateways**: tabla de SGs con assembly y workflow de publicación

Mantén `AGENTS.md` actualizado cuando añadas o renombres proyectos. El
scaffolder lo actualiza automáticamente tras crear un proyecto nuevo.
