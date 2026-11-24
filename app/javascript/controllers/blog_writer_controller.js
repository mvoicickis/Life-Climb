import { Controller } from "@hotwired/stimulus"

const AUTOSAVE_MS = 5000
const STORAGE_PREFIX = "lifepoints-blog-backup-"

export default class extends Controller {
  static targets = [
    "form",
    "autosaveFlag",
    "publishFlag",
    "slugAutoFlag",
    "seoTitle",
    "seoTitleCount",
    "metaDescription",
    "metaCount",
    "previewTitle",
    "previewDescription",
    "statusBar",
    "backupBar",
    "titleInput"
  ]

  static values = {
    saving: { type: Boolean, default: false },
    previewUrl: String,
    previewMissing: String,
    new: { type: Boolean, default: false },
    postId: String,
    untitled: String,
    serverSnapshot: String,
    dirty: { type: Boolean, default: false },
    copySaving: String,
    copySaved: String,
    copySavedJustNow: String,
    copyNotSavedYet: String,
    copyNotSavedTap: String,
    copyDraft: String,
    copyPublished: String
  }

  async connect() {
    await import("admin_blog")
    this.debounceTimer = null
    this.saveQueued = false
    this.previewAfterSaveUrl = null
    this.lastSavedSnapshot = this.parseSnapshot(this.serverSnapshotValue)
    this.intervalId = setInterval(() => this.save(), AUTOSAVE_MS)
    this.syncGooglePreview()
    this.beforeUnloadHandler = (event) => this.onBeforeUnload(event)
    window.addEventListener("beforeunload", this.beforeUnloadHandler)
    this.checkBackup()
    if (this.newValue) {
      this.setClientStatus("dirty")
    }
  }

  disconnect() {
    if (this.intervalId) clearInterval(this.intervalId)
    if (this.debounceTimer) clearTimeout(this.debounceTimer)
    window.removeEventListener("beforeunload", this.beforeUnloadHandler)
  }

  storageKey() {
    return `${STORAGE_PREFIX}${this.postIdValue || "new"}`
  }

  parseSnapshot(raw) {
    try {
      return JSON.parse(raw || "{}")
    } catch {
      return {}
    }
  }

  currentSnapshot() {
    return {
      title: this.titleValue(),
      body: this.bodyPlainText(),
      excerpt: this.excerptValue(),
      saved_at: Date.now()
    }
  }

  titleValue() {
    const field = this.hasTitleInputTarget
      ? this.titleInputTarget
      : this.element.querySelector("textarea.lp-blog-writer__title")
    return field ? field.value.trim() : ""
  }

  excerptValue() {
    const excerpt = this.element.querySelector("textarea[name='blog_post[excerpt]']")
    return excerpt?.value?.trim() || ""
  }

  bodyPlainText() {
    const editor = this.element.querySelector("trix-editor")
    return editor?.innerText?.replace(/\s+/g, " ").trim() || ""
  }

  snapshotsDiffer(a, b) {
    if (!a || !b) return false
    return a.title !== b.title || a.body !== b.body || a.excerpt !== b.excerpt
  }

  backupToStorage() {
    const snapshot = this.currentSnapshot()
    if (
      snapshot.title.length === 0 &&
      snapshot.body.length === 0 &&
      snapshot.excerpt.length === 0
    ) {
      return
    }

    try {
      localStorage.setItem(this.storageKey(), JSON.stringify(snapshot))
    } catch {
      // storage full or private mode
    }
  }

  clearBackup() {
    try {
      localStorage.removeItem(this.storageKey())
    } catch {
      // ignore
    }
  }

  readBackup() {
    try {
      const raw = localStorage.getItem(this.storageKey())
      if (!raw) return null
      return JSON.parse(raw)
    } catch {
      return null
    }
  }

  checkBackup() {
    const backup = this.readBackup()
    if (!backup) return

    const server = {
      title: this.lastSavedSnapshot.title || "",
      body: this.lastSavedSnapshot.body || "",
      excerpt: this.lastSavedSnapshot.excerpt || ""
    }

    const backupDiffersFromServer = this.snapshotsDiffer(backup, server)
    if (!backupDiffersFromServer) {
      this.clearBackup()
      return
    }

    if (this.hasBackupBarTarget) {
      this.backupBarTarget.hidden = false
    }
  }

