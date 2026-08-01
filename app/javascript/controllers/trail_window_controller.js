import { Controller } from "@hotwired/stimulus"

// Vertical 3-slot trail window: previous cleared / current (largest) / next fogged.
// Shifts over the full node list without Turbo. Separate from strategy-plan-rail.
export default class extends Controller {
  static targets = ["node", "prev", "next", "explorer"]
  static values = { index: { type: Number, default: 0 } }

  connect() {
    this.render()
  }

  prev(event) {
    event?.preventDefault()
    if (this.indexValue <= 0) return
    this.indexValue -= 1
    this.render()
  }

  next(event) {
    event?.preventDefault()
    const max = this.nodeTargets.length - 1
    if (this.indexValue >= max) return
    this.indexValue += 1
    this.render()
  }

  indexValueChanged() {
    this.render()
  }

  render() {
    const nodes = this.nodeTargets
    if (!nodes.length) {
      this.syncControls(false, false)
      return
    }

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

    this.syncControls(focus > 0, focus < nodes.length - 1)
  }

  slotY(slot) {
    if (slot === "prev") return "18%"
    if (slot === "next") return "82%"
    return "50%"
  }

  syncControls(canPrev, canNext) {
    if (this.hasPrevTarget) {
      this.prevTarget.disabled = !canPrev
      this.prevTarget.setAttribute("aria-disabled", canPrev ? "false" : "true")
    }
    if (this.hasNextTarget) {
      this.nextTarget.disabled = !canNext
      this.nextTarget.setAttribute("aria-disabled", canNext ? "false" : "true")
    }
  }
}
