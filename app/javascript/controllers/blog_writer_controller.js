import { Controller } from "@hotwired/stimulus"

const AUTOSAVE_MS = 5000

export default class extends Controller {
  static targets = [
    "form",
    "autosaveFlag",
    "seoTitle",
    "seoTitleCount",
    "metaDescription",
    "metaCount",
    "previewTitle"
  ]

  static values = {
    saving: { type: Boolean, default: false }
  }

  async connect() {
    await import("admin_blog")
    this.debounceTimer = null
    this.intervalId = setInterval(() => this.save(), AUTOSAVE_MS)
    this.syncPreviewTitle()
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
    if (!this.hasFormTarget || this.savingValue) return

    if (this.hasAutosaveFlagTarget) {
      this.autosaveFlagTarget.value = "1"
    }

    this.savingValue = true
    this.formTarget.requestSubmit()
  }

  noteSaved() {
    this.savingValue = false
    if (this.hasAutosaveFlagTarget) {
      this.autosaveFlagTarget.value = ""
    }
  }

  counterInput() {
    if (this.hasSeoTitleTarget && this.hasSeoTitleCountTarget) {
      this.seoTitleCountTarget.textContent = String(this.seoTitleTarget.value.length)
    }
    if (this.hasMetaDescriptionTarget && this.hasMetaCountTarget) {
      this.metaCountTarget.textContent = String(this.metaDescriptionTarget.value.length)
    }
    this.syncPreviewTitle()
  }

  syncPreviewTitle() {
    if (!this.hasPreviewTitleTarget) return

    const seo = this.hasSeoTitleTarget ? this.seoTitleTarget.value.trim() : ""
    const titleField = this.element.querySelector("textarea.lp-blog-writer__title")
    const title = titleField ? titleField.value.trim() : ""
    const shown = seo || title
    this.previewTitleTarget.textContent = shown.length > 0 ? shown : "Title"
  }
}
