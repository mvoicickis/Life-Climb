import { Controller } from "@hotwired/stimulus"

// Lightweight confetti burst for quest complete (MVP).
export default class extends Controller {
  connect() {
    const colors = ["#166534", "#e0a82e", "#15803d", "#f5f6f3"]
    for (let i = 0; i < 18; i += 1) {
      const piece = document.createElement("span")
      piece.className = "lp-confetti__piece"
      piece.style.left = `${Math.random() * 100}%`
      piece.style.background = colors[i % colors.length]
      piece.style.animationDelay = `${Math.random() * 0.25}s`
      piece.style.setProperty("--dx", `${(Math.random() - 0.5) * 120}px`)
      this.element.appendChild(piece)
    }
    window.setTimeout(() => this.element.remove(), 1400)
  }
}
