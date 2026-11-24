import { Controller } from "@hotwired/stimulus"

// Keeps slug in sync with the title until the slug no longer matches the auto value.
export default class extends Controller {
  static targets = [ "title", "slug" ]
  static values = { untitled: { type: String, default: "Untitled draft" } }

  connect() {
    this.slugEdited = this.slugDiffersFromTitle()
    if (this.hasTitleTarget && this.titleTarget.dataset.blogSlugUntitledValue) {
      this.untitledValue = this.titleTarget.dataset.blogSlugUntitledValue
    }
  }

  syncFromTitle() {
    if (this.slugEdited) return

    const title = this.titleTarget.value.trim()
    if (title.length === 0 || title === this.untitledValue) return

    this.slugTarget.value = this.slugify(title)
  }

  markSlugEdited() {
    this.slugEdited = this.slugDiffersFromTitle()
  }

  isAutoSynced() {
    return !this.slugEdited
  }

  refreshEditedState() {
    this.slugEdited = this.slugDiffersFromTitle()
  }

  slugify(raw) {
    return raw
      .toString()
      .trim()
      .toLowerCase()
      .replace(/[^a-z0-9\s-]/g, "")
      .trim()
      .replace(/\s+/g, "-")
  }

  slugDiffersFromTitle() {
    const slug = this.slugTarget.value.trim()
    if (slug.length === 0) return false
    if (/^draft-[a-z0-9]+$/i.test(slug)) return false

    const auto = this.slugify(this.titleTarget.value)
    return slug !== auto
  }
}