  restoreBackup() {
    const backup = this.readBackup()
    if (!backup) return

    if (this.hasTitleInputTarget) {
      this.titleInputTarget.value = backup.title || ""
      this.titleInputTarget.dispatchEvent(new Event("input", { bubbles: true }))
    }

    const editor = this.element.querySelector("trix-editor")
    if (editor?.editor && backup.body) {
      editor.editor.loadHTML(`<div>${this.escapeHtml(backup.body)}</div>`)
      editor.dispatchEvent(new Event("trix-change", { bubbles: true }))
    }

    const excerpt = this.element.querySelector("textarea[name='blog_post[excerpt]']")
    if (excerpt && backup.excerpt) {
      excerpt.value = backup.excerpt
    }

    if (this.hasBackupBarTarget) {
      this.backupBarTarget.hidden = true
    }
    this.markDirty()
    this.save()
  }

  dismissBackup() {
    this.clearBackup()
    if (this.hasBackupBarTarget) {
      this.backupBarTarget.hidden = true
    }
  }

  escapeHtml(text) {
    return text
      .replace(/&/g, "&amp;")
      .replace(/</g, "&lt;")
      .replace(/>/g, "&gt;")
  }

  markDirty() {
    this.dirtyValue = true
    this.backupToStorage()
    if (!this.savingValue) {
      this.setClientStatus(this.newValue ? "dirty" : "dirty")
    }
  }

  scheduleSave() {
    this.markDirty()
    if (this.debounceTimer) clearTimeout(this.debounceTimer)
    this.debounceTimer = setTimeout(() => this.save(), 400)
  }

  saveOnBlur() {
    this.save()
  }

  saveDraft(event) {
    event?.preventDefault()
    this.submitForm({ autosave: false, publish: false })
  }

  publish(event) {
    event?.preventDefault()
    this.submitForm({ autosave: false, publish: true })
  }

  submitForm({ autosave, publish }) {
    if (!this.hasFormTarget) return
    if (this.savingValue) {
      this.saveQueued = true
      return
    }
    if (!publish && !this.shouldSave()) return

    this.prepareSubmit()
    if (this.hasAutosaveFlagTarget) {
      this.autosaveFlagTarget.value = autosave ? "1" : ""
    }
    if (this.hasPublishFlagTarget) {
      this.publishFlagTarget.value = publish ? "1" : ""
    }

    this.savingValue = true
    this.setClientStatus("saving")
    this.formTarget.requestSubmit()
  }

  save() {
    this.submitForm({ autosave: true, publish: false })
  }

  shouldSave() {
    if (!this.newValue) return true

    const title = this.titleValue()
    if (title.length > 0) return true

    const bodyText = this.bodyPlainText()
    if (bodyText.length > 0) return true

    const fileInput = this.element.querySelector("input[type=file][name='blog_post[cover_photo]']")
    if (fileInput?.files?.length > 0) return true

    const excerpt = this.excerptValue()
    if (excerpt.length > 0) return true

    const meta = this.hasMetaDescriptionTarget ? this.metaDescriptionTarget.value.trim() : ""
    if (meta.length > 0) return true

    const focus = this.element.querySelector("input[name='blog_post[focus_phrase]']")
    if (focus?.value?.trim().length > 0) return true

    return false
  }

  prepareSubmit() {
    if (!this.hasSlugAutoFlagTarget) return

    const slugController = this.slugController()
    this.slugAutoFlagTarget.value = slugController?.isAutoSynced?.() ? "1" : "0"
  }

  slugController() {
    return this.application.getControllerForElementAndIdentifier(this.element, "blog-slug")
  }

  openPreview(event) {
    event.preventDefault()
    const url = this.previewUrlValue || event.currentTarget.getAttribute("href")
    if (!url) return

    if (this.debounceTimer) {
      clearTimeout(this.debounceTimer)
      this.debounceTimer = null
    }

    this.previewAfterSaveUrl = url
    if (this.savingValue) return

    this.save()
    if (!this.savingValue) {
      this.flushPreviewOpen()
    }
  }

