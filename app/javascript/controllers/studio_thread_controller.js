import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["story", "rail", "line"]

  connect() {
    requestAnimationFrame(() => {
      this.element.classList.add("is-drawn")
    })
  }
}
