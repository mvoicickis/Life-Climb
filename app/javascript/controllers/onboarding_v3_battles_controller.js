import { Controller } from "@hotwired/stimulus"

// Onboarding v3 battles step — add rows, enable Done planning when at least one battle title.
export default class extends Controller {
  static targets = ["list", "addInput", "submit", "form"]

  connect() {
    this.refresh()
  }

  add(event) {
    event.preventDefault()
    const title = this.addInputTarget.value.trim()
    if (!title) {
      this.addInputTarget.focus()
      return
    }

    const li = document.createElement("li")
    li.className = "lp-ob-battles__row"
    li.innerHTML = `
      <span class="lp-ob-battles__ring" aria-hidden="true"></span>
      <span class="lp-ob-battles__label"></span>
      <input type="hidden" name="onboarding[battle_titles][]" value="">`
    li.querySelector(".lp-ob-battles__label").textContent = title
    li.querySelector("input").value = title
    this.listTarget.appendChild(li)
    this.addInputTarget.value = ""
    this.addInputTarget.focus()
    this.refresh()
  }

  addFromEnter(event) {
    if (event.key !== "Enter") return
    event.preventDefault()
    this.add(event)
  }

  refresh() {
    const count = this.listTarget.querySelectorAll("input[type='hidden']").length
    if (this.hasSubmitTarget) this.submitTarget.disabled = count < 1
  }
}