import { Controller } from "@hotwired/stimulus"
import { parseTrailDeepLink } from "lib/trail_deep_link"
import { consumeDeepLinkOpenOnSheet, setPendingDeepLinkOpen } from "lib/trail_deep_link_open"

// First landing after v2 onboarding — goal plaque, curve camps land, tap tent to open sheet.
export default class extends Controller {
  static targets = [
    "overlay",
    "skipHint",
    "summit"
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
    this._deepLinkDismissStarted = false

    const deepLink = parseTrailDeepLink()
    if (deepLink.campId) {
      void this.enterFromDeepLink(deepLink)
      return
    }

    this.element.dataset.trailSuppressOpen = "1"
    this.bindFirstCampTap()
    this.playReveal()
  }

  disconnect() {
    this._token += 1
    this.unbindFirstCampTap()
  }

  async enterFromDeepLink({ campId, openComposer }) {
    if (this._deepLinkDismissStarted) return
    this._deepLinkDismissStarted = true

    try {
      if (this.hasDismissUrlValue) {
        const response = await fetch(this.dismissUrlValue, {
          method: "PATCH",
          headers: {
            Accept: "text/vnd.turbo-stream.html",
            "X-CSRF-Token": this.csrfToken()
          },
          credentials: "same-origin"
        })

        if (response.ok) {
          const html = await response.text()
          if (html.includes("turbo-stream")) {
            window.Turbo?.renderStreamMessage?.(html)
          }
        }
      }
    } catch (_error) {
      // Local finish + open below — reveal may return on next visit.
    } finally {
      this.finish()
      this.element.setAttribute("data-trail-camp-sheet-reveal-pending-value", "false")

      setPendingDeepLinkOpen(this.element, { campId, openComposer })
      const sheet = this.application.getControllerForElementAndIdentifier(this.element, "trail-camp-sheet")
      consumeDeepLinkOpenOnSheet(sheet)
    }
  }

  csrfToken() {
    return document.querySelector("meta[name='csrf-token']")?.content || ""
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

      await this.landTerraceCamps(token)
      if (token !== this._token) return

      await this.wait(400, token)
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

  async landTerraceCamps(token) {
    const camps = this.campsValue || []
    const timers = camps.map((camp) => {
      return new Promise((resolve) => {
        window.setTimeout(() => {
          if (token !== this._token) {
            resolve(false)
            return
          }
          this.landCamp(camp.id)
          resolve(true)
        }, camp.delay_ms || 0)
      })
    })

    await Promise.all(timers)
    return true
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
