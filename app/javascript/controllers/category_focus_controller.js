import { Controller } from "@hotwired/stimulus"

// Legacy no-op: camps now expand in place (folder disclosure).
// Kept so any stale data-controller="category-focus" markup does not error.
export default class extends Controller {
  connect() {
    // Practices live inside camp <details>; no Level B panel swap.
  }
}
