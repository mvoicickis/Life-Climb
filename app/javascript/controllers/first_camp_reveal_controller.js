import { Controller } from "@hotwired/stimulus"

const TRAIL_DRAW_MS = 1600

// First landing after v2 onboarding — summit, trail draw, camps land, tap tent to open sheet.
export default class extends Controller {
  static targets = [
    "overlay",
    "skipHint",
    "summit",
    "trailLine",
    "trailGlow",
    "spine"
  ]

  static values = {
    campId: String,
    camps: Array,
    dismissUrl: String,
    skipHint: String
  }

  connect() {
    if (!this.hasCampIdValue) return

    this._token = 0
    this._finished = false
    this._tapReady = false
    this._trailLength = 0

    this.element.dataset.trailSuppressOpen = "1"
    this.unhideSpine()
    this.resetTrailDraw()
    this.bindFirstCampTap()
    this.playReveal()
  }

  disconnect() {
    this._token += 1
    this.unbindFirstCampTap()
  }

  finish() {
    if (this._finished) return
    this._finished = true
    this._tapReady = false
    this._token += 1
    this.unbindFirstCampTap()
    delete this.element.dataset.trailSuppressOpen
    this.element.classList.remove("is-first-camp-reveal", "is-focus-camp", "is-awaiting-tap")
    this.overlayTarget?.remove()
    const sheet = this.application.getControllerForElementAndIdentifier(this.element, "trail-camp-sheet")
    if (sheet?._openCampId) {
      sheet.revealBodyFor({ dataset: { campId: sheet._openCampId } })
    }
  }

  async playReveal() {
    const token = this._token

    try {
      if (this.prefersReducedMotion()) {
        this.recoverToTapReady()
        return
      }

      await this.wait(500, token)
      if (token !== this._token) return

      this.showSummit()

      await this.wait(900, token)
      if (token !== this._token) return

      if (!(await this.animateTrailDraw(token))) return

      await this.wait(600, token)
      if (token !== this._token) return

      this.enterTapReady()
    } catch (error) {
      this.recoverToTapReady(error)
    }
  }

  recoverToTapReady(error) {
    if (error) {
      console.warn("first-camp-reveal: recoverToTapReady", error)
    }

    this._token += 1
    this.showFullTrail()
    this.landAllCamps()
    this.showSummit()
    this.element.classList.add("is-focus-camp")
    this.enterTapReady({ pulse: !this.prefersReducedMotion() })
  }

  enterTapReady({ pulse = true } = {}) {
    this._tapReady = true
    this.element.classList.add("is-focus-camp", "is-awaiting-tap")
    this.markCurrentCamp()
    if (pulse) this.firstCampEl()?.classList.add("is-pulsing")
    this.showSkipHint()
  }

  async animateTrailDraw(token) {
    const line = this.trailLineTarget
    const glow = this.trailGlowTarget
    const length = line.getTotalLength()
    this._trailLength = length

    if (!length) throw new Error("trail spine length is zero")

    line.style.strokeDasharray = `${length}`
    glow.style.strokeDasharray = `${length}`
    line.style.strokeDashoffset = `${length}`
    glow.style.strokeDashoffset = `${length}`

    const landed = new Set()
    const campFracs = this.campsValue || []

    return new Promise((resolve) => {
      const start = performance.now()

      const frame = (now) => {
        if (token !== this._token) {
          resolve(false)
          return
        }

        const progress = Math.min((now - start) / TRAIL_DRAW_MS, 1)
        const offset = length * (1 - progress)
        line.style.strokeDashoffset = `${offset}`
        glow.style.strokeDashoffset = `${offset}`

        campFracs.forEach((camp) => {
          if (!landed.has(camp.id) && progress >= camp.path_frac) {
            this.landCamp(camp.id)
            landed.add(camp.id)
          }
        })

        if (progress < 1) {
          requestAnimationFrame(frame)
        } else {
          resolve(true)
        }
      }

      requestAnimationFrame(frame)
    })
  }

  landCamp(campId) {
    const camp = this.element.querySelector(`#trail-camp-${campId}`)
    camp?.classList.add("is-landed")
  }

  landAllCamps() {
    this.element.querySelectorAll(".lp-trail-camp").forEach((camp) => {
      camp.classList.add("is-landed")
    })
  }

  markCurrentCamp() {
    this.firstCampEl()?.classList.add("is-current")
  }

  firstCampEl() {
    return this.element.querySelector(`#trail-camp-${this.campIdValue}`)
  }

  bindFirstCampTap() {
    const camp = this.firstCampEl()
    if (!camp) return

    this._onFirstCampClick = (event) => {
      if (!this._tapReady || this._finished) return
      if (!camp.classList.contains("is-landed")) return
      event.preventDefault()
      event.stopPropagation()
      this.openCampSheet(true)
    }
    camp.addEventListener("click", this._onFirstCampClick)
  }

  unbindFirstCampTap() {
    const camp = this.firstCampEl()
    if (camp && this._onFirstCampClick) {
      camp.removeEventListener("click", this._onFirstCampClick)
    }
    this._onFirstCampClick = null
  }

  openCampSheet(focusInput) {
    this.hideSkipHint()
    this.firstCampEl()?.classList.remove("is-pulsing")
    delete this.element.dataset.trailSuppressOpen
    if (this.hasOverlayTarget) {
      this.overlayTarget.hidden = true
      this.overlayTarget.setAttribute("aria-hidden", "true")
    }
    const sheet = this.application.getControllerForElementAndIdentifier(this.element, "trail-camp-sheet")
    sheet?.openCampById(this.campIdValue)
    if (focusInput) {
      requestAnimationFrame(() => {
        const input = this.element.querySelector("[data-first-camp-battle-target='titleField']")
        input?.focus({ preventScroll: true })
      })
    }
  }

  unhideSpine() {
    if (this.hasSpineTarget) {
      this.spineTarget.hidden = false
      this.spineTarget.removeAttribute("hidden")
    }
  }

  resetTrailDraw() {
    if (!this.hasTrailLineTarget || !this.hasTrailGlowTarget) return

    const length = this.trailLineTarget.getTotalLength()
    this._trailLength = length
    if (!length) return

    this.trailLineTarget.style.strokeDasharray = `${length}`
    this.trailGlowTarget.style.strokeDasharray = `${length}`

    if (this.prefersReducedMotion()) {
      this.showFullTrail()
    } else {
      this.trailLineTarget.style.strokeDashoffset = `${length}`
      this.trailGlowTarget.style.strokeDashoffset = `${length}`
    }
  }

  showFullTrail() {
    if (!this.hasTrailLineTarget || !this.hasTrailGlowTarget) return
    this.trailLineTarget.style.strokeDashoffset = "0"
    this.trailGlowTarget.style.strokeDashoffset = "0"
  }

  showSummit() {
    if (!this.hasSummitTarget) return
    this.summitTarget.classList.add("is-visible")
  }

  showSkipHint() {
    if (!this.hasSkipHintTarget) return
    this.skipHintTarget.classList.add("is-visible", "is-near-camp")
  }

  hideSkipHint() {
    if (!this.hasSkipHintTarget) return
    this.skipHintTarget.classList.remove("is-visible", "is-near-camp")
  }

  prefersReducedMotion() {
    return window.matchMedia("(prefers-reduced-motion: reduce)").matches
  }

  wait(ms, token) {
    return new Promise((resolve) => {
      window.setTimeout(() => resolve(token === this._token), ms)
    })
  }
}
