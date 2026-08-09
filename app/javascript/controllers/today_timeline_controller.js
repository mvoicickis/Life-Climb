import { Controller } from "@hotwired/stimulus"

// Positions the Today "now" line inside the active timeline segment.
export default class extends Controller {
  static targets = ["rail", "now", "segment"]
  static values = {
    index: Number,
    ratio: { type: Number, default: 0 }
  }

  connect() {
    this.placeNow()
    this.timer = window.setInterval(() => this.tick(), 60_000)
  }

  disconnect() {
    if (this.timer) window.clearInterval(this.timer)
  }

  tick() {
    // Soft live update: advance ratio within the current segment when possible.
    if (!this.hasNowTarget || !this.hasSegmentTarget) return
    const segment = this.segmentTargets.find((el) => Number(el.dataset.segmentIndex) === this.indexValue)
    if (!segment) return

    const start = Date.parse(segment.dataset.startsAt || "")
    const end = Date.parse(segment.dataset.endsAt || "")
    if (!Number.isFinite(start) || !Number.isFinite(end) || end <= start) return

    const now = Date.now()
    const ratio = Math.min(1, Math.max(0, (now - start) / (end - start)))
    this.ratioValue = ratio
    this.placeNow()
  }

  placeNow() {
    if (!this.hasNowTarget || !this.hasRailTarget || !this.hasSegmentTarget) return
    const segment = this.segmentTargets.find((el) => Number(el.dataset.segmentIndex) === this.indexValue)
    if (!segment) {
      this.nowTarget.hidden = true
      return
    }

    this.nowTarget.hidden = false
    const railBox = this.railTarget.getBoundingClientRect()
    const segBox = segment.getBoundingClientRect()
    if (railBox.height <= 0) return

    const topInRail = segBox.top - railBox.top + segBox.height * this.ratioValue
    this.nowTarget.style.top = `${Math.max(0, topInRail)}px`
  }
}
