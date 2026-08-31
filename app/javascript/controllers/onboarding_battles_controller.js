import { Controller } from "@hotwired/stimulus"

// Onboarding battles step — add/remove rows, enable Finish when at least one title.
export default class extends Controller {
  static targets = ["list", "row", "input", "submit", "form"]
  static values = { max: { type: Number, default: 5 } }

  connect() {
    this.refresh()
  }

  add(event) {
    event.preventDefault()
    if (this.inputTargets.length >= this.maxValue) return

    const row = document.createElement("div")
    row.className = "lp-adventure__battle-row"
    row.dataset.onboardingBattlesTarget = "row"
    row.innerHTML = `
      <input type="text"
             name="onboarding[battle_titles][]"
             maxlength="120"
             class="lp-input w-full"
             autocomplete="off"
             placeholder=""
             data-onboarding-battles-target="input"
             data-action="input->onboarding-battles#refresh">
      <button type="button"
              class="lp-adventure__battle-remove"
              data-action="onboarding-battles#remove"
              aria-label="Remove">×</button>`
    const placeholder = this.inputTargets[0]?.placeholder
    const input = row.querySelector("input")
    if (placeholder) input.placeholder = placeholder

    this.listTarget.appendChild(row)
    input.focus()
    this.refresh()
  }

  remove(event) {
    event.preventDefault()
    const row = event.currentTarget.closest("[data-onboarding-battles-target='row']")
    if (!row || this.rowTargets.length <= 1) return
    row.remove()
    this.refresh()
  }

  refresh() {
    const hasBattle = this.inputTargets.some((el) => el.value.trim().length > 0)
    if (this.hasSubmitTarget) this.submitTarget.disabled = !hasBattle

    this.rowTargets.forEach((row) => {
      const btn = row.querySelector(".lp-adventure__battle-remove")
      if (btn) btn.disabled = this.rowTargets.length <= 1
    })
  }
}
