import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = {
    dismissUrl: String
  }

  async dismissLater(event) {
    event.preventDefault()
    if (!this.hasDismissUrlValue) return

    try {
      await fetch(this.dismissUrlValue, {
        method: "PATCH",
        headers: {
          Accept: "text/vnd.turbo-stream.html",
          "X-CSRF-Token": this.csrfToken()
        },
        credentials: "same-origin"
      })
    } catch (_error) {
      return
    }

    const trail = document.getElementById("mountain-trail")
    const sheet = this.application.getControllerForElementAndIdentifier(trail, "trail-camp-sheet")
    sheet?.close()
  }

  csrfToken() {
    return document.querySelector("meta[name='csrf-token']")?.content || ""
  }
}
