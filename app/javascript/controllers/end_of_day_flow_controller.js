import { Controller } from "@hotwired/stimulus"

// Camp chip selection on end-of-day step 2.
export default class extends Controller {
  static targets = ["camp", "projectField"]

  connect() {
    if (this.hasCampTarget && this.campTargets.length === 1) {
      this.selectCamp({ currentTarget: this.campTargets[0] })
    }
  }

  selectCamp(event) {
    const button = event.currentTarget
    const projectId = button.dataset.projectId
    if (!projectId) return

    this.campTargets.forEach((el) => {
      el.classList.toggle("is-selected", el.dataset.projectId === projectId)
    })
    if (this.hasProjectFieldTarget) {
      this.projectFieldTarget.value = projectId
    }
  }
}
