import { Controller } from "@hotwired/stimulus"
import { createPointerReorder } from "lib/pointer_reorder"

// Screen 2 camp list: add, reorder, inline edit, hidden camp_titles[] for submit.
export default class extends Controller {
  static targets = [
    "list",
    "ghosts",
    "addInput",
    "addButton",
    "addRow",
    "scrollBody",
    "submit",
    "hiddenFields",
    "form"
  ]

  static values = {
    maxLength: { type: Number, default: 120 },
    firstPlaceholder: String,
    nextPlaceholder: String
  }

  connect() {
    this.items = []
    this.dragId = null
    this.pointerReorder = null
    this._onViewportResize = () => this.syncKeyboardInset()
    this.loadInitialItems()
    this.syncUi()
    window.visualViewport?.addEventListener("resize", this._onViewportResize)
    window.visualViewport?.addEventListener("scroll", this._onViewportResize)
  }

  disconnect() {
    this.pointerReorder?.destroy()
    window.visualViewport?.removeEventListener("resize", this._onViewportResize)
    window.visualViewport?.removeEventListener("scroll", this._onViewportResize)
  }

  loadInitialItems() {
    if (!this.hasHiddenFieldsTarget) return

    this.hiddenFieldsTarget.querySelectorAll("input[name='onboarding[camp_titles][]']").forEach((input) => {
      const text = input.value.trim()
      if (text) this.items.push({ id: this.uid(), text })
    })
  }

  uid() {
    return `camp-${Math.random().toString(36).slice(2, 10)}`
  }

  focusAddInput(event) {
    if (!this.hasAddInputTarget) return
    this.addInputTarget.focus()
  }

  addFromButton(event) {
    event.preventDefault()
    this.submitAdd()
  }

  addFromEnter(event) {
    if (event.key !== "Enter") return
    event.preventDefault()
    this.submitAdd()
  }

  submitAdd() {
    if (!this.hasAddInputTarget) return
    if (this.addItem(this.addInputTarget.value)) {
      this.addInputTarget.value = ""
      this.addInputTarget.focus()
    }
  }

  addItem(text) {
    const trimmed = text.trim()
    if (!trimmed) return false
    this.items.push({ id: this.uid(), text: trimmed })
    this.syncUi()
    return true
  }

  syncUi() {
    this.pointerReorder?.cancelActiveDrag()

    const hasSteps = this.items.length > 0

    if (this.hasGhostsTarget) {
      this.ghostsTarget.classList.toggle("is-hidden", hasSteps)
    }

    if (this.hasSubmitTarget) {
      this.submitTarget.disabled = !hasSteps
      this.submitTarget.classList.toggle("lp-cta--ready", hasSteps)
    }

    if (this.hasAddButtonTarget) {
      this.addButtonTarget.classList.toggle("lp-ob-steps__add-btn--primary", !hasSteps)
    }

    if (this.hasAddInputTarget) {
      const placeholder = hasSteps ? this.nextPlaceholderValue : this.firstPlaceholderValue
      if (placeholder) this.addInputTarget.placeholder = placeholder
    }

    this.renderHiddenFields()
    this.renderList()
    this.bindDrag()
    this.syncKeyboardInset()
    this.scrollStepsToEnd()
  }

  syncKeyboardInset() {
    const viewport = window.visualViewport
    let keyboardInset = 0
    let keyboardOpen = false

    if (viewport) {
      const gap = window.innerHeight - viewport.height
      keyboardOpen = gap > 120
      if (keyboardOpen) keyboardInset = Math.max(0, gap)
    }

    this.element.classList.toggle("lp-ob--camps-keyboard-open", keyboardOpen)
    this.element.style.setProperty("--lp-ob-keyboard-inset", `${keyboardInset}px`)

    if (keyboardOpen) this.scrollStepsToEnd()
  }

