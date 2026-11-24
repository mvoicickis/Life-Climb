import { Controller } from "@hotwired/stimulus"

function isAndroid() {
  if (typeof navigator === "undefined") return false
  return /Android/i.test(navigator.userAgent || "")
}

export default class extends Controller {
  static targets = [ "defaultPanel", "androidPanel" ]

  connect() {
    if (!isAndroid()) return

    document.documentElement.classList.add("is-android")
    this.element.classList.add("is-android")
    if (this.hasDefaultPanelTarget) this.defaultPanelTarget.hidden = true
    if (this.hasAndroidPanelTarget) this.androidPanelTarget.hidden = false
  }
}