  noteSaved(event) {
    const detail = event?.detail
    const httpStatus = detail?.fetchResponse?.response?.status
    const success =
      detail &&
      detail.success !== false &&
      (httpStatus === undefined || (httpStatus >= 200 && httpStatus < 300))

    this.savingValue = false
    if (this.hasAutosaveFlagTarget) {
      this.autosaveFlagTarget.value = ""
    }
    if (this.hasPublishFlagTarget) {
      this.publishFlagTarget.value = ""
    }

    if (!success) {
      this.previewAfterSaveUrl = null
      this.setClientStatus("error")
      this.runQueuedSave()
      return
    }

    this.dirtyValue = false
    this.lastSavedSnapshot = this.currentSnapshot()
    this.lastSavedSnapshot.updated_at = Math.floor(Date.now() / 1000)
    this.clearBackup()
    this.setClientStatus("saved")
    this.syncGooglePreview()
    const slugController = this.slugController()
    if (slugController?.refreshEditedState) slugController.refreshEditedState()
    this.flushPreviewOpen()
    this.runQueuedSave()
  }

  runQueuedSave() {
    if (!this.saveQueued) return

    this.saveQueued = false
    this.save()
  }

  retrySave(event) {
    const bar = this.hasStatusBarTarget ? this.statusBarTarget : null
    if (!bar?.classList.contains("is-error")) return

    event?.preventDefault()
    this.saveDraft()
  }

  flushPreviewOpen() {
    if (!this.previewAfterSaveUrl) return

    const url = this.previewAfterSaveUrl
    this.previewAfterSaveUrl = null
    window.open(url, "_blank", "noopener")
  }

  onBeforeUnload(event) {
    if (!this.dirtyValue && !this.savingValue) return

    event.preventDefault()
    event.returnValue = ""
  }

  setClientStatus(state) {
    if (!this.hasStatusBarTarget) return

    const bar = this.statusBarTarget
    bar.classList.remove("is-error", "is-saving")
    const baseline = this.newValue ? this.copyDraftValue : this.statusBaseline()

    let suffix = ""
    if (state === "saved") {
      suffix = ` · ${this.copySavedValue} ✓ ${this.copySavedJustNowValue}`
    } else if (state === "saving") {
      bar.classList.add("is-saving")
      suffix = ` · ${this.copySavingValue}`
    } else if (state === "dirty") {
      suffix = ` · ${this.copyNotSavedYetValue}`
    } else if (state === "error") {
      bar.classList.add("is-error")
      bar.dataset.action = "click->blog-writer#retrySave"
      suffix = ` · ${this.copyNotSavedTapValue}`
    }

    bar.textContent = `${baseline}${suffix}`
  }

  statusBaseline() {
    const text = this.statusBarTarget.textContent || ""
    if (text.includes("Published") || this.copyPublishedValue && text.startsWith(this.copyPublishedValue)) {
      return this.copyPublishedValue
    }
    return this.copyDraftValue
  }

  counterInput() {
    if (this.hasSeoTitleTarget && this.hasSeoTitleCountTarget) {
      this.seoTitleCountTarget.textContent = String(this.seoTitleTarget.value.length)
    }
    if (this.hasMetaDescriptionTarget && this.hasMetaCountTarget) {
      this.metaCountTarget.textContent = String(this.metaDescriptionTarget.value.length)
    }
    this.syncGooglePreview()
  }

  syncGooglePreview() {
    if (this.hasPreviewTitleTarget) {
      const seo = this.hasSeoTitleTarget ? this.seoTitleTarget.value.trim() : ""
      const title = this.titleValue()
      const shown = seo || title
      this.previewTitleTarget.textContent = shown.length > 0 ? shown : "Title"
    }

    if (this.hasPreviewDescriptionTarget) {
      const meta = this.hasMetaDescriptionTarget ? this.metaDescriptionTarget.value.trim() : ""
      if (meta.length > 0) {
        this.previewDescriptionTarget.textContent = meta
        return
      }

      const plain = this.bodyPlainText()
      const missing = this.previewMissingValue || ""
      this.previewDescriptionTarget.textContent =
        plain.length > 0 ? plain.slice(0, 155) : missing
    }
  }
}