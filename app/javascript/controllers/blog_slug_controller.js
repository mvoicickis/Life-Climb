import { Controller } from "@hotwired/stimulus"

// Keeps slug in sync with the title until the slug no longer matches the auto value.
export default class extends Controller {
  static targets = [ "title", "slug" ]

  connect() {
    this.slugEdited = this.slugDiffersFromTitle()
  }

  syncFromTitle() {
    if (this.slugEdited) return

    this.slugTarget.value = this.slugify(this.titleTarget.value)
  }

  markSlugEdited() {
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

    const auto = this.slugify(this.titleTarget.value)
    return slug !== auto
  }
}