import { Controller } from "@hotwired/stimulus"
import { TITLE_MAX, attachTitleLimit } from "lib/title_limit"

// Daily toggle + title parsing + camp rename + session win toasts inside trail battle sheet.
export default class extends Controller {
  static targets = [
    "titleField", "repeatField", "dailyToggle", "quantityField", "quantityToggle",
    "unitField", "unitMirrorField", "unitWrap", "renameDialog", "renameField",
    "descriptionDialog", "descriptionField", "sessionToast", "addRow"
  ]

  static values = {
    sessionWins: { type: Number, default: 0 },
    keepDaily: { type: Boolean, default: false },
    createUrl: String,
    lifeAreaId: Number,
    lifeJourneyId: Number,
    parentId: Number,
    atMaxTemplate: { type: String, default: "%{count} of %{max} letters used" }
  }

  connect() {
    this.styleDailyRow()
    this.styleQuantityRow()
  }

  parseDraft(event) {
    if (!this.hasTitleFieldTarget) return

    if (this.hasRepeatFieldTarget) {
      const raw = this.titleFieldTarget.value || ""
      const match = raw.trim().match(/^(.*?)\s*(?:,?\s*)(daily|every day)$/i)
      if (match) {
        this.titleFieldTarget.value = match[1].trim()
        this.repeatFieldTarget.value = "daily"
        if (this.hasDailyToggleTarget) this.dailyToggleTarget.checked = true
      } else if (this.hasDailyToggleTarget && this.dailyToggleTarget.checked) {
        this.repeatFieldTarget.value = "daily"
      } else {
        this.repeatFieldTarget.value = "none"
      }
    }

    this.syncQuantityFields()

    if (!this.titleFieldTarget.value.trim()) {
      event.preventDefault()
      this.titleFieldTarget.focus()
    }
  }

  toggleDaily() {
    if (!this.hasRepeatFieldTarget || !this.hasDailyToggleTarget) return
    this.repeatFieldTarget.value = this.dailyToggleTarget.checked ? "daily" : "none"
    this.styleDailyRow()
  }

  toggleQuantity() {
    this.syncQuantityFields()
    this.styleQuantityRow()
  }

  syncQuantityFields() {
    const on = this.hasQuantityToggleTarget && this.quantityToggleTarget.checked
    if (this.hasQuantityFieldTarget) this.quantityFieldTarget.value = on ? "1" : "0"
    if (this.hasUnitFieldTarget) {
      if (on) {
        const mirror = this.hasUnitMirrorFieldTarget ? this.unitMirrorFieldTarget.value.trim() : ""
        this.unitFieldTarget.value = mirror || "pages"
      } else {
        this.unitFieldTarget.value = "times"
      }
    }
    if (this.hasUnitMirrorFieldTarget && on && !this.unitMirrorFieldTarget.value.trim()) {
      this.unitMirrorFieldTarget.value = "pages"
    }
    if (this.hasUnitWrapTarget) this.unitWrapTarget.hidden = !on
  }

  syncUnitMirror() {
    if (!this.hasUnitFieldTarget || !this.hasUnitMirrorFieldTarget) return

    this.unitFieldTarget.value = this.unitMirrorFieldTarget.value.trim() || "pages"
  }

  styleDailyRow() {
    if (!this.hasAddRowTarget || !this.hasDailyToggleTarget) return
    this.addRowTarget.classList.toggle("is-daily-on", this.dailyToggleTarget.checked)
  }

  styleQuantityRow() {
    if (!this.hasAddRowTarget) return
    const on = this.hasQuantityToggleTarget && this.quantityToggleTarget.checked
    this.addRowTarget.classList.toggle("is-qty-on", on)
  }

  editCamp(event) {
    event?.preventDefault()
    event?.stopPropagation()
    if (!this.hasRenameDialogTarget) return
    if (this.hasRenameFieldTarget) {
      this.renameFieldTarget.value = this.element.dataset.projectTitle || ""
    }
    this.renameDialogTarget.showModal?.() || (this.renameDialogTarget.open = true)
  }

  closeRename(event) {
    event?.preventDefault()
    this.renameDialogTarget?.close?.()
  }

  editCampDescription(event) {
    event?.preventDefault()
    event?.stopPropagation()
    if (!this.hasDescriptionDialogTarget) return
    if (this.hasDescriptionFieldTarget) {
      this.descriptionFieldTarget.value = this.element.dataset.projectDescription || ""
    }
    this.descriptionDialogTarget.showModal?.() || (this.descriptionDialogTarget.open = true)
  }

