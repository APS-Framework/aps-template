import type { Plugin } from "@opencode-ai/plugin"
import { readdir, readFile } from "fs/promises"
import { join } from "path"

export const PendingPlansPlugin: Plugin = async ({ worktree, client }) => {
  await client.app.log({
    body: { service: "pending-plans", level: "info", message: `plugin loaded — worktree: ${worktree}` },
  })

  let checked = false

  const checkPlans = async () => {
    if (checked) return
    checked = true

    await client.app.log({
      body: { service: "pending-plans", level: "info", message: `scanning ${join(worktree, ".opencode", "plans")}` },
    })

    const plansDir = join(worktree, ".opencode", "plans")
    try {
      const folders = await readdir(plansDir, { withFileTypes: true })
      const pending: string[] = []

      for (const folder of folders.filter(f => f.isDirectory())) {
        const statePath = join(plansDir, folder.name, "state.md")
        try {
          const content = await readFile(statePath, "utf-8")
          if (content.includes("- [ ]")) {
            const match = content.match(/## Fase actual\r?\n(.+)/)
            const fase = match?.[1].trim() ?? "desconocida"
            pending.push(`${folder.name} → ${fase}`)
          }
        } catch { /* sin state.md, ignorar */ }
      }

      await client.app.log({
        body: { service: "pending-plans", level: "info", message: `planes pendientes: ${pending.length}` },
      })

      if (pending.length > 0) {
        await client.tui.showToast({
          body: {
            message: `${pending.length} plan(s) pendiente(s) — /refactor-verify para retomar`,
            variant: "warning",
          },
        })
      }
    } catch (err) {
      await client.app.log({
        body: { service: "pending-plans", level: "warn", message: `error: ${err}` },
      })
    }
  }

  return {
    event: async ({ event }) => {
      // session.created: sesión nueva (sin sesión previa)
      // session.idle:    sesión reanudada — dispara tras la primera respuesta IA
      if (event.type === "session.created" || event.type === "session.idle") {
        await checkPlans()
      }
    },
  }
}
