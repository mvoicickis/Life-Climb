import { Controller } from "@hotwired/stimulus"

// Animated first landing after v2 onboarding — summit, camps land, camp 1 sheet opens.
export default class extends Controller {
  static targets = [ "overlay", "skipHint" ]
  static values = {
    campId: String,
    dismissUrl: String,
    skipHint: String
  }

  connect() {
    if (!this.hasCampIdValue) return

    this._token = 0
    this._finished = false
    this.playReveal()
  }

  skip(event) {
    event?.preventDefault()
    event?.stopPropagation()
    this.skipToSheet()
  }

  skipToSheet() {
    if (this._finished) return
    this._token += 1
    this.landAllCamps()
    this.openCampSheet(true)
  }

  finish() {
    if (this._finished) return
    this._finished = true
    this._token += 1
    this.element.classList.remove("is-first-camp-reveal")
    this.overlayTarget?.remove()
    const sheet = this.application.getControllerForElementAndIdentifier(this.element, "trail-camp-sheet")
    if (sheet?._openCampId) {
      sheet.revealBodyFor({ dataset: { campId: sheet._openCampId } })
    }
  }

  async playReveal() {
    const token = this._token
    await this.wait(350, token)
    if (token !== this._token) return

    this.showSkipHint()

    await this.wait(700, token)
    if (token !== this._token) return

    await this.landCampsSequentially(token)
    if (token !== this._token) return

    this.element.classList.add("is-focus-camp")
    this.markCurrentCamp()

    await this.wait(500, token)
    if (token !== this._token) return

    this.openCampSheet(true)
  }

  async landCampsSequentially(token) {
    const camps = Array.from(this.element.querySelectorAll(".lp-trail-camp"))
    for (const camp of camps) {
      camp.classList.add("is-landed")
      await this.wait(550, token)
      if (token !== this._token) return
    }
  }

  landAllCamps() {
    this.element.querySelectorAll(".lp-trail-camp").forEach((camp) => {
      camp.classList.add("is-landed")
    })
    this.element.classList.add("is-focus-camp")
    this.markCurrentCamp()
    this.hideSkipHint()
  }

  markCurrentCamp() {
    const camp = this.element.querySelector(`#trail-camp-${this.campIdValue}`)
    camp?.classList.add("is-current")
  }

  openCampSheet(focusInput) {
    this.hideSkipHint()
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

  showSkipHint() {
    if (!this.hasSkipHintTarget) return
    this.skipHintTarget.classList.add("is-visible")
  }

  hideSkipHint() {
    if (!this.hasSkipHintTarget) return
    this.skipHintTarget.classList.remove("is-visible")
  }

  wait(ms, token) {
    return new Promise((resolve) => {
      window.setTimeout(() => resolve(token === this._token), ms)
    })
  }
}
