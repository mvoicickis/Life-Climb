import { Controller } from "@hotwired/stimulus"

// Post–FirstClimb Mountain tour chips (steps 2–7). Advances on real trail events.
export default class extends Controller {
  static targets = ["chip", "step", "text", "icon"]
  static values = {
    ack: { type: Number, default: 0 },
    url: String,
    camps: { type: Number, default: 0 },
    hasBattles: { type: Boolean, default: false },
    hasWins: { type: Boolean, default: false }
  }

  connect() {
    this._onKey = null
    this.refresh()
  }

  refresh() {
    const coach = this.currentCoach()
    if (!coach || !this.hasChipTarget) {
      this.chipTarget?.setAttribute("hidden", "")
      return
    }
    this.chipTarget.removeAttribute("hidden")
    if (this.hasStepTarget) this.stepTarget.textContent = `Step ${coach.n} of 7`
    if (this.hasTextTarget) this.textTarget.textContent = coach.text
    if (this.hasIconTarget) this.iconTarget.textContent = coach.icon
  }

  currentCoach() {
    const ack = this.ackValue
    if (ack >= 7) return null

    if (this.campsValue <= 0) {
      return { n: 2, icon: "⛳", text: "Tap a glowing signpost to plant your first project." }
    }
    if (!this.hasBattlesValue) {
      return { n: 3, icon: "⚔", text: "Open your project and add today’s battle." }
    }
    if (!this.hasWinsValue) {
      return { n: 4, icon: "✓", text: "Tick a battle to win it — that’s a day’s progress." }
    }
    if (ack < 5) {
      return { n: 5, icon: "🚩", text: "Tap your flag any time to rename your destination.", canAck: true }
    }
    if (ack < 6) {
      return { n: 6, icon: "📊", text: "Your XP and camps done live in the bar up top.", canAck: true }
    }
    if (ack < 7) {
      return { n: 7, icon: "📔", text: "Every number you log becomes a stat under Journey.", canAck: true }
    }
    return null
  }

  async ack(event) {
    event?.preventDefault()
    const coach = this.currentCoach()
    if (!coach?.canAck) return
    await this.persist(Math.max(this.ackValue, coach.n))
    this.refresh()
  }

  async skip(event) {
    event?.preventDefault()
    await this.persist(7)
    this.refresh()
  }

  async persist(ack) {
    this.ackValue = ack
    const url = this.urlValue
    if (!url) return
    const token = document.querySelector("meta[name='csrf-token']")?.content
    const body = new URLSearchParams()
    body.set("ack", String(ack))
    body.set("authenticity_token", token || "")
    try {
      await fetch(url, {
        method: "PATCH",
        headers: {
          "X-CSRF-Token": token || "",
          Accept: "text/plain"
        },
        body,
        credentials: "same-origin"
      })
    } catch (_e) {
      // Keep local ack so the chip still dismisses.
    }
  }

  // Called from trail-canvas / camp-sheet via CustomEvent on #mountain-trail
  notePlanted() {
    this.campsValue = Math.max(this.campsValue, 1)
    this.refresh()
  }

  noteBattleAdded() {
    this.hasBattlesValue = true
    this.refresh()
  }

  noteBattleWon() {
    this.hasWinsValue = true
    this.refresh()
  }
}
