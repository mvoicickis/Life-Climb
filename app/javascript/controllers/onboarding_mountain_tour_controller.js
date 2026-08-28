import { Controller } from "@hotwired/stimulus"

// Five-bubble Mountain tour after new onboarding bootstrap.
export default class extends Controller {
  static targets = ["overlay", "spotlight", "bubble", "step", "text", "actions"]
  static values = {
    url: String,
    steps: Array
  }

  connect() {
    this.index = 0
    this.show()
    this._onResize = () => this.position()
    window.addEventListener("resize", this._onResize)
  }

  disconnect() {
    window.removeEventListener("resize", this._onResize)
  }

  show() {
    const step = this.stepsValue[this.index]
    if (!step) return

    this.overlayTarget.hidden = false
    this.overlayTarget.classList.add("is-active")
    this.bubbleTarget.hidden = false
    this.stepTarget.textContent = step.step
    this.textTarget.textContent = step.text
    this.actionsTarget.innerHTML = ""

    if (step.final) {
      this.spotlightTarget.hidden = true
      this.bubbleTarget.style.top = "50%"
      this.bubbleTarget.style.left = "50%"
      this.bubbleTarget.style.transform = "translate(-50%, -50%)"

      const btn = document.createElement("a")
      btn.href = step.todayUrl
      btn.className = "lp-onboarding-tour__cta"
      btn.textContent = step.todayLabel
      btn.dataset.turbo = "false"
      btn.addEventListener("click", () => this.persist())
      this.actionsTarget.appendChild(btn)
    } else {
      this.spotlightTarget.hidden = false
      this.bubbleTarget.style.transform = ""

      const skip = document.createElement("button")
      skip.type = "button"
      skip.className = "lp-onboarding-tour__skip"
      skip.textContent = step.skipLabel
      skip.addEventListener("click", () => this.dismiss())

      const next = document.createElement("button")
      next.type = "button"
      next.className = "lp-onboarding-tour__next"
      next.textContent = step.nextLabel
      next.addEventListener("click", () => this.next())

      this.actionsTarget.append(skip, next)
      this.position()
    }

    this.bubbleTarget.classList.add("is-visible")
  }

  position() {
    const step = this.stepsValue[this.index]
    if (!step || step.final) return

    const el = document.getElementById(step.target)
    if (!el) return

    const pad = 8
    const rect = el.getBoundingClientRect()
    this.spotlightTarget.style.top = `${rect.top - pad}px`
    this.spotlightTarget.style.left = `${rect.left - pad}px`
    this.spotlightTarget.style.width = `${rect.width + pad * 2}px`
    this.spotlightTarget.style.height = `${rect.height + pad * 2}px`

    let top = step.placement === "above" ? rect.top - this.bubbleTarget.offsetHeight - 12 : rect.bottom + 12
    let left = Math.max(12, Math.min(rect.left, window.innerWidth - this.bubbleTarget.offsetWidth - 12))
    if (top < 12) top = rect.bottom + 12
    this.bubbleTarget.style.top = `${top}px`
    this.bubbleTarget.style.left = `${left}px`
  }

  next() {
    this.index += 1
    this.bubbleTarget.classList.remove("is-visible")
    requestAnimationFrame(() => this.show())
  }

  dismiss() {
    this.persist()
    this.hide()
  }

  hide() {
    this.overlayTarget.classList.remove("is-active")
    this.bubbleTarget.classList.remove("is-visible")
    setTimeout(() => { this.overlayTarget.hidden = true }, 250)
  }

  async persist() {
    const url = this.urlValue
    if (!url) return
    const token = document.querySelector("meta[name='csrf-token']")?.content
    const body = new URLSearchParams()
    body.set("authenticity_token", token || "")
    try {
      await fetch(url, { method: "PATCH", headers: { Accept: "text/vnd.turbo-stream.html" }, body })
    } catch (_e) {
      // Tour is non-blocking; user can still climb.
    }
  }
}
