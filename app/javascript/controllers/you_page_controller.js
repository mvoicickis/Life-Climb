import { Controller } from "@hotwired/stimulus"

// You v2: expand companion/language cards, inline name edit.
export default class extends Controller {
  static targets = [
    "companionCard",
    "languageCard",
    "nameButton",
    "nameForm",
    "nameInput"
  ]

  connect() {
    if (this.element.dataset.youPageOpen === "character") {
      this.companionCardTarget?.classList.add("is-open")
    }
    if (this.element.dataset.youPageOpen === "language") {
      this.languageCardTarget?.classList.add("is-open")
    }
    if (this.element.dataset.youPageOpen === "name") this.editName()
  }

  toggleCompanion(event) {
    event.preventDefault()
    this.companionCardTarget?.classList.toggle("is-open")
  }

  toggleLanguage(event) {
    event.preventDefault()
    this.languageCardTarget?.classList.toggle("is-open")
  }

  editName(event) {
    event?.preventDefault()
    if (!this.hasNameFormTarget || !this.hasNameButtonTarget) return
    this.nameButtonTarget.hidden = true
    this.nameFormTarget.hidden = false
    this.nameInputTarget?.focus()
    this.nameInputTarget?.select()
  }

  nameKey(event) {
    if (event.key === "Escape") {
      event.preventDefault()
      this.cancelName()
    }
  }

  cancelName() {
    if (!this.hasNameFormTarget || !this.hasNameButtonTarget) return
    this.nameFormTarget.hidden = true
    this.nameButtonTarget.hidden = false
  }
}
