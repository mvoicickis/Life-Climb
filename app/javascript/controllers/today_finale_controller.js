import { Controller } from "@hotwired/stimulus"
import { enqueue, release } from "lib/lp_overlay_queue"
import { haptic, sound, prefersReducedMotion } from "lib/lp_feedback"

// Full-screen all-battles-won finale — waits on the overlay queue.
export default class extends Controller {
  static targets = [ "battlesCount" ]
  static values = {
    shareText: String,
    shareToast: String,
    battles: Number
  }

  connect() {
    this.element.hidden = true
    enqueue("finale", {
      open: () => this.reveal(),
      onFail: () => release("finale")
    })
  }

  disconnect() {
    release("finale")
  }

  reveal() {
    if (!this.element.isConnected) {
      release("finale")
      return
    }
    this.element.hidden = false
    const reduce = prefersReducedMotion()
    this.element.classList.add("is-final")
    if (!reduce) this.element.classList.add("is-impact")
    sound("all_won")
    haptic([ 20, 40, 20 ])
    if (this.hasBattlesCountTarget) {
      const to = this.battlesValue || 0
      if (reduce) {
        this.battlesCountTarget.textContent = String(to)
      } else {
        this.countUp(this.battlesCountTarget, to, 700)
      }
    }
  }

  continue(event) {
    event?.preventDefault?.()
    release("finale")
    this.element.remove()
  }

  share(event) {
    event?.preventDefault?.()
    const text = this.shareTextValue
    if (navigator.share && text) {
      navigator.share({ text }).catch(() => this.toast())
      return
    }
    if (text && navigator.clipboard?.writeText) {
      navigator.clipboard.writeText(text).then(() => this.toast()).catch(() => this.toast())
      return
    }
    this.toast()
  }

  toast() {
    const message = this.shareToastValue
    if (!message) return
    const root = document.getElementById("today-dash-root")
    const notch = root && this.application.getControllerForElementAndIdentifier(root, "today-notch")
    if (notch?.showToast) {
      notch.showToast(message)
      return
    }
    // Fallback toast
    const node = document.createElement("div")
    node.className = "lp-today-v2-toast"
    node.textContent = message
    document.body.appendChild(node)
    window.setTimeout(() => node.remove(), 2200)
  }

  countUp(el, to, ms) {
    const start = performance.now()
    const frame = (now) => {
      const t = Math.min(1, (now - start) / ms)
      el.textContent = String(Math.round((1 - Math.pow(1 - t, 3)) * to))
      if (t < 1) requestAnimationFrame(frame)
    }
    requestAnimationFrame(frame)
  }
}
