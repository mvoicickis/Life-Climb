import { Controller } from "@hotwired/stimulus"
import { enqueue, release } from "lib/lp_overlay_queue"
import { haptic, sound, prefersReducedMotion } from "lib/lp_feedback"

const OVERLAY_OPEN = "lp-overlay-open"

// Full-screen all-battles-won finale — waits on the overlay queue.
export default class extends Controller {
  static targets = [ "battlesCount", "battlesLabel" ]
  static values = {
    shareText: String,
    shareToast: String,
    battles: Number,
    battlesLabelOne: String,
    battlesLabelOther: String
  }

  connect() {
    this.element.hidden = true
    this._onBeforeVisit = () => this.clearOverlayOpen()
    document.addEventListener("turbo:before-visit", this._onBeforeVisit)
    enqueue("finale", {
      open: () => this.reveal(),
      onFail: () => release("finale")
    })
  }

  disconnect() {
    document.removeEventListener("turbo:before-visit", this._onBeforeVisit)
    this.clearOverlayOpen()
    release("finale")
  }

  reveal() {
    if (!this.element.isConnected) {
      release("finale")
      return
    }
    this.element.hidden = false
    this.markOverlayOpen()
    const reduce = prefersReducedMotion()
    this.element.classList.add("is-final")
    if (!reduce) this.element.classList.add("is-impact")
    sound("all_won")
    haptic([ 20, 40, 20 ])
    this.revealBattlesCount()
  }

  setBattlesLabel(count) {
    if (!this.hasBattlesLabelTarget) return
    const label = count === 1 ? this.battlesLabelOneValue : this.battlesLabelOtherValue
    if (label) this.battlesLabelTarget.textContent = label
  }

  revealBattlesCount() {
    const to = this.battlesValue || 0
    this.setBattlesLabel(to)
    if (!this.hasBattlesCountTarget) return
    const reduce = prefersReducedMotion()
    if (reduce) {
      this.battlesCountTarget.textContent = String(to)
    } else {
      this.countUp(this.battlesCountTarget, to, 700)
    }
  }

  continue(event) {
    event?.preventDefault?.()
    this.clearOverlayOpen()
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

  markOverlayOpen() {
    document.body.classList.add(OVERLAY_OPEN)
  }

  clearOverlayOpen() {
    document.body.classList.remove(OVERLAY_OPEN)
  }
}
