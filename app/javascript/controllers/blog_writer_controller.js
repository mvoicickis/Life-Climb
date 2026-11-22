import { Controller } from "@hotwired/stimulus"

const AUTOSAVE_MS = 5000

export default class extends Controller {
  static targets = [
    "form",
    "autosaveFlag",
    "slugAutoFlag",
    "seoTitle",
    "seoTitleCount",
    "metaDescription",
    "metaCount",
    "previewTitle",
    "previewDescription",
    "statusBar"
  ]

  static values = {
    saving: { type: Boolean, default: false },
    previewUrl: String,
    previewMissing: String,
    new: { type: Boolean, default: false }
  }

  async connect() {
    await import("admin_blog")
    this.debounceTimer = null
    this.saveQueued = false
    this.previewAfterSaveUrl = null
    this.intervalId = setInterval(() => this.save(), AUTOSAVE_MS)
    this.syncGooglePreview()
  }

  disconnect() {
    if (this.intervalId) clearInterval(this.intervalId)
    if (this.debounceTimer) clearTimeout(this.debounceTimer)
  }

  scheduleSave() {
    if (this.debounceTimer) clearTimeout(this.debounceTimer)
    this.debounceTimer = setTimeout(() => this.save(), 400)
  }

  saveOnBlur() {
    this.save()
  }

  save() {
    if (!this.hasFormTarget) return

    if (this.savingValue) {
      this.saveQueued = true
      return
    }

    if (!this.shouldSave()) return

    this.prepareSubmit()

    if (this.hasAutosaveFlagTarget) {
      this.autosaveFlagTarget.value = "1"
    }

    this.savingValue = true
    this.formTarget.requestSubmit()
  }

  shouldSave() {
    if (!this.newValue) return true

    const titleField = this.element.querySelector("textarea.lp-blog-writer__title")
    const title = titleField ? titleField.value.trim() : ""
    if (title.length > 0) return true

    const editor = this.element.querySelector("trix-editor")
    const bodyText = editor?.editor?.getDocument()?.toString?.().trim() || ""
    if (bodyText.length > 0) return true

    const fileInput = this.element.querySelector("input[type=file][name='blog_post[cover_photo]']")
    if (fileInput?.files?.length > 0) return true

    const excerpt = this.element.querySelector("textarea[name='blog_post[excerpt]']")
    if (excerpt?.value?.trim().length > 0) return true

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
    const success = !event?.detail || event.detail.success !== false

    this.savingValue = false
    if (this.hasAutosaveFlagTarget) {
      this.autosaveFlagTarget.value = ""
    }

    if (!success) {
      this.previewAfterSaveUrl = null
      this.runQueuedSave()
      return
    }

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
    this.save()
  }

  flushPreviewOpen() {
    if (!this.previewAfterSaveUrl) return

    const url = this.previewAfterSaveUrl
    this.previewAfterSaveUrl = null
    window.open(url, "_blank", "noopener")
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
      const titleField = this.element.querySelector("textarea.lp-blog-writer__title")
      const title = titleField ? titleField.value.trim() : ""
      const shown = seo || title
      this.previewTitleTarget.textContent = shown.length > 0 ? shown : "Title"
    }

    if (this.hasPreviewDescriptionTarget) {
      const meta = this.hasMetaDescriptionTarget ? this.metaDescriptionTarget.value.trim() : ""
      if (meta.length > 0) {
        this.previewDescriptionTarget.textContent = meta
        return
      }

      const editor = this.element.querySelector("trix-editor")
      const plain = editor?.innerText?.replace(/\s+/g, " ").trim() || ""
      const missing = this.previewMissingValue || ""
      this.previewDescriptionTarget.textContent =
        plain.length > 0 ? plain.slice(0, 155) : missing
    }
  }
}