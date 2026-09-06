import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [
    "form",
    "titleField",
    "todayBtn",
    "daysBtn",
    "weekdaysRow",
    "repeatField",
    "weekdayFields",
    "error"
  ]

  static values = {
    createUrl: String,
    needTitle: String,
    needDays: String
  }

  connect() {
    this._selectedDays = new Set()
    this.setMode("today")
  }

  pickToday(event) {
    event?.preventDefault()
    event?.stopPropagation()
    this.setMode("today")
  }

  pickDays(event) {
    event?.preventDefault()
    event?.stopPropagation()
    this.setMode("days")
  }

  toggleWeekday(event) {
    event?.preventDefault()
    event?.stopPropagation()
    const button = event.currentTarget
    const day = button.dataset.day
    if (this._selectedDays.has(day)) {
      this._selectedDays.delete(day)
      button.classList.remove("is-on")
    } else {
      this._selectedDays.add(day)
      button.classList.add("is-on")
    }
  }

  titleKeydown(event) {
    if (event.key !== "Enter") return
    event.preventDefault()
    this.formTarget.requestSubmit()
  }

  submit(event) {
    if (this.formTarget.dataset.confirmed === "true") {
      this.formTarget.dataset.confirmed = "false"
      return
    }

    event.preventDefault()
    this.clearError()

    const title = this.titleFieldTarget.value.trim()
    if (!title) {
      this.showError(this.needTitleValue)
      return
    }

    const weekly = this.repeatFieldTarget.value === "weekly"
    if (weekly && this._selectedDays.size === 0) {
      this.showError(this.needDaysValue)
      return
    }

    this.weekdayFieldsTarget.innerHTML = ""
    if (weekly) {
      this._selectedDays.forEach((day) => {
        const input = document.createElement("input")
        input.type = "hidden"
        input.name = "repeat_weekdays[]"
        input.value = day
        this.weekdayFieldsTarget.appendChild(input)
      })
    }

    this.formTarget.dataset.confirmed = "true"
    this.formTarget.requestSubmit()
  }

  saved(event) {
    if (!event.detail.success) return

    const reveal = this.application.getControllerForElementAndIdentifier(
      document.getElementById("mountain-trail"),
      "first-camp-reveal"
    )
    reveal?.finish()
  }

  setMode(mode) {
    const weekly = mode === "days"
    this.todayBtnTarget.classList.toggle("is-active", !weekly)
    this.daysBtnTarget.classList.toggle("is-active", weekly)
    this.weekdaysRowTarget.classList.toggle("is-visible", weekly)
    this.repeatFieldTarget.value = weekly ? "weekly" : "none"
  }

  showError(message) {
    if (!this.hasErrorTarget) return
    this.errorTarget.textContent = message
    this.errorTarget.hidden = false
    this.errorTarget.removeAttribute("hidden")
  }

  clearError() {
    if (!this.hasErrorTarget) return
    this.errorTarget.textContent = ""
    this.errorTarget.hidden = true
    this.errorTarget.setAttribute("hidden", "")
  }
}
