import { Controller } from "@hotwired/stimulus"

// Progressive enhancement for the weekly planner item list.
// Without JS the add/remove/suggest forms POST normally and re-render.
// With JS, add/suggest/remove update the list client-side; Continue still POSTs.
export default class extends Controller {
  static targets = [
    "list",
    "row",
    "input",
    "addForm",
    "addButton",
    "continueForm",
    "continueButton",
    "hiddenFields"
  ]

  static values = {
    continueOne: String,
    continueOther: String
  }

  connect() {
    this.syncContinue()
  }

  add(event) {
    const title = (this.hasInputTarget ? this.inputTarget.value : "").trim()
    if (!title) return // let required/server handle blank

    event.preventDefault()
    this.appendItem(title)
    if (this.hasInputTarget) {
      this.inputTarget.value = ""
      this.inputTarget.focus()
    }
  }

  suggest(event) {
    const form = event.target
    const titleInput = form.querySelector('[name="value"]')
    const raw = titleInput?.value?.trim()
    if (!raw) return

    // Prefer visible label ("+ Install Linux") over task:ID for the list.
    const button = form.querySelector('button, input[type="submit"]')
    let label = (button?.textContent || button?.value || "").trim()
    if (label.startsWith("+")) label = label.slice(1).trim()

    event.preventDefault()
    this.appendItem(label || raw, raw.startsWith("task:") ? raw : null)
  }

  remove(event) {
    event.preventDefault()
    const form = event.target
    const row = form.closest("[data-weekly-planner-items-target='row']")
    if (row) row.remove()
    this.syncContinue()
  }

  prepareContinue(event) {
    if (!this.hasHiddenFieldsTarget) return

    this.hiddenFieldsTarget.innerHTML = ""
    this.titles().forEach((title) => {
      const input = document.createElement("input")
      input.type = "hidden"
      input.name = "items[][title]"
      input.value = title
      this.hiddenFieldsTarget.appendChild(input)
    })

    if (this.titles().length === 0) {
      event.preventDefault()
    }
  }

  appendItem(title, rawValue = null) {
    if (!this.hasListTarget) return

    const existing = this.titles().map((t) => t.toLowerCase())
    if (existing.includes(title.toLowerCase())) {
      this.syncContinue()
      return
    }

    const li = document.createElement("li")
    li.className = "lp-weekly-planner__item lp-glass flex items-center justify-between gap-3 px-3 py-2"
    li.dataset.weeklyPlannerItemsTarget = "row"
    li.dataset.title = title
    if (rawValue) li.dataset.rawValue = rawValue

    const span = document.createElement("span")
    span.className = "min-w-0 flex-1 font-semibold"
    span.textContent = title

    const removeBtn = document.createElement("button")
    removeBtn.type = "button"
    removeBtn.className = "lp-weekly-planner__remove text-sm font-bold"
    removeBtn.textContent = "Remove"
    removeBtn.addEventListener("click", () => {
      li.remove()
      this.syncContinue()
    })

    li.appendChild(span)
    li.appendChild(removeBtn)
    this.listTarget.appendChild(li)
    this.syncContinue()
  }

  titles() {
    if (!this.hasListTarget) return []
    return Array.from(this.listTarget.querySelectorAll("[data-title]"))
      .map((el) => el.dataset.title)
      .filter(Boolean)
  }

  syncContinue() {
    const count = this.titles().length
    if (this.hasContinueButtonTarget) {
      this.continueButtonTarget.disabled = count === 0
      if (count > 0) {
        const template = count === 1 ? this.continueOneValue : this.continueOtherValue
        this.continueButtonTarget.value = template.replace("%{count}", String(count))
      }
    }
    if (this.hasListTarget) {
      this.listTarget.dataset.weeklyPlannerItemsEmpty = count === 0 ? "true" : "false"
    }
  }
}
