import { Controller } from "@hotwired/stimulus"
import { enqueue, release } from "lib/lp_overlay_queue"
import { haptic, sound, prefersReducedMotion } from "lib/lp_feedback"

const PHASES = [
  "is-avatar",
  "is-flipping",
  "is-titled",
  "is-week",
  "is-running",
  "is-record",
  "is-cta",
  "is-final"
]

const CHECK_STAGGER_MS = 70

// Streak moment overlay on Today — brand white sequence, then optional commit + reminder.
export default class extends Controller {
  static targets = [
    "celebrate",
    "commit",
    "choices",
    "commitCta",
    "error",
    "reminderHost",
    "todayMark",
    "check"
  ]
  static values = {
    offerCommit: { type: Boolean, default: false },
    commitUrl: String,
    declineUrl: String,
    notSaved: String,
    commitCtaTemplate: String,
    shareText: String
  }

  connect() {
    this._busy = false
    this._timers = []
    this.element.hidden = true
    this.element.classList.add("is-queued")
    enqueue("streak", {
      open: () => this.reveal(),
      onFail: () => release("streak")
    })
  }

  reveal() {
    if (!this.element.isConnected) {
      release("streak")
      return
    }
    this.element.hidden = false
    this.element.classList.remove("is-queued")
    this.playSequence()
  }

  disconnect() {
    this.clearTimers()
    release("streak")
  }

  playSequence() {
    this.clearTimers()
    this.resetPhases()
    if (prefersReducedMotion()) {
      this.showFinal()
      return
    }

    // Timing kept from prior sequence (without fly/impact/Lottie):
    // avatar land → flip at 900 → week/running at 1300 → today + confetti → cta/final at 1800
    this.element.classList.add("is-avatar")

    this.later(() => {
      this.element.classList.add("is-flipping", "is-titled")
      sound("streak_tick")
    }, 900)

    this.later(() => {
      this.element.classList.add("is-week", "is-running")
      this.revealChecks()
    }, 1300)

    this.later(() => {
      this.element.classList.add("is-cta", "is-final")
    }, 1800)
  }

  showFinal() {
    this.resetPhases()
    this.element.classList.add(
      "is-avatar",
      "is-flipping",
      "is-titled",
      "is-week",
      "is-running",
      "is-cta",
      "is-final"
    )
    if (this.element.dataset.record === "true") this.element.classList.add("is-record")
    this.checkTargets.forEach((el) => el.classList.add("is-shown"))
    if (this.hasTodayMarkTarget) this.todayMarkTarget.classList.add("is-shown", "is-pop")
  }

  resetPhases() {
    this.element.classList.remove(...PHASES)
    this.checkTargets.forEach((el) => el.classList.remove("is-shown"))
    if (this.hasTodayMarkTarget) {
      this.todayMarkTarget.classList.remove("is-pop", "is-shown")
      this.todayMarkTarget.querySelectorAll(".lp-streak-moment__confetti").forEach((el) => el.remove())
    }
  }

  revealChecks() {
    this.checkTargets.forEach((el, i) => {
      this.later(() => el.classList.add("is-shown"), i * CHECK_STAGGER_MS)
    })
    const afterChecks = this.checkTargets.length * CHECK_STAGGER_MS
    this.later(() => {
      if (this.hasTodayMarkTarget) {
        this.todayMarkTarget.classList.add("is-shown", "is-pop")
        this.burstGreenConfetti()
        sound("tap")
        haptic([ 20, 40, 20 ])
      }
      if (this.element.dataset.record === "true") {
        this.element.classList.add("is-record")
      }
    }, afterChecks + 40)
  }

  burstGreenConfetti() {
    if (!this.hasTodayMarkTarget || prefersReducedMotion()) return
    const wrap = document.createElement("span")
    wrap.className = "lp-streak-moment__confetti"
    for (let i = 0; i < 12; i += 1) {
      const bit = document.createElement("i")
      const angle = (Math.PI * 2 * i) / 12
      const dist = 18 + Math.random() * 28
      bit.style.setProperty("--x", `${Math.cos(angle) * dist}px`)
      bit.style.setProperty("--y", `${Math.sin(angle) * dist}px`)
      wrap.appendChild(bit)
    }
    this.todayMarkTarget.appendChild(wrap)
    this.later(() => wrap.remove(), 700)
  }

  later(fn, ms) {
    const id = window.setTimeout(fn, ms)
    this._timers.push(id)
  }