  closeDescription(event) {
    event?.preventDefault()
    this.descriptionDialogTarget?.close?.()
  }

  async saveCamp(event) {
    event.preventDefault()
    const url = this.element.dataset.updateUrl
    const title = this.hasRenameFieldTarget ? this.renameFieldTarget.value.trim() : ""
    if (!url || !title) return

    const token = document.querySelector("meta[name='csrf-token']")?.content
    const body = new URLSearchParams()
    body.set("title", title)
    body.set("authenticity_token", token || "")

    const response = await fetch(url, {
      method: "PATCH",
      headers: {
        Accept: "text/vnd.turbo-stream.html, text/html",
        "X-CSRF-Token": token || ""
      },
      body,
      credentials: "same-origin"
    })

    this.closeRename()
    if (response.redirected) {
      window.location.href = response.url
      return
    }
    window.location.reload()
  }

  async saveCampDescription(event) {
    event.preventDefault()
    const url = this.element.dataset.updateUrl
    if (!url) return

    const description = this.hasDescriptionFieldTarget ? this.descriptionFieldTarget.value.trim() : ""
    const token = document.querySelector("meta[name='csrf-token']")?.content
    const body = new URLSearchParams()
    body.set("description", description)
    body.set("authenticity_token", token || "")

    const response = await fetch(url, {
      method: "PATCH",
      headers: {
        Accept: "text/vnd.turbo-stream.html, text/html",
        "X-CSRF-Token": token || ""
      },
      body,
      credentials: "same-origin"
    })

    this.closeDescription()
    if (response.redirected) {
      window.location.href = response.url
      return
    }
    window.location.reload()
  }

  stashCampDelete() {
    // Session stash is written server-side in destroy; toast handled by turbo stream.
  }

  battleWon(event) {
    const { success } = event.detail || {}
    if (!success) return

    this.sessionWinsValue += 1
    this.showSessionToast(this.sessionWinsValue)
  }

  optimisticTick(event) {
    const row = event.target.closest?.(".lp-trail-battles__row")
    if (!row) return
    row.classList.add("is-ticking")
    row.querySelector(".lp-trail-battles__box")?.classList.add("is-won")
  }

  beginAddSubmit(event) {
    const form = event.target
    if (!form?.classList?.contains("lp-trail-battles__add")) return

    if (this._submitting) {
      event.preventDefault()
      return
    }
    this._submitting = true

    window.setTimeout(() => {
      form.querySelectorAll(".lp-trail-battles__submit").forEach((el) => {
        if (el.disabled) return
        el.disabled = true
        el.classList.add("is-pending")
        el.setAttribute("aria-busy", "true")
      })
    }, 0)
  }

  endAddSubmit(form) {
    this._submitting = false
    const root = form || this.element.querySelector(".lp-trail-battles__add")
    if (!root) return

    root.querySelectorAll(".lp-trail-battles__submit").forEach((el) => {
      el.disabled = false
      el.classList.remove("is-pending")
      el.removeAttribute("aria-busy")
    })
  }

  battleAdded(event) {
    this.endAddSubmit(event.target)

    const { success } = event.detail || {}
    if (!success) return

    if (this.hasTitleFieldTarget) {
      this.titleFieldTarget.value = ""
      this.titleFieldTarget.dispatchEvent(new Event("input", { bubbles: true }))
      if (this.keepDailyValue) {
        this.titleFieldTarget.blur()
      } else {
        this.titleFieldTarget.focus()
      }
    }
    if (this.hasDailyToggleTarget) {
      this.dailyToggleTarget.checked = this.keepDailyValue
      this.toggleDaily()
    }
    if (this.hasQuantityToggleTarget) {
      this.quantityToggleTarget.checked = false
      this.toggleQuantity()
    }
  }

  stashBattleDelete() {
    // Session stash is written server-side in destroy; undo toast handled by turbo stream.
  }

  showSessionToast(count) {
    if (!this.hasSessionToastTarget || count <= 0) return

    const template =
      this.sessionToastTarget.dataset.template ||
      this.element.dataset.sessionWinTemplate ||
      "%{count} won this session"
    this.sessionToastTarget.textContent = template.replace("%{count}", String(count))
    this.sessionToastTarget.hidden = false

    window.clearTimeout(this._sessionToastTimer)
    this._sessionToastTimer = window.setTimeout(() => {
      if (this.hasSessionToastTarget) this.sessionToastTarget.hidden = true
    }, 3200)
  }

