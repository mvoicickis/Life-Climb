import { Controller } from "@hotwired/stimulus"

// Gentle lift → expand before entering the next expedition stage.
export default class extends Controller {
  enter(event) {
    const link = event.currentTarget
    if (!(link instanceof HTMLAnchorElement)) return
    if (event.metaKey || event.ctrlKey || event.shiftKey || event.altKey) return
    if (link.dataset.zooming === "1") return

    event.preventDefault()
    link.dataset.zooming = "1"
    link.classList.add("is-lifting")
    window.setTimeout(() => link.classList.add("is-expanding"), 90)
    window.setTimeout(() => {
      if (window.Turbo?.visit) {
        window.Turbo.visit(link.href)
      } else {
        window.location = link.href
      }
    }, 320)
  }
}
