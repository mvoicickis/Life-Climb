import { Controller } from "@hotwired/stimulus"

// Keeps slug in sync with the title until an admin edits the slug field.
export default class extends Controller {
  static targets = [ "title", "slug" ]

  connect() {
    this.slugEdited = this.slugTarget.value.length > 0
  }

  syncFromTitle() {
    if (this.slugEdited) return

    const raw = this.titleTarget.value.trim()
    this.slugTarget.value = raw
      .toLowerCase()
      .replace(/[^a-z0-9\s-]/g, "")
      .trim()
      .replace(/\s+/g, "-")
  }

  markSlugEdited() {
    this.slugEdited = true
  }
}