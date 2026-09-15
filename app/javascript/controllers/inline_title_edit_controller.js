import { Controller } from "@hotwired/stimulus"
import { TITLE_MAX, attachTitleLimit } from "lib/title_limit"
import { applyTurboStreamFromResponse } from "lib/apply_turbo_stream"

// Inline battle/todo title rename — PATCH strategy goal, apply turbo stream, re-focus when needed.
export default class extends Controller {
  static targets = ["display"]

  static values = {
    updateUrl: String,
    mode: { type: String, default: "camp" },
    battleId: Number,
    todoId: Number,
    atMaxTemplate: { type: String, default: "%{count} of %{max} letters used" }
  }

  openFromMenu(event) {
    event.preventDefault()
    event.stopPropagation()
    event.currentTarget.closest("details")?.removeAttribute("open")
    this.startEditing({ selectAll: true })
  }

  open(event) {
    event.preventDefault()
    event.stopPropagation()
    this.startEditing({ caretAtEnd: true })
  }

  resumeEditing(title, caretIndex) {
    this.startEditing({ initialValue: title, caretIndex })
  }

  startEditing({ selectAll = false, caretAtEnd = false, initialValue = null, caretIndex = null } = {}) {
    if (!this.hasDisplayTarget || !this.updateUrlValue) return
    if (this.element.querySelector("input.lp-inline-title-edit__input")) return

    const display = this.displayTarget
    const current = (initialValue ?? display.textContent).trim()
    display.hidden = true

    const input = document.createElement("input")
    input.type = "text"
    input.className =
      this.modeValue === "today"
        ? "lp-today-v2-row__title-input lp-inline-title-edit__input"
        : "lp-trail-battles__input lp-trail-battles__inline lp-inline-title-edit__input"
    input.maxLength = TITLE_MAX
    input.value = current

    const limit = attachTitleLimit(input, { template: this.atMaxTemplateValue })
    display.insertAdjacentElement("afterend", input)
    input.focus()

    if (caretIndex != null) {
      input.setSelectionRange(caretIndex, caretIndex)
    } else if (selectAll) {
      input.select()
    } else if (caretAtEnd) {
      const end = input.value.length
      input.setSelectionRange(end, end)
    }

    this._limit = limit
    this._input = input
    this._previous = current

    const onBlur = () => this.commit({ keepEditing: false })
    input.addEventListener("blur", onBlur)
    this._onBlur = onBlur

    input.addEventListener("keydown", (keyEvent) => {
      if (keyEvent.key === "Enter") {
        keyEvent.preventDefault()
        const keepEditing = this.modeValue === "today"
        this.commit({ keepEditing, caretIndex: input.selectionStart })
      }
      if (keyEvent.key === "Escape") {
        keyEvent.preventDefault()
        input.value = this._previous
        this.finishLocalEdit()
      }
    })
  }

  async commit({ keepEditing, caretIndex = null }) {
    if (!this._input) return

    const input = this._input
    const title = input.value.trim()
    const previous = this._previous
    const caret = caretIndex ?? input.selectionStart

    if (!title || title === previous) {
      this.finishLocalEdit()
      return
    }

    input.removeEventListener("blur", this._onBlur)
    this._limit?.detach()
    input.remove()
    if (this.hasDisplayTarget) this.displayTarget.hidden = false
    this._input = null

    const battleId = this.battleIdValue
    const todoId = this.todoIdValue
    const mode = this.modeValue

    const token = document.querySelector("meta[name='csrf-token']")?.content
    const body = new URLSearchParams()
    body.set("title", title)
    body.set("authenticity_token", token || "")

    const response = await fetch(this.updateUrlValue, {
      method: "PATCH",
      headers: {
        Accept: "text/vnd.turbo-stream.html, text/html",
        "X-CSRF-Token": token || ""
      },
      body,
      credentials: "same-origin"
    })

    const applied = await applyTurboStreamFromResponse(response)
    if (!applied || !keepEditing) return

    requestAnimationFrame(() => {
      const row = this.findRowElement(battleId, todoId, mode)
      if (!row) return
      const ctrl = this.application.getControllerForElementAndIdentifier(row, "inline-title-edit")
      ctrl?.resumeEditing(title, caret)
    })
  }

  finishLocalEdit() {
    if (this._onBlur && this._input) this._input.removeEventListener("blur", this._onBlur)
    this._limit?.detach()
    this._input?.remove()
    this._input = null
    if (this.hasDisplayTarget) this.displayTarget.hidden = false
  }

  findRowElement(battleId = this.battleIdValue, todoId = this.todoIdValue, mode = this.modeValue) {
    if (mode === "today" && todoId) {
      return document.getElementById(`daily_todo_${todoId}_battlefield_row`)
    }
    if (battleId) {
      return (
        document.getElementById(`trail-battle-${battleId}`) ||
        document.getElementById(`trail-base-battle-${battleId}`)
      )
    }
    return this.element.isConnected ? this.element : null
  }
}
