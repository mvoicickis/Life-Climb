import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  pop(event) {
    const btn = event.currentTarget
    const row = btn.closest(".studio-quest")
    if (!row) return

    row.classList.add("is-popping")

    const amount = btn.dataset.lp || "10"
    const floater = document.createElement("span")
    floater.className = "studio-lp-float"
    floater.textContent = `+${amount} LP`
    row.appendChild(floater)

    requestAnimationFrame(() => floater.classList.add("is-shown"))
    window.setTimeout(() => floater.remove(), 900)
  }
}
