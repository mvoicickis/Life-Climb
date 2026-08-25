import { Controller } from "@hotwired/stimulus"

// Today V2 nav notch — Fight / End day / New day + toast nudges.
export default class extends Controller {
  static targets = [ "toast" ]
  static values = {
    fightToast: String,
    shareToast: String,
    recapText: String
  }

  fight(event) {
    event.preventDefault()
    this.showToast(this.fightToastValue || "Tap a battle above to fight it")
  }

  shareRecap(event) {
    event.preventDefault()
    const text = this.recapTextValue
    if (navigator.share && text) {
      navigator.share({ text }).catch(() => this.showToast(this.shareToastValue))
      return
    }
    if (text && navigator.clipboard?.writeText) {
      navigator.clipboard.writeText(text).then(() => {
        this.showToast(this.shareToastValue)
      }).catch(() => this.showToast(this.shareToastValue))
      return
    }
    this.showToast(this.shareToastValue)
  }

  showToast(message) {
    if (!message) return
    let node = this.hasToastTarget ? this.toastTarget : null
    if (!node) {
      node = document.createElement("div")
      node.className = "lp-today-v2-toast"
      node.setAttribute("data-today-notch-target", "toast")
      document.body.appendChild(node)
    }
    node.textContent = message
    node.hidden = false
    window.clearTimeout(this._timer)
    this._timer = window.setTimeout(() => {
      node.hidden = true
    }, 2200)
  }
}
