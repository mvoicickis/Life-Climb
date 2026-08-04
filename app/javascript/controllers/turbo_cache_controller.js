import { Controller } from "@hotwired/stimulus"

// Clears Turbo Drive page snapshots after server mutations that affect other
// pages (e.g. habit destroy → Today must not restore a pre-delete cache).
export default class extends Controller {
  static values = { clear: Boolean }

  connect() {
    if (!this.clearValue) return
    if (window.Turbo?.cache) Turbo.cache.clear()
  }
}
