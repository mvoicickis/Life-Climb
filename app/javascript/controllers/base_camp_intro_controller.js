import { Controller } from "@hotwired/stimulus"

// One-time Base Camp intro sheet before the real base camp sheet opens.
export default class extends Controller {
  static targets = ["overlay"]
  static values = {
    dismissUrl: String
  }

  interceptOpen(event) {
    if (!this.hasOverlayTarget) return
    if (!this.overlayTarget.hidden) return

    event.preventDefault()
    event.stopImmediatePropagation()
    this.overlayTarget.hidden = false
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
    window.dispatchEvent(new CustomEvent("base-camp-intro:resume-open"))
  }

  resumeOpenBase() {
    const trail = document.getElementById("mountain-trail")
    if (!trail) return
    const sheet = this.application.getControllerForElementAndIdentifier(trail, "trail-camp-sheet")
    sheet?.openBase()
  }
}