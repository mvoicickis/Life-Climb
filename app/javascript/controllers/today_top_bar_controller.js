import { Controller } from "@hotwired/stimulus"
import { play as playSound } from "lib/lp_sound"

// Frosted Today top bar — morph greeting → received cheer, then mark seen.
export default class extends Controller {
  static targets = ["greet", "cheer"]
  static values = {
    cheerId: Number,
    seenUrl: String,
    autoCheer: { type: Boolean, default: false }
  }

  connect() {
    if (!this.autoCheerValue || !this.hasCheerTarget) return
    this.markSeen()
    if (window.matchMedia("(prefers-reduced-motion: reduce)").matches) {
      this.element.classList.add("is-cheering")
      window.setTimeout(() => this.element.classList.remove("is-cheering"), 3000)
      return
    }
    window.requestAnimationFrame(() => this.playCheer())
  }

  playCheer() {
    this.element.classList.remove("is-leaving")
    this.element.classList.add("is-cheering")
    try { playSound("cheer") } catch (_err) { /* optional */ }
    try {
      if (typeof navigator.vibrate === "function") navigator.vibrate(10)
    } catch (_err) { /* optional */ }

    window.clearTimeout(this.hideTimer)
    window.clearTimeout(this.resetTimer)
    this.hideTimer = window.setTimeout(() => {
      this.element.classList.add("is-leaving")
      this.resetTimer = window.setTimeout(() => {
        this.element.classList.remove("is-cheering", "is-leaving")
      }, 340)
    }, 3000)
  }

  markSeen() {
    const url = this.seenUrlValue
    if (!url) return
    const token = document.querySelector("meta[name='csrf-token']")?.content
    fetch(url, {
      method: "POST",
      headers: {
        "X-CSRF-Token": token || "",
        Accept: "application/json"
      },
      credentials: "same-origin"
    }).catch(() => {})
  }

  disconnect() {
    window.clearTimeout(this.hideTimer)
    window.clearTimeout(this.resetTimer)
  }
}
