import { Controller } from "@hotwired/stimulus"

const OVERLAY_OPEN = "lp-overlay-open"

// One-time Base Camp intro sheet before the real base camp sheet opens.
export default class extends Controller {
  static targets = ["overlay"]
  static values = {
    dismissUrl: String
  }

  connect() {
    this._onBeforeVisit = () => this.clearOverlayOpen()
    document.addEventListener("turbo:before-visit", this._onBeforeVisit)
  }

  disconnect() {
    document.removeEventListener("turbo:before-visit", this._onBeforeVisit)
    this.clearOverlayOpen()
  }

  interceptOpen(event) {
    if (!this.hasOverlayTarget) return
    if (!this.overlayTarget.hidden) return

    event.preventDefault()
    event.stopImmediatePropagation()
    this.overlayTarget.hidden = false
    this.markOverlayOpen()
  }

  async dismiss() {
    if (this.dismissUrlValue) {
      try {
        const token = document.querySelector("meta[name='csrf-token']")?.content
        const response = await fetch(this.dismissUrlValue, {
          method: "PATCH",
          headers: {
            "X-CSRF-Token": token,
            Accept: "text/vnd.turbo-stream.html"
          },
          credentials: "same-origin"
        })
        if (!response.ok) throw new Error("not saved")
      } catch (_e) {
        // still close — user can open Base Camp
      }
    }
    this.overlayTarget.hidden = true
    this.clearOverlayOpen()
    window.dispatchEvent(new CustomEvent("base-camp-intro:resume-open"))
  }

  resumeOpenBase() {
    const trail = document.getElementById("mountain-trail")
    if (!trail) return
    const sheet = this.application.getControllerForElementAndIdentifier(trail, "trail-camp-sheet")
    sheet?.openBase()
  }

  markOverlayOpen() {
    document.body.classList.add(OVERLAY_OPEN)
  }

  clearOverlayOpen() {
    document.body.classList.remove(OVERLAY_OPEN)
  }
}
