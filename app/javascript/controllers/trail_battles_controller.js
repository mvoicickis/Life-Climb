import { Controller } from "@hotwired/stimulus"

// Daily toggle + title parsing + camp rename inside trail battle sheet.
export default class extends Controller {
  static targets = ["titleField", "repeatField", "dailyToggle", "renameDialog", "renameField"]

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
}
