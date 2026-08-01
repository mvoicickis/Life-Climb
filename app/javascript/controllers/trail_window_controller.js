import { Controller } from "@hotwired/stimulus"

// Vertical 3-slot trail window: previous cleared / current (largest) / next fogged.
// Slot index comes from the server (focus_id). Camp switching is Turbo navigation —
// do not shift slots client-side or the battle sheet will desync.
export default class extends Controller {
  static targets = ["node", "explorer"]
  static values = { index: { type: Number, default: 0 } }

  connect() {
    this.render()
  }

  indexValueChanged() {
    this.render()
  }

  render() {
    const nodes = this.nodeTargets
    if (!nodes.length) return

    const focus = Math.min(Math.max(this.indexValue, 0), nodes.length - 1)
    if (focus !== this.indexValue) this.indexValue = focus

    const slotFor = {
      [focus - 1]: "prev",
      [focus]: "focus",
      [focus + 1]: "next"
    }

    nodes.forEach((el, i) => {
      const slot = slotFor[i] || null
      el.hidden = !slot
      el.classList.toggle("is-window-visible", Boolean(slot))
      el.classList.toggle("is-slot-prev", slot === "prev")
      el.classList.toggle("is-slot-focus", slot === "focus")
      el.classList.toggle("is-slot-next", slot === "next")
      if (slot) {
        el.style.setProperty("--lp-slot-y", this.slotY(slot))
      }
    })

    if (this.hasExplorerTarget) {
      this.explorerTarget.style.setProperty("--lp-y", this.slotY("focus"))
      this.explorerTarget.hidden = false
    }
  }

  slotY(slot) {
    if (slot === "prev") return "18%"
    if (slot === "next") return "82%"
    return "50%"
  }
}
