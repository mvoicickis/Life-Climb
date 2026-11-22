import { Controller } from "@hotwired/stimulus"

const MAX_LINES = 3

export default class extends Controller {
  static targets = [ "input" ]

  connect() {
    this.resize()
  }

  input() {
    this.resize()
  }

  keydown(event) {
    if (event.key !== "Enter") return
    event.stopPropagation()
  }

  resize() {
    if (!this.hasInputTarget) return

    const field = this.inputTarget
    const styles = getComputedStyle(field)
    const lineHeight = parseFloat(styles.lineHeight) || parseFloat(styles.fontSize) * 1.2
    const maxHeight = lineHeight * MAX_LINES

    field.style.height = "auto"
    field.style.overflow = "hidden"
    field.style.height = `${Math.min(field.scrollHeight, maxHeight)}px`
  }
}
