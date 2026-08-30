import { Controller } from "@hotwired/stimulus"

// Camp picker → battle title form on Today end-of-day bridge.
export default class extends Controller {
  static targets = ["camp", "picker", "form", "projectField", "titleField", "addAnother"]
  static values = { selectedProjectId: String }

  connect() {
    if (this.hasCampTarget && this.campTargets.length === 1) {
      this.selectCamp({ currentTarget: this.campTargets[0] })
    }
  }

  selectCamp(event) {
    const button = event.currentTarget
    const projectId = button.dataset.projectId
    if (!projectId) return

    this.selectedProjectIdValue = projectId
    this.campTargets.forEach((el) => {
      el.classList.toggle("is-selected", el.dataset.projectId === projectId)
    })
    if (this.hasProjectFieldTarget) {
      this.projectFieldTarget.value = projectId
    }
  }

  showForm() {
    if (!this.selectedProjectIdValue) return
    if (this.hasPickerTarget) this.pickerTarget.hidden = true
    if (this.hasFormTarget) {
      this.formTarget.hidden = false
      if (this.hasTitleFieldTarget) this.titleFieldTarget.focus()
    }
  }

  revealAddAnother() {
    if (this.hasAddAnotherTarget) this.addAnotherTarget.hidden = false
    if (this.hasFormTarget) this.formTarget.hidden = false
    if (this.hasTitleFieldTarget) {
      this.titleFieldTarget.value = ""
      this.titleFieldTarget.focus()
    }
  }
}
