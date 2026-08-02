import { Controller } from "@hotwired/stimulus"

// Camp folder disclosure — scroll an auto-opened folder into view on deep link.
export default class extends Controller {
  connect() {
    if (!this.element.open) return
    requestAnimationFrame(() => {
      this.element.scrollIntoView({ block: "nearest", inline: "nearest" })
    })
  }
}
