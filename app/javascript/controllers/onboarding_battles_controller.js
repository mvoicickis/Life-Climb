import { Controller } from "@hotwired/stimulus"
import { TITLE_MAX, attachTitleLimit } from "lib/title_limit"

// Onboarding battles step — add/remove rows, enable Finish when at least one title.
export default class extends Controller {
  static targets = ["list", "row", "input", "submit", "form"]
  static values = {
    max: { type: Number, default: 5 },
    atMaxTemplate: { type: String, default: "%{count} of %{max} letters used" }
  }

  connect() {
    this.refresh()
  }

  add(event) {
    event.preventDefault()
    if (this.inputTargets.length >= this.maxValue) return

    const row = document.createElement("div")
    row.className = "lp-adventure__battle-row"
    row.dataset.onboardingBattlesTarget = "row"
    const placeholder = this.inputTargets[0]?.placeholder || ""
    row.innerHTML = `
      <div class="lp-title-limit lp-adventure__battle-field" data-controller="title-limit"
           data-title-limit-at-max-template-value="${this.atMaxTemplateValue.replace(/"/g, "&quot;")}">
        <input type="text"
               name="onboarding[battle_titles][]"
               maxlength="${TITLE_MAX}"
               class="lp-input w-full"
               autocomplete="off"
               placeholder="${placeholder.replace(/"/g, "&quot;")}"
               aria-describedby="adventure-battles-examples"
               data-onboarding-battles-target="input"
               data-action="input->onboarding-battles#refresh">
        <p class="lp-title-limit__count" data-title-limit-target="count" hidden role="status"></p>
      </div>
      <button type="button"
              class="lp-adventure__battle-remove"
              data-action="onboarding-battles#remove"
              aria-label="Remove">×</button>`
    const input = row.querySelector("input")

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
