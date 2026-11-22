import { Controller } from "@hotwired/stimulus"

// Soft highlight a battle row when opening Today from a push (?battle=todo_id).
export default class extends Controller {
  static values = {
    fadeMs: { type: Number, default: 2000 }
  }

  connect() {
    this.revealFromQuery()
  }

  disconnect() {
    if (this._highlightTimer) window.clearTimeout(this._highlightTimer)
  }

  revealFromQuery() {
    const params = new URLSearchParams(window.location.search)
    const battleId = params.get("battle")
    if (!battleId) return

    this.stripBattleParam()

    const row = this.element.querySelector(`[data-todo-id="${CSS.escape(battleId)}"]`)
    if (!row) return
    if (row.classList.contains("is-won-row") || row.classList.contains("is-struck")) return

    row.scrollIntoView({ block: "center", behavior: this.scrollBehavior() })
    row.classList.add("is-push-highlight")

    if (this.reducedMotion()) return

    this._highlightTimer = window.setTimeout(() => {
      row.classList.remove("is-push-highlight")
    }, this.fadeMsValue)
  }

  stripBattleParam() {
    const url = new URL(window.location.href)
    if (!url.searchParams.has("battle")) return
    url.searchParams.delete("battle")
    const next = `${url.pathname}${url.search}${url.hash}`
    window.history.replaceState(window.history.state, "", next)
  }

  reducedMotion() {
    return window.matchMedia("(prefers-reduced-motion: reduce)").matches
  }

  scrollBehavior() {
    return this.reducedMotion() ? "instant" : "smooth"
  }
}