# AGENTS.md

> **Archivo contractual del proyecto**: los agentes opencode (refactor-orchestrator,
> refactor-analyzer, refactor-worker-*) lo leen al arrancar para conocer la estructura
> concreta del repo. Mantener actualizado cuando se añadan o renombren proyectos.

Este archivo define cómo se estructura este repositorio concreto para que los agentes
de opencode (en `.opencode/agents/` y `.opencode/skills/`) puedan trabajar sobre él
de forma segura.

## Layer Map

Cada capa de la convención APS se mapea a un proyecto (o carpeta) real de este repo.
Los agentes usan esta tabla para saber dónde crear, buscar y modificar código.

| Capa | Path | Rol |
|---|---|---|
| `contracts` | (definir, p.ej. `src/{Proyecto}.Contracts/`) | Interfaces, modelos, requests/responses, excepciones |
| `crosscutting` | (definir, p.ej. `src/{SG-1}/`, `src/{SG-2}/`, ...) | Service Gateways y librerías transversales |
| `impl` | (definir, p.ej. `src/{Proyecto}.Impl/`) | Servicios, operaciones, mappers, comparers |
| `presentation` | (definir, p.ej. `src/{Proyecto}.API/`) | Azure Functions / Controllers ASP.NET Core |
| `tests` | (definir, p.ej. `src/{Proyecto}.Test*/`) | Tests unitarios MSTest v3 + NSubstitute + Shouldly |

### Convenciones por capa

- **Interfaces** (`I{Servicio}`): declaradas en `contracts`.
- **Implementaciones** (`CS{Servicio}`): declaradas en `impl`.
- **Endpoints / Functions**: declarados en `presentation`.
- **Contratos de Service Gateways (SG)**: viven en el assembly del propio SG
  (capa `crosscutting`), NO en `contracts`.
- **Operaciones** (servicios con Template Method): `OperationServiceBase` en `impl`,
  subclases `CS{Servicio}` también en `impl`.

## Tipo de host

(marcar uno)

- [ ] **FUNCTIONS** — Azure Functions Isolated Worker
- [ ] **WEBAPP** — ASP.NET Core Web App / API
- [ ] **NUGET_LIBRARY** — solo class libraries, sin capa de presentación

## Convenciones internas del proyecto

(añadir aquí cualquier convención que los agentes deban respetar)

- Naming:
  - Interfaces: prefijo `I` (`IOperationService`)
  - Clases concretas: prefijo `CS` (`CSBookingService`)
  - DTOs entrada: sufijo `Request`
  - DTOs salida: sufijo `Response`
  - Modelos de dominio: sufijo `Model`
  - Excepciones: sufijo `Exception`
- Versionado: fijar versiones en `Directory.Packages.props` (central package management).
- Tests:
  - Stack canonico: MSTest v3 + NSubstitute 5.x + Shouldly 4.x
  - Naming: `Metodo_Escenario_ResultadoEsperado`
  - Tests de caracterizacion (refactor multi-fase): sufijo `_Characterization`
- Patrones arquitectonicos:
  - (definir aquí, p.ej. Result pattern, CQRS, Template Method en OperationServiceBase)

## Service Gateways

| SG | Assembly | Publica NuGet | Workflow |
|---|---|---|---|
| (definir) | (definir) | Si/No | (definir, p.ej. `.github/workflows/publish.yml` que invoca `APS-Framework/.github/.github/workflows/nuget-ci-publish.yml@main`) |

Cuando un SG cambia su API pública, requiere publicar nueva version NuGet:
**se gestiona en un workflow separado, no en el commit de codigo**.

## Estructura del repositorio

```
.
+-- src/
|   +-- {Proyecto}.Contracts/
|   +-- {Proyecto}.Impl/
|   +-- {Proyecto}.API/
|   +-- {SG-1}/
|   +-- ...
+-- tests/
|   +-- {Proyecto}.Tests/
+-- .opencode/            # tooling opencode (no commitear cambios estructurales aqui sin PR)
+-- .opencode/plans/      # estado de refactors en curso (transitorio)
+-- Directory.Build.props
+-- Directory.Packages.props
+-- NuGet.config
+-- opencode.json
+-- AGENTS.md             # este archivo
```

## Notas para agentes

- Si necesitas contexto adicional del proyecto, pregunta al usuario antes de asumir.
- Tras un refactor, actualiza este archivo si la estructura ha cambiado
  (nuevo proyecto, SG renombrado, etc.).