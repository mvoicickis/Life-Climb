import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  skip(event) {
    event.preventDefault()
    if (typeof window.__lpDismissAppWelcome === "function") {
      window.__lpDismissAppWelcome()
    }
  }
}
