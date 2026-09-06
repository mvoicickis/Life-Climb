import { Controller } from "@hotwired/stimulus"

// Screen 2 camp list: add, reorder, inline edit, hidden camp_titles[] for submit.
export default class extends Controller {
  static targets = [
    "list",
    "ghosts",
    "addInput",
    "submit",
    "hiddenFields",
    "hint",
    "form"
  ]

  static values = {
    reorderHint: String,
    maxLength: { type: Number, default: 120 }
  }

  static HOLD_MS = 250
  static MOVE_CANCEL_PX = 8

  connect() {
    this.items = []
    this.dragId = null
    this.reorderHintShown = false
    this.loadInitialItems()
    this.syncUi()
  }

  disconnect() {
    this.cancelActiveDrag()
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
    this.cancelActiveDrag()

    if (this.hasGhostsTarget) {
      this.ghostsTarget.classList.toggle("is-hidden", this.items.length > 0)
    }
    if (this.hasSubmitTarget) {
      this.submitTarget.disabled = this.items.length === 0
    }
    this.renderHiddenFields()
    this.renderList()
    this.maybeShowReorderHint()
  }

  maybeShowReorderHint() {
    if (this.reorderHintShown || this.items.length < 2 || !this.hasHintTarget) return

    this.reorderHintShown = true
    this.hintTarget.textContent = this.reorderHintValue
    this.hintTarget.hidden = false
    this.hintTarget.removeAttribute("hidden")
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
    li.className = "lp-ob-steps__row"
    li.dataset.id = item.id
    li.dataset.index = String(index)

    const handle = document.createElement("button")
    handle.type = "button"
    handle.className = "lp-ob-steps__handle"
    handle.setAttribute("aria-label", "Drag to reorder")
    handle.innerHTML = this.handleSvg()
    handle.addEventListener("pointerdown", (event) => this.onHandlePointerDown(event))

    const textBtn = document.createElement("button")
    textBtn.type = "button"
    textBtn.className = "lp-ob-steps__text"
    textBtn.textContent = item.text
    textBtn.addEventListener("click", () => this.beginEdit(item.id, textBtn))

    li.appendChild(handle)
    li.appendChild(textBtn)
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

  onHandlePointerDown(event) {
    if (event.button !== 0) return

    const handle = event.currentTarget
    const row = handle.closest(".lp-ob-steps__row")
    if (!row || !this.hasListTarget) return

    const pointerId = event.pointerId
    const startX = event.clientX
    const startY = event.clientY
    let holdTimer = null
    let active = false

    const cleanupListeners = () => {
      document.removeEventListener("pointermove", onMove)
      document.removeEventListener("pointerup", onUp)
      document.removeEventListener("pointercancel", onUp)
    }

    const cancelHold = () => {
      if (holdTimer) {
        clearTimeout(holdTimer)
        holdTimer = null
      }
    }

    const onMove = (ev) => {
      if (ev.pointerId !== pointerId) return

      if (!active) {
        const dx = Math.abs(ev.clientX - startX)
        const dy = Math.abs(ev.clientY - startY)
        if (dx > this.constructor.MOVE_CANCEL_PX || dy > this.constructor.MOVE_CANCEL_PX) {
          cancelHold()
        }
        return
      }

      ev.preventDefault()
      this.updateDragPosition(ev.clientX, ev.clientY)
      this.updatePlaceholderPosition(ev.clientY)
    }

    const onUp = (ev) => {
      if (ev.pointerId !== pointerId) return

      cancelHold()
      cleanupListeners()

      if (active) {
        this.finishDrag(row)
      }

      handle.classList.remove("is-grabbing")
      this.activeDrag = null
    }

    holdTimer = setTimeout(() => {
      holdTimer = null
      active = true
      handle.classList.add("is-grabbing")
      this.startDrag(handle, row, pointerId, startY)
    }, this.constructor.HOLD_MS)

    document.addEventListener("pointermove", onMove)
    document.addEventListener("pointerup", onUp)
    document.addEventListener("pointercancel", onUp)
  }

  startDrag(handle, row, pointerId, startY) {
    const rowRect = row.getBoundingClientRect()
    const placeholder = document.createElement("li")
    placeholder.className = "lp-ob-steps__placeholder"
    placeholder.setAttribute("aria-hidden", "true")
    placeholder.style.height = `${rowRect.height}px`

    this.listTarget.insertBefore(placeholder, row)
    document.body.appendChild(row)

    row.classList.add("is-dragging")
    row.style.width = `${rowRect.width}px`
    row.style.left = `${rowRect.left}px`
    row.style.top = `${rowRect.top}px`

    try {
      handle.setPointerCapture(pointerId)
    } catch (_) {
      // capture may fail on some browsers
    }

    this.activeDrag = {
      handle,
      row,
      placeholder,
      pointerId,
      pointerOffsetY: startY - rowRect.top,
      anchorLeft: rowRect.left,
      dragId: row.dataset.id
    }
    this.dragId = row.dataset.id
  }

  updateDragPosition(clientX, clientY) {
    const drag = this.activeDrag
    if (!drag) return

    drag.row.style.top = `${clientY - drag.pointerOffsetY}px`
    drag.row.style.left = `${drag.anchorLeft}px`
  }

  updatePlaceholderPosition(clientY) {
    const drag = this.activeDrag
    if (!drag) return

    const rows = [...this.listTarget.querySelectorAll(".lp-ob-steps__row")]
    let inserted = false

    for (const other of rows) {
      const rect = other.getBoundingClientRect()
      const mid = rect.top + rect.height / 2
      if (clientY < mid) {
        this.listTarget.insertBefore(drag.placeholder, other)
        inserted = true
        break
      }
    }

    if (!inserted) {
      this.listTarget.appendChild(drag.placeholder)
    }
  }

  placeholderIndex() {
    const drag = this.activeDrag
    if (!drag) return -1

    let index = 0
    for (const child of this.listTarget.children) {
      if (child === drag.placeholder) return index
      if (child.classList.contains("lp-ob-steps__row")) index += 1
    }
    return index
  }

  finishDrag(row) {
    const drag = this.activeDrag
    if (!drag) return

    const from = this.items.findIndex((entry) => entry.id === drag.dragId)
    const to = this.placeholderIndex()

    if (from > -1 && to > -1 && from !== to) {
      const [moved] = this.items.splice(from, 1)
      this.items.splice(to, 0, moved)
      this.syncUi()
      return
    }

    this.teardownDragDom(row, drag)
    this.dragId = null
  }

  teardownDragDom(row, drag) {
    drag.placeholder.remove()
    row.classList.remove("is-dragging")
    row.style.width = ""
    row.style.left = ""
    row.style.top = ""
    this.listTarget.appendChild(row)

    try {
      drag.handle.releasePointerCapture(drag.pointerId)
    } catch (_) {
      // pointer already released
    }
  }

  cancelActiveDrag() {
    const drag = this.activeDrag
    if (!drag) return

    this.teardownDragDom(drag.row, drag)
    drag.handle.classList.remove("is-grabbing")
    this.activeDrag = null
    this.dragId = null
  }

  beforeSubmit(event) {
    if (this.items.length === 0) {
      event.preventDefault()
      return
    }
    this.renderHiddenFields()
  }
}
