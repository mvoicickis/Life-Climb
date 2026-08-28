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
    this._onReflow = () => this.schedulePosition()
    this._scrollRoot = document.querySelector("#mountain-trail .lp-trail__scroll")

    window.addEventListener("resize", this._onReflow, { passive: true })
    window.addEventListener("scroll", this._onReflow, true)
    if (this._scrollRoot) this._scrollRoot.addEventListener("scroll", this._onReflow, { passive: true })

    this._resizeObserver = new ResizeObserver(() => this.schedulePosition())

    requestAnimationFrame(() => requestAnimationFrame(() => this.show()))
  }

  disconnect() {
    window.removeEventListener("resize", this._onReflow)
    window.removeEventListener("scroll", this._onReflow, true)
    if (this._scrollRoot) this._scrollRoot.removeEventListener("scroll", this._onReflow)
    this._resizeObserver?.disconnect()
    if (this._positionFrame) cancelAnimationFrame(this._positionFrame)
  }

  schedulePosition() {
    if (this._positionFrame) cancelAnimationFrame(this._positionFrame)
    this._positionFrame = requestAnimationFrame(() => {
      requestAnimationFrame(() => this.position())
    })
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
      this._resizeObserver.disconnect()
      this.spotlightTarget.hidden = true
      this.bubbleTarget.classList.add("is-centered")
      this.bubbleTarget.style.top = "50%"
      this.bubbleTarget.style.left = "50%"

      const btn = document.createElement("a")
      btn.href = step.todayUrl
      btn.className = "lp-onboarding-tour__cta"
      btn.textContent = step.todayLabel
      btn.dataset.turbo = "false"
      btn.addEventListener("click", () => this.persist())
      this.actionsTarget.appendChild(btn)
    } else {
      this.bubbleTarget.classList.remove("is-centered")
      this.bubbleTarget.style.top = ""
      this.bubbleTarget.style.left = ""
      this.spotlightTarget.hidden = false

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
      this.observeTarget(step.target)
      this.schedulePosition()
    }

    this.bubbleTarget.classList.add("is-visible")
  }

  observeTarget(targetId) {
    this._resizeObserver.disconnect()
    const el = this.targetElement(targetId)
    if (el) this._resizeObserver.observe(el)
  }

  targetElement(targetId) {
    return document.getElementById(targetId)
  }

  position() {
    const step = this.stepsValue[this.index]
    if (!step || step.final) return

    const el = this.targetElement(step.target)
    if (!el) return

    el.scrollIntoView({ block: "nearest", inline: "nearest", behavior: "instant" })

    const rect = el.getBoundingClientRect()
    if (rect.width <= 0 || rect.height <= 0) return

    const pad = 8
    const spotlight = this.spotlightTarget
    spotlight.style.top = `${rect.top - pad}px`
    spotlight.style.left = `${rect.left - pad}px`
    spotlight.style.width = `${rect.width + pad * 2}px`
    spotlight.style.height = `${rect.height + pad * 2}px`

    const bubble = this.bubbleTarget
    const margin = 12
    const bubbleW = bubble.offsetWidth || 264
    const bubbleH = bubble.offsetHeight || 120

    let top = step.placement === "above" ? rect.top - bubbleH - margin : rect.bottom + margin
    let left = rect.left + rect.width / 2 - bubbleW / 2
    left = Math.max(margin, Math.min(left, window.innerWidth - bubbleW - margin))

    if (top < margin) top = rect.bottom + margin
    if (top + bubbleH > window.innerHeight - margin) {
      top = Math.max(margin, rect.top - bubbleH - margin)
    }

    bubble.style.top = `${top}px`
    bubble.style.left = `${left}px`
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