  scrollStepsToEnd() {
    if (!this.hasScrollBodyTarget) return
    const el = this.scrollBodyTarget
    el.scrollTop = el.scrollHeight
  }

  bindDrag() {
    if (!this.hasListTarget) return

    this.pointerReorder?.destroy()
    this.pointerReorder = createPointerReorder({
      listRoot: this.listTarget,
      rowSelector: ".lp-ob-steps__row",
      handleSelector: ".lp-ob-steps__handle",
      placeholderClass: "lp-ob-steps__placeholder",
      draggingClass: "is-dragging",
      onReorder: () => {
        const rows = [...this.listTarget.querySelectorAll(".lp-ob-steps__row")]
        this.items = rows
          .map((row) => this.items.find((entry) => entry.id === row.dataset.id))
          .filter(Boolean)
        this.renderHiddenFields()
      }
    })
  }

  renderHiddenFields() {
    if (!this.hasHiddenFieldsTarget) return

    this.hiddenFieldsTarget.innerHTML = ""
    this.items.forEach((item) => {
      const input = document.createElement("input")
      input.type = "hidden"
      input.name = "onboarding[camp_titles][]"
      input.value = item.text
      this.hiddenFieldsTarget.appendChild(input)
    })
  }

  renderList() {
    if (!this.hasListTarget) return

    this.listTarget.innerHTML = ""
    this.items.forEach((item, index) => {
      this.listTarget.appendChild(this.buildRow(item, index))
    })
  }

  buildRow(item, index) {
    const li = document.createElement("li")
    li.className = "lp-ob-trail__item lp-ob-steps__row"
    li.dataset.id = item.id
    li.dataset.index = String(index)

    const stem = document.createElement("div")
    stem.className = "lp-ob-trail__stem"
    stem.setAttribute("aria-hidden", "true")

    const marker = document.createElement("span")
    marker.className = "lp-ob-trail__marker"
    marker.textContent = String(index + 1)

    const line = document.createElement("span")
    line.className = "lp-ob-trail__line"

    stem.appendChild(marker)
    stem.appendChild(line)

    const textBtn = document.createElement("button")
    textBtn.type = "button"
    textBtn.className = "lp-ob-trail__label lp-ob-steps__text"
    textBtn.textContent = item.text
    textBtn.addEventListener("click", () => this.beginEdit(item.id, textBtn))

    const handle = document.createElement("button")
    handle.type = "button"
    handle.className = "lp-ob-steps__handle"
    handle.setAttribute("aria-label", "Drag to reorder")
    handle.innerHTML = this.handleSvg()

    li.appendChild(stem)
    li.appendChild(textBtn)
    li.appendChild(handle)
    return li
  }

  handleSvg() {
    return '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="currentColor" aria-hidden="true"><circle cx="9" cy="7" r="1.5"/><circle cx="15" cy="7" r="1.5"/><circle cx="9" cy="12" r="1.5"/><circle cx="15" cy="12" r="1.5"/><circle cx="9" cy="17" r="1.5"/><circle cx="15" cy="17" r="1.5"/></svg>'
  }

  beginEdit(id, anchor) {
    const item = this.items.find((entry) => entry.id === id)
    if (!item) return

    const input = document.createElement("input")
    input.type = "text"
    input.className = "lp-ob-steps__edit"
    input.value = item.text
    input.maxLength = this.maxLengthValue

    const commit = () => {
      const next = input.value.trim()
      if (next) item.text = next
      this.syncUi()
    }

    input.addEventListener("keydown", (event) => {
      if (event.key === "Enter") {
        event.preventDefault()
        commit()
      } else if (event.key === "Escape") {
        event.preventDefault()
        this.syncUi()
      }
    })

    input.addEventListener("blur", commit)

    anchor.replaceWith(input)
    input.focus()
    input.select()
  }

  beforeSubmit(event) {
    if (this.items.length === 0) {
      event.preventDefault()
      return
    }
    this.renderHiddenFields()
  }
}