  disconnect() {
    if (this._sessionToastTimer) window.clearTimeout(this._sessionToastTimer)
  }

  inlineTitleInput(current) {
    const input = document.createElement("input")
    input.type = "text"
    input.className = "lp-trail-battles__input lp-trail-battles__inline"
    input.maxLength = TITLE_MAX
    input.value = current
    const limit = attachTitleLimit(input, { template: this.atMaxTemplateValue })
    return { input, limit }
  }

  editSuggestion(event) {
    event.preventDefault()
    event.stopPropagation()
    const row = event.currentTarget.closest(".lp-trail-battles__row.is-suggestion")
    if (!row || row.querySelector("input.lp-trail-battles__inline")) return

    const nameBtn = row.querySelector(".lp-trail-battles__name-btn")
    const current = (nameBtn?.textContent || row.dataset.suggestionTitle || "").trim()
    if (!nameBtn) return

    nameBtn.hidden = true
    const { input, limit } = this.inlineTitleInput(current)
    nameBtn.insertAdjacentElement("afterend", input)
    input.focus()
    input.select()

    const commit = async () => {
      const title = input.value.trim()
      limit.detach()
      input.remove()
      nameBtn.hidden = false
      if (!title || title === current) return

      nameBtn.textContent = title
      row.dataset.suggestionTitle = title
      const titleField = row.querySelector('input[name="title"]')
      if (titleField) titleField.value = title

      const token = document.querySelector("meta[name='csrf-token']")?.content
      const body = new URLSearchParams()
      body.set("life_area_id", String(this.lifeAreaIdValue || ""))
      body.set("life_journey_id", String(this.lifeJourneyIdValue || ""))
      body.set("parent_id", String(this.parentIdValue || ""))
      body.set("horizon", "day")
      body.set("scheduled_on", new Date().toISOString().slice(0, 10))
      body.set("repeat", "none")
      body.set("title", title)
      body.set("authenticity_token", token || "")

      const response = await fetch(this.createUrlValue || "/strategy_goals", {
        method: "POST",
        headers: {
          Accept: "text/vnd.turbo-stream.html, text/html",
          "X-CSRF-Token": token || ""
        },
        body,
        credentials: "same-origin"
      })

      const html = await response.text()
      const contentType = response.headers.get("content-type") || ""
      if (response.ok && contentType.includes("turbo-stream") && window.Turbo?.renderStreamMessage) {
        window.Turbo.renderStreamMessage(html)
      }
    }

    input.addEventListener("blur", commit, { once: true })
    input.addEventListener("keydown", (keyEvent) => {
      if (keyEvent.key === "Enter") {
        keyEvent.preventDefault()
        input.blur()
      }
      if (keyEvent.key === "Escape") {
        keyEvent.preventDefault()
        input.value = current
        input.blur()
      }
    })
  }

  renameBattle(event) {
    event.preventDefault()
    event.stopPropagation()
    const row = event.currentTarget.closest(".lp-trail-battles__row")
    if (!row) return
    const url = event.currentTarget.dataset.updateUrl || row.dataset.updateUrl
    const name = row.querySelector(".lp-trail-battles__name")
    if (!url || !name || row.querySelector("input.lp-trail-battles__inline")) return

    const current = name.textContent.trim()
    name.hidden = true
    const { input, limit } = this.inlineTitleInput(current)
    name.insertAdjacentElement("afterend", input)
    input.focus()
    input.select()

    const commit = async () => {
      const title = input.value.trim()
      limit.detach()
      input.remove()
      name.hidden = false
      if (!title || title === current) return
      name.textContent = title
      const token = document.querySelector("meta[name='csrf-token']")?.content
      const body = new URLSearchParams()
      body.set("title", title)
      body.set("authenticity_token", token || "")
      await fetch(url, {
        method: "PATCH",
        headers: {
          Accept: "text/vnd.turbo-stream.html, text/html",
          "X-CSRF-Token": token || ""
        },
        body,
        credentials: "same-origin"
      })
    }

    input.addEventListener("blur", commit, { once: true })
    input.addEventListener("keydown", (keyEvent) => {
      if (keyEvent.key === "Enter") {
        keyEvent.preventDefault()
        input.blur()
      }
      if (keyEvent.key === "Escape") {
        keyEvent.preventDefault()
        input.value = current
        input.blur()
      }
    })
  }
}
