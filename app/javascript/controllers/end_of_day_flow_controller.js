import { Controller } from "@hotwired/stimulus"

// Camp chip selection and optional today reveal on end-of-day step 2.
export default class extends Controller {
  static targets = ["camp", "projectField", "todayPrompt", "todayPanel", "todayProjectField"]

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
    if (this.hasTodayProjectFieldTarget) {
      this.todayProjectFieldTarget.value = projectId
    }
  }

  revealToday() {
    if (!this.hasTodayPromptTarget || !this.hasTodayPanelTarget) return

    this.todayPromptTarget.hidden = true
    this.todayPanelTarget.hidden = false
    this.todayPanelTarget.querySelector("input[type='text']")?.focus()
  }
}