  clearTimers() {
    this._timers.forEach((id) => window.clearTimeout(id))
    this._timers = []
  }

  dismiss(event) {
    event?.preventDefault?.()
    this.clearTimers()
    release("streak")
    this.element.remove()
  }

  continue(event) {
    event?.preventDefault?.()
    sound("tap")
    if (this.offerCommitValue && this.hasCommitTarget) {
      this.showCommit()
      return
    }
    this.dismiss()
  }

  share(event) {
    event?.preventDefault?.()
    sound("cheer")
    const text = this.shareTextValue
    if (navigator.share && text) {
      navigator.share({ text }).catch(() => {})
      return
    }
    if (text && navigator.clipboard?.writeText) {
      navigator.clipboard.writeText(text).catch(() => {})
    }
  }

  showCommit(event) {
    event?.preventDefault?.()
    if (!this.hasCommitTarget) {
      this.dismiss()
      return
    }
    if (this.hasCelebrateTarget) this.celebrateTarget.hidden = true
    this.commitTarget.hidden = false
    this.element.classList.add("is-card-mode")
  }

  selectDays(event) {
    event?.preventDefault?.()
    const button = event.currentTarget
    const days = Number(button.dataset.days)
    if (!days || !this.hasChoicesTarget) return

    this.choicesTarget.querySelectorAll(".lp-streak-moment__choice").forEach((el) => {
      const selected = el === button
      el.classList.toggle("is-selected", selected)
      el.setAttribute("aria-pressed", selected ? "true" : "false")
    })

    if (this.hasCommitCtaTarget) {
      this.commitCtaTarget.dataset.days = String(days)
      const template = this.commitCtaTemplateValue || "Commit to %{count} days"
      this.commitCtaTarget.textContent = template.replace("%{count}", String(days))
    }
  }

  async commit(event) {
    event?.preventDefault?.()
    if (this._busy) return

    const button = event.currentTarget
    const days = Number(button.dataset.days || this.commitCtaTarget?.dataset?.days)
    if (!days || !this.commitUrlValue) return

    this._busy = true
    this.clearError()
    button.disabled = true

    try {
      const response = await fetch(this.commitUrlValue, {
        method: "POST",
        credentials: "same-origin",
        headers: {
          Accept: "application/json",
          "Content-Type": "application/json",
          "X-CSRF-Token": this.csrfToken()
        },
        body: JSON.stringify({ days })
      })
      if (!response.ok) throw new Error("Request failed")
      const data = await response.json()
      const html = (data && data.html) || ""
      if (html.trim()) {
        this.showReminder(html)
      } else {
        this.dismiss()
      }
    } catch (error) {
      console.error(error)
      this.showError()
      button.disabled = false
    } finally {
      this._busy = false
    }
  }

  async decline(event) {
    event?.preventDefault?.()
    if (this._busy) return
    if (!this.declineUrlValue) {
      this.dismiss()
      return
    }

    this._busy = true
    this.clearError()
    const button = event.currentTarget
    button.disabled = true

    try {
      const response = await fetch(this.declineUrlValue, {
        method: "POST",
        credentials: "same-origin",
        headers: {
          Accept: "application/json",
          "X-CSRF-Token": this.csrfToken()
        }
      })
      if (!response.ok) throw new Error("Request failed")
      this.dismiss()
    } catch (error) {
      console.error(error)
      this.showError()
      button.disabled = false
    } finally {
      this._busy = false
    }
  }

  showReminder(html) {
    if (this.hasCelebrateTarget) this.celebrateTarget.hidden = true
    if (this.hasCommitTarget) this.commitTarget.hidden = true
    if (!this.hasReminderHostTarget) {
      this.dismiss()
      return
    }
    this.element.classList.add("is-card-mode")
    this.reminderHostTarget.hidden = false
    this.reminderHostTarget.innerHTML = html
  }

  onReminderClosed() {
    this.dismiss()
  }

  csrfToken() {
    return document.querySelector("meta[name='csrf-token']")?.content || ""
  }

  showError() {
    if (!this.hasErrorTarget) return
    this.errorTarget.textContent = this.notSavedValue || "Not saved. Tap to try again."
    this.errorTarget.hidden = false
  }

  clearError() {
    if (!this.hasErrorTarget) return
    this.errorTarget.hidden = true
    this.errorTarget.textContent = ""
  }
}
