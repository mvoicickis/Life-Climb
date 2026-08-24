import { Controller } from "@hotwired/stimulus"

// Daily toggle + title parsing + camp rename + session win toasts inside trail battle sheet.
export default class extends Controller {
  static targets = [
    "titleField", "repeatField", "dailyToggle", "renameDialog", "renameField", "sessionToast", "addRow"
  ]

  static values = { sessionWins: { type: Number, default: 0 } }

  connect() {
    this.styleDailyRow()
  }

  parseDraft(event) {
    if (!this.hasTitleFieldTarget || !this.hasRepeatFieldTarget) return

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

  styleDailyRow() {
    if (!this.hasAddRowTarget || !this.hasDailyToggleTarget) return
    this.addRowTarget.classList.toggle("is-daily-on", this.dailyToggleTarget.checked)
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

  stashCampDelete() {
    // Session stash is written server-side in destroy; toast handled by turbo stream.
  }

  battleWon(event) {
    const { success } = event.detail || {}
    if (!success) return

    this.sessionWinsValue += 1
    this.showSessionToast(this.sessionWinsValue)
  }

  battleAdded(event) {
    const { success } = event.detail || {}
    if (!success) return

    if (this.hasTitleFieldTarget) {
      this.titleFieldTarget.value = ""
      this.titleFieldTarget.focus()
    }
    if (this.hasDailyToggleTarget) {
      this.dailyToggleTarget.checked = false
      this.toggleDaily()
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
}
