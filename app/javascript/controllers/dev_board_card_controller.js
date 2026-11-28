import { Controller } from "@hotwired/stimulus"

// Dev board card — title tap shows description and reported-by line.
export default class extends Controller {
  toggle(event) {
    event?.preventDefault()
    this.element.classList.toggle("is-open")
    const open = this.element.classList.contains("is-open")
    event?.currentTarget?.setAttribute("aria-expanded", open ? "true" : "false")
  }
}
